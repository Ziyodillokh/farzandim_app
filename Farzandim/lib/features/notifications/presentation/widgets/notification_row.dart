import 'package:farzandim/features/notifications/data/models/app_notification.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Tokenlar (lokal, Parvoz) ════════════
const _row = Color(0xFF21262A); // ikon-tayl foni
const _cardBorder = Color(0x14FFFFFF); // oq ~8% rim
const _dim = Color(0x99FFFFFF); // oq 60% — quyi matn

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
              decoration: BoxDecoration(
                color: _row,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cardBorder),
              ),
              child: Icon(
                notification.type.icon,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _unb(14),
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
