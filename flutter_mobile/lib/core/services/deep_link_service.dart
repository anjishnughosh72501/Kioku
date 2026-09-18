import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/services/invite_service.dart';
import 'package:flutter_mobile/core/services/user_profile_service.dart';
import 'package:flutter_mobile/core/storage/local_storage_service.dart';
import 'package:flutter_mobile/features/friends/presentation/widgets/invite_accept_dialog.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const MethodChannel _channel = MethodChannel('com.kioku.app/deeplink');
  bool _initialized = false;
  Future<void> Function(Uri uri)? _linkHandler;

  void setHandler(Future<void> Function(Uri uri) handler) {
    _linkHandler = handler;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') {
        final raw = call.arguments as String?;
        if (raw != null && raw.isNotEmpty) {
          final uri = Uri.tryParse(raw);
          if (uri != null && _linkHandler != null) {
            await _linkHandler!(uri);
          }
        }
      }
    });

    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (initial != null && initial.isNotEmpty) {
        final uri = Uri.tryParse(initial);
        if (uri != null && _linkHandler != null) {
          await _linkHandler!(uri);
        }
      }
    } catch (_) {}
  }

  /// Process an incoming invite or deep link URI
  static Future<bool> handleIncomingUri({
    required Uri uri,
    required WidgetRef ref,
    required BuildContext context,
  }) async {
    // 1. Check for Universal Short Invite Links (/i/:code or /invite/:code or kioku://i/:code)
    String? shortInviteCode;
    if (uri.pathSegments.isNotEmpty) {
      if (uri.pathSegments.first == 'i' && uri.pathSegments.length > 1) {
        shortInviteCode = uri.pathSegments[1];
      } else if (uri.pathSegments.first == 'invite' && uri.pathSegments.length > 1) {
        shortInviteCode = uri.pathSegments[1];
      }
    }
    if (shortInviteCode == null && (uri.host == 'i' || uri.host == 'invite')) {
      if (uri.pathSegments.isNotEmpty) {
        shortInviteCode = uri.pathSegments.first;
      }
    }

    if (shortInviteCode != null && shortInviteCode.trim().isNotEmpty) {
      final code = shortInviteCode.trim().toUpperCase();
      if (context.mounted) {
        InviteAcceptDialog.show(context, code);
      }
      return true;
    }

    String? albumId = uri.queryParameters['albumId'];
    final albumName = uri.queryParameters['albumName'] ?? 'Shared Album';
    final friendCode = uri.queryParameters['friendCode'];
    final from = uri.queryParameters['from'];
    final storage = uri.queryParameters['storage'] ?? 'local';
    final claimToken = uri.queryParameters['claim'];

    // Parse path-based album ids (e.g. kioku://album/123 or https://kioku.app/albums/123)
    if (albumId == null || albumId.isEmpty) {
      if (uri.host == 'album' || uri.host == 'albums') {
        if (uri.pathSegments.isNotEmpty) {
          albumId = uri.pathSegments.first;
        }
      } else if (uri.pathSegments.isNotEmpty) {
        final idx = uri.pathSegments.indexOf('albums');
        final altIdx = uri.pathSegments.indexOf('album');
        final matchIdx = idx != -1 ? idx : altIdx;
        if (matchIdx != -1 && matchIdx + 1 < uri.pathSegments.length) {
          albumId = uri.pathSegments[matchIdx + 1];
        }
      }
    }

    final hasFriend = friendCode != null && friendCode.trim().isNotEmpty;
    final hasAlbum = albumId != null && albumId.trim().isNotEmpty;

    if (!hasFriend && !hasAlbum) {
      return false;
    }

    // Require explicit user confirmation before touching local albums or state
    if (context.mounted) {
      final friendLabel = from != null && from.isNotEmpty ? from : (friendCode ?? 'A friend');
      final promptTitle = hasAlbum ? 'Join Shared Album?' : 'Connect with Friend?';
      final promptBody = hasAlbum
          ? '$friendLabel wants to share the album "$albumName" with you.'
          : '$friendLabel wants to connect with you on Kioku.';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(promptTitle),
          content: Text(promptBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Decline'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Accept'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return false;
      }
    }

    bool friendAdded = false;
    if (friendCode != null && friendCode.trim().isNotEmpty) {
      await UserProfileService.instance.addFriend(
        friendCode.trim(),
        displayName: from,
      );
      ref.invalidate(connectedFriendsProvider);
      friendAdded = true;
    }

    bool albumJoined = false;
    if (albumId != null && albumId.trim().isNotEmpty) {
      final cleanAlbumId = albumId.trim();

      // Zero-knowledge key handoff: never parse raw collection keys from URLs.
      // If a claim token is present, initiate the claim-token key-exchange flow.
      if (claimToken != null && claimToken.isNotEmpty) {
        try {
          await InviteService.instance.redeemClaim(claimToken: claimToken);
        } catch (_) {}
      }

      await LocalStorageService.instance.ensureAlbum(
        id: cleanAlbumId,
        name: albumName,
        storageType: storage,
      );
      await ref.read(albumsProvider.notifier).refresh();
      await ref.read(activeAlbumProvider.notifier).set(cleanAlbumId);
      await ref.read(memoriesProvider.notifier).refresh();
      albumJoined = true;

      if (context.mounted) {
        GoRouter.of(context).go('/albums/$cleanAlbumId');
      }
    }

    if (context.mounted && (friendAdded || albumJoined)) {
      final friendLabel = from != null && from.isNotEmpty ? from : (friendCode ?? 'friend');
      String message;
      if (friendAdded && albumJoined) {
        message = 'Connected with $friendLabel & joined "$albumName"!';
      } else if (albumJoined) {
        message = 'Joined album "$albumName"!';
      } else {
        message = 'Connected with $friendLabel!';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return true;
    }

    return false;
  }
}
