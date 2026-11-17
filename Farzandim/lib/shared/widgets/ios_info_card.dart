import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Parvoz tokenlari (lokal) — boshqa Parvoz varaqlari bilan bir xil.
const _blue = Color(0xFF216BFF);
const _blueSoft = Color(0xFF508AFF);
const _textDim = Color(0xB3FFFFFF); // oq 70%

/// iPhone (iOS) bola uchun tushuntirish kartasi.
///
/// iOS bola ilovasi haqiqiy ilovalar/ekran vaqtini yubormaydi (Apple qoidasi),
/// shu sabab ota-ona ekranlarida "ma'lumot yo'q" o'rniga sababi ko'rsatiladi.
/// [compact] — ro'yxat tepasidagi ixcham banner (varaqlarda), aks holda
/// to'liq o'lchamli karta.
class IosInfoCard extends StatelessWidget {
  /// `IosInfoCard` konstruktor.
  const IosInfoCard({
    required this.message,
    this.title,
    this.compact = false,
    super.key,
  });

  /// Asosiy matn.
  final String message;

  /// Ixtiyoriy sarlavha (faqat to'liq o'lchamli kartada ko'rsatiladi).
  final String? title;

  /// Ixcham banner (kichik padding va shrift).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final heading = compact ? null : title;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: _blue.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.phone_iphone, size: compact ? 20 : 24, color: _blueSoft),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (heading != null) ...[
                  Text(
                    heading,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 12.5 : 13.5,
                    color: _textDim,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
