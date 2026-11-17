// Growth v5 ekranlari uchun Material mavzusi: ilova umumiy mavzusi yorug'
// bo'lishi mumkin, v5 ekranlari esa doim to'q — klaviatura, tanlov tutqichlari,
// kursor va RefreshIndicator ham shunga mos bo'lsin.

import 'package:farzandim_child/design/tokens.dart';
import 'package:flutter/material.dart';

abstract final class GTheme {
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: GColors.bg,
    canvasColor: GColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: GColors.primary,
      onPrimary: GColors.white,
      secondary: GColors.sky,
      surface: Color(0xFF0B1022),
      onSurface: GColors.text,
      error: GColors.danger,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: GColors.primary,
      selectionColor: Color(0x664F86FF),
      selectionHandleColor: GColors.primary,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: GColors.divider,
  );
}
