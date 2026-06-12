// ─────────────────────────────────────────────────────────────────────
// LeaderboardScreen — "Reyting" (Figma 1:1)
// ─────────────────────────────────────────────────────────────────────
//
// Dashboard "Batafsil" tugmasidan ochiladi (avval ChildAchievementsScreen
// edi). Yashil header + 3 davr tab (Haftalik/Oylik/Butun davr) + viloyat
// filtri (bottom-sheet) + top-3 podium + paginated ro'yxat (15/sahifa,
// skrol bilan) + pastda joriy bola ("Siz"). Reyting XP'dan hisoblanadi
// (test/olympiad yechilganda XP beriladi).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:farzandim/core/constants/uzbekistan_regions.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/tashkent_time.dart';
import 'package:farzandim/features/gamification/data/models/leaderboard_models.dart';
import 'package:farzandim/features/gamification/data/repositories/leaderboard_repository.dart';
import 'package:farzandim/features/gamification/presentation/providers/leaderboard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _kGreenTop = Color(0xFF7ED957);
const _kGreenBottom = Color(0xFF4CAF50);
const _kGold = Color(0xFFFFC93C);
const _kSilver = Color(0xFFB8C2CC);
const _kBronze = Color(0xFFE8893B);

/// Reyting ekrani.
class LeaderboardScreen extends ConsumerStatefulWidget {
  /// `LeaderboardScreen` konstruktor.
  const LeaderboardScreen({required this.childId, super.key});

  /// Qaysi bola uchun ("Siz" reytingi).
  final String childId;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  // weekly | monthly | all
  String _period = 'all';
  String? _region;
  final ScrollController _scroll = ScrollController();

  static const _periods = ['weekly', 'monthly', 'all'];
  static const _periodLabels = ['Haftalik', 'Oylik', 'Butun davr'];
  static const _months = [
    'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
    'Iyul', 'Avgust', 'Sentyabr', 'Oktyabr', 'Noyabr', 'Dekabr',
  ];

  LeaderboardArgs get _args =>
      (childId: widget.childId, period: _period, region: _region);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 320) {
      ref.read(leaderboardProvider(_args).notifier).loadMore();
    }
  }

  String get _periodSubtitle {
    switch (_period) {
      case 'weekly':
        return 'Shu hafta';
      case 'monthly':
        final t = tashkentNow();
        return '${_months[t.month - 1]} oyi';
      default:
        return 'Butun davr';
    }
  }

  Future<void> _pickRegion() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (_) => _RegionPickerSheet(selected: _region),
    );
    if (result != null) {
      setState(() => _region = result.isEmpty ? null : result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(leaderboardProvider(_args));
    final top3 = st.entries.take(3).toList();
    final rest = st.entries.length > 3
        ? st.entries.sublist(3)
        : <LeaderboardEntry>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ─── Yashil header ───
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_kGreenTop, _kGreenBottom],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md,
                  AppDimensions.sm,
                  AppDimensions.md,
                  AppDimensions.lg,
                ),
                child: Column(
                  children: [
                    _header(),
                    const SizedBox(height: AppDimensions.md),
                    _tabs(),
                    const SizedBox(height: AppDimensions.md),
                    _regionButton(),
                    const SizedBox(height: AppDimensions.lg),
                    _podium(st, top3),
                  ],
                ),
              ),
            ),
          ),

          // ─── Dark ro'yxat ───
          Expanded(
            child: _list(st, rest),
          ),

          // ─── Sticky "Siz" ───
          // Faqat top-3'dan tashqarida ko'rsatamiz (top-3 podium'da ko'rinadi
          // — dublikat bo'lmasin). rank 0 = bu davrda XP yo'q → baribir
          // ko'rsatamiz.
          if (st.currentChild != null &&
              (st.currentChild!.rank == 0 || st.currentChild!.rank > 3))
            _CurrentChildRow(entry: st.currentChild!),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              const Text(
                'Reyting',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _periodSubtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _tabs() {
    final active = _periods.indexOf(_period);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _periodLabels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _period = _periods[i]),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == active ? Colors.white : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusPill),
                  ),
                  child: Text(
                    _periodLabels[i],
                    style: TextStyle(
                      color: i == active
                          ? const Color(0xFF1B5E20)
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _regionButton() {
    return GestureDetector(
      onTap: _pickRegion,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined,
                color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              _region ?? "Viloyatlar bo'yicha",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _podium(LeaderboardState st, List<LeaderboardEntry> top3) {
    if (st.initialLoading) {
      return const SizedBox(
        height: 150,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    if (top3.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            "Hali reyting yo'q",
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      );
    }
    LeaderboardEntry? at(int i) => i < top3.length ? top3[i] : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumItem(at(1), 2, 60)),
        Expanded(child: _podiumItem(at(0), 1, 78)),
        Expanded(child: _podiumItem(at(2), 3, 60)),
      ],
    );
  }

  Widget _podiumItem(LeaderboardEntry? e, int place, double size) {
    if (e == null) return const SizedBox.shrink();
    final color = place == 1
        ? _kGold
        : place == 2
            ? _kSilver
            : _kBronze;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (place == 1)
          const Icon(Icons.emoji_events_rounded, color: _kGold, size: 24),
        const SizedBox(height: 2),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
              ),
              child: _Avatar(
                childId: e.childId,
                name: e.name,
                size: size,
              ),
            ),
            Positioned(
              bottom: -10,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kGreenBottom, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$place',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          e.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        _XpPill(xp: e.xp, light: true),
      ],
    );
  }

  Widget _list(LeaderboardState st, List<LeaderboardEntry> rest) {
    if (st.initialLoading) {
      return const SizedBox.shrink();
    }
    if (st.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reyting yuklanmadi',
                style: AppTextStyles.bodyM
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.read(leaderboardProvider(_args).notifier).refresh(),
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      );
    }
    if (rest.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.md,
      ),
      itemCount: rest.length + (st.loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (context, i) {
        if (i >= rest.length) {
          return Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }
        return _LeaderboardRow(entry: rest[i]);
      },
    );
  }
}

