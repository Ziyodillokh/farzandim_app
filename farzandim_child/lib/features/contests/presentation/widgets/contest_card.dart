// ─────────────────────────────────────────────────────────────────────
// ContestCard — konkurs kartasi (PDF p13-14)
// ─────────────────────────────────────────────────────────────────────
//
// Yuqorida 160px rasm sohasi (real imageUrl yoki placeholder gradient
// + ikon). Pastida soha badge + bonus, title, description, va
// holatga qarab progress bar (aktiv) yoki g'olib bloki (yakunlangan).

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/contests/data/models/contest_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ContestCard extends StatelessWidget {
  const ContestCard({required this.contest, super.key});

  final ContestModel contest;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (contest.isActive) {
          context.push('/contest-start', extra: contest);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Konkurs natijalari tez orada'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: contest.placeholderColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          contest.soha,
                          style: TextStyle(
                            color: contest.placeholderColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(AppIcons.star,
                          color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${contest.bonus}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    contest.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contest.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (contest.isActive)
                    _ActiveDetails(contest: contest)
                  else
                    _FinishedDetails(contest: contest),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: contest.imageUrl.isNotEmpty
            ? Image.network(
                contest.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  contest.placeholderColor,
                  // ignore: deprecated_member_use
                  contest.placeholderColor.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ),
        Center(
          child: Icon(
            contest.placeholderIcon,
            // ignore: deprecated_member_use
            color: Colors.white.withOpacity(0.9),
            size: 64,
          ),
        ),
        if (!contest.isActive)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'YAKUNLANGAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActiveDetails extends StatelessWidget {
  const _ActiveDetails({required this.contest});

  final ContestModel contest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: contest.progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.surfaceVariant,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.people,
                size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              '${contest.ishtirokchilarSoni}/${contest.maxIshtirokchi}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const Spacer(),
            const Icon(AppIcons.schedule,
                size: 14, color: AppColors.warning),
            const SizedBox(width: 4),
            Text(
              contest.remainingFormatted,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FinishedDetails extends StatelessWidget {
  const _FinishedDetails({required this.contest});

  final ContestModel contest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          // ignore: deprecated_member_use
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(AppIcons.trophy,
                color: Colors.black, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "G'olib",
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${contest.winnerName ?? "—"}, ${contest.winnerAge ?? "—"} yosh',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${contest.ishtirokchilarSoni}',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.people,
              size: 12, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
