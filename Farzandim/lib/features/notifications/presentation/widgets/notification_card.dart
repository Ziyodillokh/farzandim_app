import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/config/env_config.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/formatters.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_icon_widget.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:flutter/material.dart';

/// Bildirishnomalar ekranidagi bitta kartochka (Figma 1:1).
///
/// **Ikki variant:**
/// - **Aksiyali** (`isActionable`, masalan pair so'rov): sarlavha + bola
///   ismi + meta + qizil o'qilmagan nuqta + "Tekshirish" / "Rad etish".
/// - **Info** (batareya, zona, jadval, ...): ikona + sarlavha + meta
///   (bola • vaqt), tugmasiz.
class NotificationCard extends StatelessWidget {
  /// `NotificationCard` konstruktor.
  const NotificationCard({
    required this.notification,
    required this.onTap,
    this.onReview,
    this.onReject,
    this.onBlock,
    super.key,
  });

  /// Ko'rsatiladigan xabar.
  final AppNotification notification;

  /// Karta bossa — `markAsRead` + type bo'yicha navigatsiya.
  final VoidCallback onTap;

  /// "Tekshirish" tugmasi (faqat aksiyali xabarlar uchun).
  final VoidCallback? onReview;

  /// "Rad etish" tugmasi (faqat aksiyali xabarlar uchun).
  final VoidCallback? onReject;

  /// "Bloklash" tugmasi (faqat o'yin xabarlari uchun).
  final VoidCallback? onBlock;

  bool get _actionable =>
      notification.isActionable && onReview != null && onReject != null;

  bool get _blockable => notification.isGame && onBlock != null;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.radiusL);
    final title = notification.title.trim().isNotEmpty
        ? notification.title
        : notification.message;
    // SOS — eng muhim: qizil tusli fon + qizil chegara bilan ajralib turadi.
    final isSos = notification.type == NotificationType.sos;

    return Material(
      color: isSos
          ? AppColors.error.withValues(alpha: 0.12)
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: isSos
              ? AppColors.error.withValues(alpha: 0.55)
              : AppColors.border,
          width: isSos ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Avatar(notification: notification),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.bodyM.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_actionable) ...[
                          if (notification.childName.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              notification.childName,
                              style: AppTextStyles.bodyS.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 3),
                          Text(
                            _meta(),
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            _meta(),
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!notification.isRead) ...[
                    const SizedBox(width: 8),
                    const _UnreadDot(),
                  ],
                ],
              ),
              if (_actionable) ...[
                const SizedBox(height: AppDimensions.md),
                Row(
                  children: [
                    Expanded(
                      child: _PillButton(
                        label: 'notifications.review'.tr(),
                        onTap: onReview!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PillButton(
                        label: 'notifications.reject'.tr(),
                        onTap: onReject!,
                      ),
                    ),
                  ],
                ),
              ],
              // O'yin xabari — bitta "Bloklash" tugmasi (o'yinni to'liq
              // bloklaydi).
              if (_blockable) ...[
                const SizedBox(height: AppDimensions.md),
                _BlockButton(onTap: onBlock!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Meta qatori — "Hozir • Sevinch" yoki info'da "Sevinch • Kecha".
  String _meta() {
    final time = _capitalize(formatRelativeTime(notification.timestamp));
    if (_actionable) {
      return time;
    }
    final parts = <String>[
      if (notification.childName.trim().isNotEmpty) notification.childName,
      time,
    ];
    return parts.join(' • ');
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ════════════════════════ AVATAR ════════════════════════

class _Avatar extends StatelessWidget {
  const _Avatar({required this.notification});
  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    // O'yin / ilova-limiti xabari — haqiqiy ilova ikonkasini ko'rsatamiz
    // (masalan CS2 o'ynalsa CS2 ikonkasi). Ikonka backend proxy'dan keladi:
    // bola installed-apps sync'i orqali MinIO'ga yuklagan PNG. @Public —
    // auth header kerak emas. AppIconWidget yetib bo'lmasa type/paket
    // fallback'iga tushadi (ikonka hali sinxronlanmagan bo'lsa).
    final pkg = notification.packageName;
    if (pkg != null &&
        pkg.isNotEmpty &&
        notification.childId.isNotEmpty) {
      final iconUrl = '${EnvConfig.apiUrl}/children/${notification.childId}'
          '/installed-apps/${Uri.encodeComponent(pkg)}/icon';
      return AppIconWidget(
        packageName: pkg,
        iconUrl: iconUrl,
        size: 46,
      );
    }

    final color = notification.type.color;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(notification.type.icon, color: color, size: 24),
    );
  }
}

// ════════════════════════ UNREAD DOT ════════════════════════

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ════════════════════════ BLOCK BUTTON ════════════════════════

/// "Bloklash" — o'yin xabari ostidagi to'liq-kenglik tugma (qizil tus).
/// Bosilganda o'yin to'liq bloklanadi (app-limit dailyLimitMs=0).
class _BlockButton extends StatelessWidget {
  const _BlockButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.error.withValues(alpha: 0.12),
      shape: StadiumBorder(
        side: BorderSide(
          color: AppColors.error.withValues(alpha: 0.5),
          width: 1.4,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block_rounded, size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'notifications.blockApp'.tr(),
                style: AppTextStyles.bodyM.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════ PILL BUTTON ════════════════════════

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: AppColors.border, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
