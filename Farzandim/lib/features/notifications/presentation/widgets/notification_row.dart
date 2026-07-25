import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/config/env_config.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_icon_widget.dart';
import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

/// Ilova (o'yin) ikonasi proxy URL — backend MinIO'dan rasmni stream qiladi
/// (`@Public`, auth header kerak emas). "O'yin o'ynayapti" xabarida o'yinning
/// HAQIQIY logosini ko'rsatish uchun.
String appIconProxyUrl(String childId, String packageName) =>
    '${EnvConfig.apiUrl}/children/$childId/installed-apps/'
    '${Uri.encodeComponent(packageName)}/icon';

// ════════════ Tokenlar (lokal, Parvoz) ════════════
const _row = Color(0xFF21262A); // ikon-tayl foni
const _cardBorder = Color(0x14FFFFFF); // oq ~8% rim
const _dim = Color(0x99FFFFFF); // oq 60% — quyi matn
const _sosRed = Color(0xFFFF3B30); // SOS asosiy qizil
const _sosDim = Color(0xB3FF6B60); // SOS quyi matn (muloyim qizil)
const _sosBg = Color(0x14FF3B30); // SOS karta foni (qizil ~8%)
const _sosBorder = Color(0x40FF3B30); // SOS karta chegarasi (qizil ~25%)

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.45,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.35,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.4);

/// Xabar kelgan soat (HH:mm) — ro'yxat kun bo'yicha guruhlangani uchun bu
/// yerda faqat soat kifoya (sana guruh sarlavhasida).
String _fmtTime(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)}';
}

/// Bildirishnomalar ro'yxatidagi bitta qator (Parvoz varaq/sahifa uchun umumiy).
///
/// Rasm 3 dizayni: chapda dumaloq-kvadrat ikon-tayl (tur ikoni), o'ngida
/// sarlavha (Unbounded, qalin) + quyi matn (Poppins, xira). Bosilsa
/// [onTap] — o'qilgan deb belgilaydi va detal sahifasini ochadi.
class NotificationRow extends StatelessWidget {
  /// `NotificationRow` konstruktor.
  const NotificationRow({
    required this.notification,
    required this.onTap,
    super.key,
  });

  /// Ko'rsatiladigan xabar.
  final AppNotification notification;

  /// Qator bosilganda chaqiriladi.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasTitle = notification.title.trim().isNotEmpty;
    final title = hasTitle
        ? notification.title.trim()
        : notification.message.trim();
    final sub = hasTitle ? notification.message.trim() : '';
    final img = notification.imageUrl?.trim();
    final hasImage = img != null && img.isNotEmpty;

    // O'yin xabari ("O'yin o'ynayapti") — o'yinning HAQIQIY logosi backend
    // ikon proxy'sidan. Avval faqat umumiy gamepad ikoni ko'rinardi (logo
    // yo'q edi). Logo topilmasa AppIconWidget brend rangli harf beradi.
    final gamePkg = notification.packageName?.trim();
    final showGameIcon =
        notification.isGame &&
        gamePkg != null &&
        gamePkg.isNotEmpty &&
        notification.childId.isNotEmpty;

    // Ikon-tayl: rasm bo'lsa kichik banner thumbnail, aks holda tur ikoni.
    final iconChild = showGameIcon
        ? AppIconWidget(
            packageName: gamePkg,
            iconUrl: appIconProxyUrl(notification.childId, gamePkg),
            size: 46,
          )
        : Icon(notification.type.icon, size: 22, color: Colors.white);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              // Logo/rasm tayl chegarasidan chiqmasin.
              clipBehavior: (hasImage || showGameIcon)
                  ? Clip.antiAlias
                  : Clip.none,
              decoration: BoxDecoration(
                color: _row,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardBorder),
              ),
              child: hasImage
                  ? Image.network(
                      img,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      // Rasm yuklanmasa tur ikoni ko'rinadi.
                      errorBuilder: (context, error, stack) => iconChild,
                    )
                  : iconChild,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _unb(14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Kelgan soat (HH:mm).
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          _fmtTime(notification.timestamp),
                          style: _pop(11, c: _dim),
                        ),
                      ),
                    ],
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _pop(12, c: _dim),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SOS bildirishnomasi uchun maxsus qizil karta (ro'yxat tepasida).
/// Bosilsa — SOS modali ochiladi.
class SosNotificationCard extends StatelessWidget {
  /// `SosNotificationCard` konstruktor.
  const SosNotificationCard({
    required this.notification,
    required this.onTap,
    super.key,
  });

  /// SOS xabari.
  final AppNotification notification;

  /// Karta bosilganda chaqiriladi.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = notification.childName.trim();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: _sosBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _sosBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'notifications.sos.cardTitle'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _unb(16, c: _sosRed),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'notifications.sos.cardSubtitle'.tr(
                      namedArgs: {'name': name},
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _pop(12.5, c: _sosDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmtTime(notification.timestamp),
                  style: _pop(11, c: _sosDim),
                ),
                const SizedBox(height: 6),
                const Icon(
                  SolarIconsBold.altArrowRight,
                  size: 22,
                  color: _sosRed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
