import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/storage/storage_provider.dart';
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
  late StorageProviderType _selectedStorage;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedStorage = ref.read(activeStorageTypeProvider);
  }

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
      await ref.read(albumsProvider.notifier).addAlbum(
            name,
            storageType: _selectedStorage.name,
          );
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

  String _storageLabel(StorageProviderType type) {
    switch (type) {
      case StorageProviderType.local:
        return 'Local';
      case StorageProviderType.drive:
        return 'Google Drive';
      case StorageProviderType.s3:
        return 'S3 Bucket';
      case StorageProviderType.webdav:
        return 'WebDAV';
      case StorageProviderType.mesh:
        return 'P2P Mesh';
    }
  }

  IconData _storageIcon(StorageProviderType type) {
    switch (type) {
      case StorageProviderType.local:
        return Icons.phone_android_rounded;
      case StorageProviderType.drive:
        return Icons.cloud_outlined;
      case StorageProviderType.s3:
        return Icons.storage_outlined;
      case StorageProviderType.webdav:
        return Icons.folder_shared_outlined;
      case StorageProviderType.mesh:
        return Icons.hub_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final defaultStorage = ref.watch(activeStorageTypeProvider);

    return AlertDialog(
      backgroundColor: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      title: Text(
        'Name your album',
        style: typography.headlineSmall?.copyWith(
          color: colors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: false,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: 'Album Name',
                hintText: 'e.g. Summer 2026',
                errorText: _error,
              ),
              onSubmitted: (_) => _loading ? null : _submit(),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              'Storage Backend',
              style: typography.bodyMedium?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Decide where encrypted memories will be stored. Once created, an album\'s storage cannot be shifted.',
              style: typography.bodySmall?.copyWith(
                color: colors.inkMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: StorageProviderType.values.map((type) {
                final isSelected = _selectedStorage == type;
                final isDefault = defaultStorage == type;
                return ChoiceChip(
                  avatar: Icon(
                    _storageIcon(type),
                    size: 15,
                    color: isSelected ? colors.primary : colors.inkMuted,
                  ),
                  label: Text(
                    isDefault ? '${_storageLabel(type)} (Default)' : _storageLabel(type),
                  ),
                  selected: isSelected,
                  selectedColor: colors.primary.withValues(alpha: 0.15),
                  backgroundColor: colors.surfaceContainerHigh,
                  labelStyle: typography.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colors.primary : colors.ink,
                  ),
                  side: BorderSide(
                    color: isSelected ? colors.primary : colors.divider,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedStorage = type);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}
