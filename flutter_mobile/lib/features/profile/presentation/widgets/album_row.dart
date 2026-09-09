import 'package:flutter/material.dart';

import 'package:flutter_mobile/core/drive/app_drive.dart';
import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/theme/index.dart';

class AlbumRow extends StatefulWidget {
  const AlbumRow({
    super.key,
    required this.album,
    required this.colors,
    required this.typography,
    required this.onShare,
  });

  final Album album;
  final AppColors colors;
  final TextTheme typography;
  final VoidCallback onShare;

  @override
  State<AlbumRow> createState() => _AlbumRowState();
}

class _AlbumRowState extends State<AlbumRow> {
  late Future<List<AlbumMember>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = AppDrive.instance.albumMembers(widget.album.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typography = widget.typography;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      leading: Icon(Icons.photo_library_outlined, size: 20, color: colors.accent),
      title: Text(
        widget.album.title,
        style: typography.bodyMedium?.copyWith(color: colors.ink, fontWeight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: widget.onShare,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.ios_share_outlined, size: 18, color: colors.accentDark),
          ),
          Icon(Icons.expand_more, color: colors.inkMuted),
        ],
      ),
      onExpansionChanged: (_) {
        setState(() {
          _membersFuture = AppDrive.instance.albumMembers(widget.album.id);
        });
      },
      children: [
        FutureBuilder<List<AlbumMember>>(
          future: _membersFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Could not load members',
                  style: typography.bodySmall?.copyWith(
                    color: colors.danger,
                    fontSize: 11,
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return Text('Loading members…',
                  style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11));
            }
            final members = snapshot.data!;
            if (members.isEmpty) {
              return Text('Only you',
                  style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11));
            }
            return Column(
              children: members
                  .map(
                    (m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${m.displayName ?? m.email} · ${m.role}',
                          style: typography.bodySmall?.copyWith(
                            color: colors.inkMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
