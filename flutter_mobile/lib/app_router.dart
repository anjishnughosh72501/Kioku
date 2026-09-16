/// App Router — GoRouter configuration for Kioku navigation
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models/memory.dart';
import 'features/auth/presentation/screens/join_screen.dart';
import 'features/feed/presentation/screens/feed_screen.dart';
import 'package:flutter_mobile/shared/widgets/kioku_shell.dart';
import 'features/flashbacks/presentation/screens/flashbacks_screen.dart';
import 'features/upload/presentation/screens/upload_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/media_viewer/presentation/screens/photo_viewer_screen.dart';
import 'features/media_viewer/presentation/screens/video_player_screen.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/recovery_key_screen.dart';
import 'features/auth/presentation/screens/migration_screen.dart';
import 'features/profile/presentation/screens/storage_setup_screen.dart';

/// GoRouter provider with auth state listener
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/join',
    redirect: (context, state) {
      final isAuthed = authState.isAuthenticated;
      final isJoining = state.matchedLocation == '/join';

      if (!isAuthed && !isJoining) {
        return '/join';
      }
      if (isAuthed && isJoining) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/join',
        name: 'join',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const JoinScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return KiokuShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'feed',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: FeedScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/flashbacks',
                name: 'flashbacks',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: FlashbacksScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/upload',
        name: 'upload',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const UploadScreen(),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.14),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(
                opacity: curved,
                child: child,
              ),
            );
          },
        ),
      ),
      GoRoute(
        path: '/media/:id',
        name: 'media-detail',
        pageBuilder: (context, state) {
          final mediaId = state.pathParameters['id']!;
          final memory = state.extra as KiokuMemory?;
          final child = (memory?.isVideo == true)
              ? VideoPlayerScreen(mediaId: mediaId, memory: memory)
              : PhotoViewerScreen(mediaId: mediaId, memory: memory);
          return CustomTransitionPage(
            key: state.pageKey,
            child: child,
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
                  child: child,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/storage-setup',
        name: 'storage-setup',
        pageBuilder: (context, state) => buildPushTransitionPage(
          key: state.pageKey,
          child: const StorageSetupScreen(),
        ),
      ),
      GoRoute(
        path: '/recovery-key',
        name: 'recovery-key',
        pageBuilder: (context, state) => buildPushTransitionPage(
          key: state.pageKey,
          child: RecoveryKeyScreen(
            recoveryPhrase: state.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: '/migration',
        name: 'migration',
        pageBuilder: (context, state) => buildPushTransitionPage(
          key: state.pageKey,
          child: MigrationScreen(
            onComplete: () => context.go('/'),
          ),
        ),
      ),
    ],
  );
});

/// iOS-style push transition: subtle horizontal slide (Offset(0.06, 0) -> 0) + fade
Page<dynamic> buildPushTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: child,
        ),
      );
    },
  );
}