import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';

class CreateAlbumDialog extends ConsumerStatefulWidget {
  const CreateAlbumDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const CreateAlbumDialog(),
    );
  }

  @override
  ConsumerState<CreateAlbumDialog> createState() => _CreateAlbumDialogState();
}

class _CreateAlbumDialogState extends ConsumerState<CreateAlbumDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter an album name');
      return;
    }
    if (name.length > 80) {
      setState(() => _error = 'Name must be 80 characters or fewer');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(albumsProvider.notifier).addAlbum(name);
      if (mounted) {
        Navigator.of(context).pop(name);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to create album: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: colors.surfaceContainer,
      title: Text(
        'Name your album',
        style: typography.headlineSmall?.copyWith(
          color: colors.ink,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: InputDecoration(
          hintText: 'e.g. Summer 2026',
          errorText: _error,
        ),
        onSubmitted: (_) => _loading ? null : _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
          ),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.accentDark,
                  ),
                )
              : Text(
                  'Create',
                  style: typography.bodyMedium?.copyWith(
                    color: colors.accentDark,
                  ),
                ),
        ),
      ],
    );
  }
}
