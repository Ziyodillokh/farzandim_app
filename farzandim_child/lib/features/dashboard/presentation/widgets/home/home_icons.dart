// ─────────────────────────────────────────────────────────────────────
// Bosh sahifa — maxsus vektor ikonlar
// ─────────────────────────────────────────────────────────────────────
//
// Solar to'plamida aynan mosi yo'q ikonlar maketdan qayta chizilgan
// (24×24 viewBox). Oq rangda chiziladi, rang `HomeSvgIcon.color` orqali
// (`ColorFilter.srcIn`) beriladi.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Solar "Chat Round Line" (Bold) — header.
const homeChatSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">'
    '<path fill-rule="evenodd" clip-rule="evenodd" fill="#FFFFFF" '
    'd="M10 20C15.5228 20 20 15.5228 20 10C20 4.47715 15.5228 0 10 0C4.47715 0 0 '
    '4.47715 0 10C0 11.5997 0.37562 13.1116 1.04346 14.4525C1.22094 14.8088 '
    '1.28001 15.2161 1.17712 15.6006L0.58151 17.8267C0.32295 18.793 1.20701 '
    '19.677 2.17335 19.4185L4.39939 18.8229C4.78393 18.72 5.19121 18.7791 '
    '5.54753 18.9565C6.88837 19.6244 8.4003 20 10 20ZM6 11.25C5.58579 11.25 5.25 '
    '11.5858 5.25 12C5.25 12.4142 5.58579 12.75 6 12.75H11.5C11.9142 12.75 12.25 '
    '12.4142 12.25 12C12.25 11.5858 11.9142 11.25 11.5 11.25H6ZM5.25 8.5C5.25 '
    '8.0858 5.58579 7.75 6 7.75H14C14.4142 7.75 14.75 8.0858 14.75 8.5C14.75 '
    '8.9142 14.4142 9.25 14 9.25H6C5.58579 9.25 5.25 8.9142 5.25 8.5Z"/></svg>';

/// Solar "Bell Bing" (Bold) — header.
const homeBellSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 20">'
    '<path fill="#FFFFFF" d="M5.35179 18.2418C6.19288 19.311 7.51418 20 9 '
    '20C10.4858 20 11.8071 19.311 12.6482 18.2418C10.2264 18.57 7.77357 18.57 '
    '5.35179 18.2418Z"/>'
    '<path fill-rule="evenodd" clip-rule="evenodd" fill="#FFFFFF" '
    'd="M15.7491 7.7041V7C15.7491 3.13401 12.7274 0 9 0C5.27256 0 2.25087 '
    '3.13401 2.25087 7V7.7041C2.25087 8.54909 2.00972 9.37517 1.5578 '
    '10.0782L0.450359 11.8012C-0.561176 13.3749 0.211046 15.5139 1.97036 '
    '16.0116C6.57274 17.3134 11.4273 17.3134 16.0296 16.0116C17.789 15.5139 '
    '18.5612 13.3749 17.5496 11.8012L16.4422 10.0782C15.9903 9.37517 15.7491 '
    '8.54909 15.7491 7.7041ZM9 3.25C9.41421 3.25 9.75 3.58579 9.75 4V8C9.75 '
    '8.41421 9.41421 8.75 9 8.75C8.58579 8.75 8.25 8.41421 8.25 8V4C8.25 3.58579 '
    '8.58579 3.25 9 3.25Z"/></svg>';

const _stroke =
    'fill="none" stroke="#FFFFFF" stroke-linecap="round" stroke-linejoin="round"';

/// Kalendar (chiziqli, nuqtasiz) — "Bugungi testlar".
const homeCalendarSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<g $_stroke stroke-width="1.6">'
    '<rect x="3.5" y="5" width="17" height="15.5" rx="3.6"/>'
    '<path d="M3.5 9.6H20.5M8 3.2V6.6M16 3.2V6.6"/></g></svg>';

/// Kutubxona (nav) — kitob + daftar.
const homeLibrarySvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<g $_stroke stroke-width="1.6">'
    '<rect x="3.4" y="3.4" width="6.2" height="17.2" rx="1.8"/>'
    '<rect x="11.6" y="3.4" width="9" height="17.2" rx="2"/>'
    '<path d="M15.2 3.6V8.4C15.2 9.2 16.6 9.2 16.6 8.2V3.6M14.2 17H16.6"/>'
    '</g></svg>';