// ════════════════════════ ROW ════════════════════════

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, this.highlight = false});

  final LeaderboardEntry entry;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm + 2,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: highlight
            ? Border.all(color: AppColors.accent, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              entry.rank > 0 ? '${entry.rank}' : '—',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          _Avatar(childId: entry.childId, name: entry.name, size: 40),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyM.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (highlight) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Siz',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (entry.region.isNotEmpty)
                  Text(
                    entry.region,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          _XpPill(xp: entry.xp),
        ],
      ),
    );
  }
}

class _CurrentChildRow extends StatelessWidget {
  const _CurrentChildRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.md,
      ),
      child: SafeArea(
        top: false,
        child: _LeaderboardRow(entry: entry, highlight: true),
      ),
    );
  }
}

// ════════════════════════ AVATAR ════════════════════════

class _Avatar extends ConsumerWidget {
  const _Avatar({
    required this.childId,
    required this.name,
    required this.size,
  });

  final String childId;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.read(leaderboardRepositoryProvider).avatarUrl(childId);
    final letter = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return ClipOval(
      // MEM-4: disk kesh + cheklangan dekod (memCacheWidth)
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: 200,
        errorWidget: (_, __, ___) => _fallback(letter),
        placeholder: (_, __) => _fallback(letter),
      ),
    );
  }

  Widget _fallback(String letter) {
    return Container(
      width: size,
      height: size,
      color: AppColors.surfaceVariant,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

// ════════════════════════ XP PILL ════════════════════════

class _XpPill extends StatelessWidget {
  const _XpPill({required this.xp, this.light = false});

  final int xp;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: 0.22)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded,
              size: 15,
              color: light ? Colors.white : AppColors.warning),
          const SizedBox(width: 4),
          Text(
            '$xp',
            style: AppTextStyles.label.copyWith(
              color: light ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ REGION PICKER ════════════════════════

class _RegionPickerSheet extends StatelessWidget {
  const _RegionPickerSheet({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    const regions = UzbekistanRegions.regions;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.lg,
              AppDimensions.lg,
              AppDimensions.lg,
              AppDimensions.sm,
            ),
            child: Row(
              children: [
                Text(
                  'Hududni tanlang',
                  style: AppTextStyles.headlineL.copyWith(fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                _tile(context, label: 'Hammasi', value: '',
                    isSelected: selected == null),
                for (final r in regions)
                  _tile(context, label: r, value: r, isSelected: r == selected),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return ListTile(
      title: Text(label, style: AppTextStyles.bodyM),
      trailing: Icon(
        isSelected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: isSelected ? AppColors.accent : AppColors.textTertiary,
      ),
      onTap: () => Navigator.of(context).pop(value),
    );
  }
}
