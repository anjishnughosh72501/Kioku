/// FlashbacksScreen — time-travel memories (yearly, monthly, weekly),
/// computed locally from the signed-in user's Drive albums.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mobile/core/models/memory.dart';
import 'package:flutter_mobile/core/providers.dart';
import 'package:flutter_mobile/core/theme/index.dart';
import 'package:flutter_mobile/shared/widgets/clay_card.dart';
import 'package:flutter_mobile/shared/widgets/drive_thumb.dart';

class FlashbacksScreen extends ConsumerStatefulWidget {
  const FlashbacksScreen({super.key});

  @override
  ConsumerState<FlashbacksScreen> createState() => _FlashbacksScreenState();
}

class _FlashbacksScreenState extends ConsumerState<FlashbacksScreen> {
  String _selectedPeriod = 'all';

  @override
  Widget build(BuildContext context) {
    final colors = context.kiokuColors;
    final typography = Theme.of(context).textTheme;
    final setsAsync = ref.watch(flashbacksProvider);
    final sets = setsAsync.value ?? <FlashbackSetData>[];

    final currentSets = _selectedPeriod == 'all'
        ? sets
        : sets.where((s) => s.period == _selectedPeriod).toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(flashbacksProvider),
        color: colors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(sets, colors, typography)
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: -0.1, end: 0, duration: 400.ms),
            ),
            ..._buildBody(setsAsync, currentSets, colors, typography),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    List<FlashbackSetData> sets,
    AppColors colors,
    TextTheme typography,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flashbacks',
                  style: typography.displayLarge?.copyWith(
                    fontSize: 28,
                    color: colors.ink,
                    fontFamily: 'Fraunces',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXs),
                Text(
                  'Relive moments from the past',
                  style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.divider),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.08),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/kiokulogo.jpg', fit: BoxFit.cover),
            ),
          ],
        ),
          if (sets.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingMd),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _periodChip('all', 'All', colors, typography),
                  for (final set in sets)
                    _periodChip(set.period, set.periodTitle, colors, typography),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _periodChip(
    String key,
    String label,
    AppColors colors,
    TextTheme typography,
  ) {
    final isActive = _selectedPeriod == key;
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.spacingSm),
      child: FilterChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) => setState(() => _selectedPeriod = key),
        backgroundColor: colors.surfaceContainer,
        selectedColor: colors.primary,
        labelStyle: typography.bodyMedium?.copyWith(
          fontSize: 12,
          color: isActive
              ? (colors.brightness == Brightness.dark
                    ? const Color(0xFF0D1E15)
                    : Colors.white)
              : colors.inkMuted,
        ),
        side: BorderSide(color: colors.divider, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  List<Widget> _buildBody(
    AsyncValue<List<FlashbackSetData>> setsAsync,
    List<FlashbackSetData> sets,
    AppColors colors,
    TextTheme typography,
  ) {
    if (setsAsync.isLoading && setsAsync.value == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator(color: colors.primary)),
        ),
      ];
    }

    if (setsAsync.hasError && !setsAsync.isLoading) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_outlined, size: 56, color: colors.inkMuted),
                const SizedBox(height: AppTheme.spacingLg),
                Text(
                  setsAsync.error.toString(),
                  style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingLg),
                ClayButton(
                  label: 'Retry',
                  variant: ClayButtonVariant.secondary,
                  onPressed: () => ref.refresh(flashbacksProvider),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (sets.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_outlined, size: 64, color: colors.inkMuted),
                  const SizedBox(height: AppTheme.spacingLg),
                  Text(
                    'No flashbacks yet',
                    style: typography.headlineSmall?.copyWith(color: colors.ink, fontSize: 20),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    'Memories will appear here as time passes',
                    style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          0,
          AppTheme.spacingMd,
          AppTheme.spacingXxl,
        ),
        sliver: SliverList.separated(
          itemCount: sets.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spacingLg),
          itemBuilder: (context, index) =>
              _buildFlashbackSection(sets[index], colors, typography),
        ),
      ),
    ];
  }

  Widget _buildFlashbackSection(
    FlashbackSetData set,
    AppColors colors,
    TextTheme typography,
  ) {
    return ClayCard(
      variant: ClayVariant.defaultCard,
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  set.periodTitle,
                  style: typography.headlineSmall?.copyWith(fontSize: 15, color: colors.ink),
                ),
              ),
              Text(
                set.subtitle,
                style: typography.bodySmall?.copyWith(color: colors.inkMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          if (set.items.isEmpty)
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
                child: Text(
                  'No memories from this period yet',
                  style: typography.bodyMedium?.copyWith(color: colors.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: set.items.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppTheme.spacingMd),
                itemBuilder: (context, index) =>
                    _buildFlashbackCard(set.items[index], colors, typography),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlashbackCard(
    KiokuMemory item,
    AppColors colors,
    TextTheme typography,
  ) {
    return SizedBox(
      width: 160,
      child: ClayCard(
        variant: ClayVariant.defaultCard,
        padding: EdgeInsets.zero,
        onTap: () => context.push('/media/${item.id}', extra: item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
                child: DriveThumb(memory: item),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                item.caption ?? 'Memory',
                style: typography.bodyMedium?.copyWith(fontSize: 12, color: colors.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}