/// Kutubxona (nav, faol) — xuddi shu siluet, to'ldirilgan (kesiklar evenodd).
const homeLibraryFilledSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<g fill="#FFFFFF" stroke="#FFFFFF" stroke-width="1.6" '
    'stroke-linejoin="round">'
    '<rect x="3.4" y="3.4" width="6.2" height="17.2" rx="1.8"/></g>'
    '<path fill="#FFFFFF" fill-rule="evenodd" d="M13.6 2.6H18.6A2.8 2.8 0 0 1 '
    '21.4 5.4V18.6A2.8 2.8 0 0 1 18.6 21.4H13.6A2.8 2.8 0 0 1 10.8 18.6V5.4'
    'A2.8 2.8 0 0 1 13.6 2.6ZM14.6 4.2V9.4L15.9 8.4L17.2 9.4V4.2ZM14.2 16.4'
    'H16.6A0.6 0.6 0 0 1 16.6 17.6H14.2A0.6 0.6 0 0 1 14.2 16.4Z"/></svg>';

/// Natijalar (nav) — chiziqli ustunlar.
const homeResultsSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<g $_stroke stroke-width="1.6">'
    '<path d="M3.6 20.6V12.6A2.4 2.4 0 0 1 8.4 12.6V20.6Z"/>'
    '<path d="M11.4 20.6V9.8A2.2 2.2 0 0 1 13.6 7.6H18.4A2.2 2.2 0 0 1 20.6 9.8'
    'V20.6Z"/>'
    '<path d="M12.6 7.6V5A1.6 1.6 0 0 1 15.8 5V7.6"/></g></svg>';

/// Rivojlanish (nav, faol) — xuddi shu siluet, to'ldirilgan.
const homeResultsFilledSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<g fill="#FFFFFF" stroke="#FFFFFF" stroke-width="1.6" '
    'stroke-linejoin="round">'
    '<path d="M3.6 20.6V12.6A2.4 2.4 0 0 1 8.4 12.6V20.6Z"/>'
    '<path d="M11.4 20.6V9.8A2.2 2.2 0 0 1 13.6 7.6H18.4A2.2 2.2 0 0 1 20.6 9.8'
    'V20.6Z"/>'
    '<path d="M12.6 7.6V5A1.6 1.6 0 0 1 15.8 5V7.6Z"/></g></svg>';

/// Kuchli yo'nalish — to'ldirilgan o'suvchi ustunlar.
const homeBarsSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<g fill="#FFFFFF">'
    '<rect x="2" y="12.5" width="5.2" height="9.5" rx="1.8"/>'
    '<rect x="9.4" y="7.5" width="5.2" height="14.5" rx="1.8"/>'
    '<rect x="16.8" y="2" width="5.2" height="20" rx="1.8"/></g></svg>';

/// Tavsiya — yuqoriga-o'ngga qalin strelka.
const homeArrowUpRightSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<g $_stroke stroke-width="3.4">'
    '<path d="M5 19L19 5M8.5 5H19V15.5"/></g></svg>';

/// Qidiruv — qalin chiziqli lupa (Testlar header).
const homeSearchSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<g $_stroke stroke-width="2.5">'
    '<circle cx="10.6" cy="10.6" r="7"/><path d="M15.8 15.8L21 21"/></g></svg>';

/// Orqaga — chapga strelka (ichki sahifalar header'i).
const homeBackSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<g $_stroke stroke-width="2.2"><path d="M15 5L8 12L15 19"/></g></svg>';

/// SVG ikon — oq chizilgan SVG'ni berilgan rangga bo'yaydi.
class HomeSvgIcon extends StatelessWidget {
  const HomeSvgIcon(this.svg, {super.key, required this.size, this.color});

  final String svg;
  final double size;

  /// `null` — SVG'ning o'z rangi (oq).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(
        svg,
        fit: BoxFit.contain,
        colorFilter: color == null
            ? null
            : ColorFilter.mode(color!, BlendMode.srcIn),
      ),
    );
  }
}
