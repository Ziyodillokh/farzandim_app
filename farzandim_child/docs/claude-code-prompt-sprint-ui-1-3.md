# Sprint UI.1-3: Theme Refresh (Colors + Buttons + Icons)

## Project context
- **App**: Farzandim Child App (Flutter)
- **Path**: `~/Projects/farzandim_child`
- **Backend**: `~/Projects/farzandim-backend` (REST API, JWT auth, ZRU-547 compliance)
- **Target users**: Children ages 3-14, Uzbek language
- **Design reference**: Duolingo, Khan Kids, Buddy.ai (maksimal playful)
- **Critical constraint**: UI structure stays — only colors, buttons, icons change.

## Goal
Production-grade theme refresh in 3 sprints. Visual transformation Duolingo-style without touching app architecture, navigation, or screen layouts.

## Acceptance criteria
1. App builds and runs on both Android and iOS without errors.
2. All existing screens still functional (no broken navigation, no missing widgets).
3. Backwards compatibility: any feature that worked before still works.
4. Code formatted, no lint warnings (run `flutter analyze`).
5. Real device test: 3 different screens screenshot before/after for comparison.

---

## Sprint UI.1: Color System (Week 1)

### Step 1: Audit current theme

Before any changes, explore and document:
```
1. Find all current color definitions:
   - lib/core/theme/ (or wherever theme is)
   - lib/main.dart (MaterialApp theme)
   - Any hardcoded Color(0xFF...) in widgets
   
2. List every Color() reference with file:line
3. Find current ThemeData configuration
4. Document in a SCRATCH.md (delete after sprint done)
```

### Step 2: Create new color palette

Create `lib/core/theme/app_colors.dart` (or overwrite existing):

```dart
import 'package:flutter/material.dart';

/// Farzandim Child App Color System
/// 
/// Inspired by Duolingo design language.
/// All colors WCAG AA compliant for child users (3-14).
/// 
/// Usage guidelines:
/// - primary: Main CTA buttons, success states, FARO accent
/// - secondary: Info, location, navigation hints
/// - accent: Rewards, stars, balls, achievements (rare use)
/// - warning: Battery low, schedule warnings
/// - danger: Emergency only, SOS (very rare)
class AppColors {
  AppColors._();

  // ============ PRIMARY (Duolingo Green) ============
  static const Color primary = Color(0xFF58CC02);
  static const Color primaryHover = Color(0xFF46A302);
  static const Color primaryDisabled = Color(0xFF9CCC65);
  static const Color primaryShadow = Color(0xFF46A302); // 3D button bottom

  // ============ SECONDARY (Friendly Blue) ============
  static const Color secondary = Color(0xFF1CB0F6);
  static const Color secondaryHover = Color(0xFF0E96D6);
  static const Color secondaryShadow = Color(0xFF0E96D6);

  // ============ ACCENT (Sunshine Yellow) ============
  static const Color accent = Color(0xFFFFC800);
  static const Color accentHover = Color(0xFFE5B400);
  static const Color accentShadow = Color(0xFFE5B400);

  // ============ STATUS ============
  static const Color warning = Color(0xFFFF9600);
  static const Color warningShadow = Color(0xFFCC7700);
  
  static const Color danger = Color(0xFFFF4B4B);
  static const Color dangerShadow = Color(0xFFCC3030);
  
  static const Color success = primary;
  static const Color info = secondary;

  // ============ BACKGROUNDS (Light Mode) ============
  static const Color bgPrimary = Color(0xFFFFFFFF);
  static const Color bgSurface = Color(0xFFF7F7F7);
  static const Color bgAccent = Color(0xFFFFF8E7);  // Soft yellow
  static const Color bgSky = Color(0xFFE0F2FE);    // Cosmic sky

  // ============ BACKGROUNDS (Dark Mode) ============
  static const Color bgPrimaryDark = Color(0xFF131F24);
  static const Color bgSurfaceDark = Color(0xFF1E2D32);
  static const Color bgCardDark = Color(0xFF2D4147);

  // ============ TEXT ============
  static const Color textPrimary = Color(0xFF1A2B3B);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);  // White on green
  static const Color textOnAccent = Color(0xFF1A2B3B);   // Dark on yellow

  // ============ DIVIDERS / BORDERS ============
  static const Color divider = Color(0xFFE2E8F0);
  static const Color border = Color(0xFFCBD5E0);

  // ============ SHADOWS ============
  static const Color shadowLight = Color(0x0F1A2B3B); // 6% opacity
  static const Color shadowMedium = Color(0x141A2B3B); // 8% opacity
  static const Color shadowFAB = Color(0x29FFC800);   // 16% accent

  // ============ UZBEK PRIDE (use sparingly, <5%) ============
  static const Color uzbFlagBlue = Color(0xFF1EB5E5);
  static const Color uzbFlagRed = Color(0xFFCE1126);
  static const Color uzbFlagGreen = Color(0xFF1EAF53);
}
```

### Step 3: Update ThemeData

Find current `ThemeData` in `lib/main.dart` or `lib/core/theme/app_theme.dart`. Create or update `app_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Light theme — primary use case for children (better readability)
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.textOnPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.textOnPrimary,
      tertiary: AppColors.accent,
      onTertiary: AppColors.textOnAccent,
      surface: AppColors.bgSurface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      onError: AppColors.textOnPrimary,
    ),
    
    textTheme: GoogleFonts.interTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgPrimary,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.fredoka(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    
    cardTheme: CardThemeData(
      color: AppColors.bgPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.zero,
    ),
    
    dividerColor: AppColors.divider,
  );

  /// Dark theme — for evening use
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.bgPrimaryDark,
    
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.textOnPrimary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: AppColors.bgCardDark,
      error: AppColors.danger,
    ),
    
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  );
}
```

### Step 4: Add google_fonts dependency

```bash
cd ~/Projects/farzandim_child
flutter pub add google_fonts
```

Verify `pubspec.yaml` has:
```yaml
dependencies:
  google_fonts: ^6.1.0
```

### Step 5: Apply theme

Update `lib/main.dart`:

```dart
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ThemeMode.light, // Default light, allow user override later
  // ... rest of config
)
```

### Step 6: Refactor hardcoded colors

Find all `Color(0xFF...)` references in widgets and replace with `AppColors.X`. Use semantic mapping:
- Old blue accent → `AppColors.secondary`
- Old buttons → `AppColors.primary`
- Background colors → `AppColors.bgPrimary` / `bgSurface`

DO NOT change layout, padding, dimensions — only colors.

### Step 7: Test & verify

```bash
flutter clean
flutter pub get
flutter run -d <device>
```

Manual checklist:
- [ ] App launches without crash
- [ ] All screens render
- [ ] Text is readable (contrast)
- [ ] No yellow text on white backgrounds (a11y)
- [ ] Buttons visible against backgrounds
- [ ] `flutter analyze` shows 0 errors

Screenshot 5 screens for before/after comparison.

---

## Sprint UI.2: Buttons (Days 8-12)

### Step 1: Create PlayfulButton widget

Create `lib/widgets/playful_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';

/// Duolingo-style 3D button with shadow + press animation.
/// 
/// Features:
/// - 4px bottom shadow that creates "raised" feel
/// - Press animation: scale 0.97 + haptic feedback
/// - Disabled state with 50% opacity
/// - Loading state with CircularProgressIndicator
/// 
/// Usage:
/// ```dart
/// PlayfulButton(
///   label: 'YUBORISH',
///   onPressed: () => doSomething(),
///   variant: ButtonVariant.primary,
/// )
/// ```
class PlayfulButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final double height;

  const PlayfulButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.height = 56,
  });

  @override
  State<PlayfulButton> createState() => _PlayfulButtonState();
}

class _PlayfulButtonState extends State<PlayfulButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  Color _getMainColor() {
    switch (widget.variant) {
      case ButtonVariant.primary:
        return AppColors.primary;
      case ButtonVariant.secondary:
        return AppColors.secondary;
      case ButtonVariant.accent:
        return AppColors.accent;
      case ButtonVariant.warning:
        return AppColors.warning;
      case ButtonVariant.danger:
        return AppColors.danger;
      case ButtonVariant.outlined:
        return Colors.transparent;
    }
  }

  Color _getShadowColor() {
    switch (widget.variant) {
      case ButtonVariant.primary:
        return AppColors.primaryShadow;
      case ButtonVariant.secondary:
        return AppColors.secondaryShadow;
      case ButtonVariant.accent:
        return AppColors.accentShadow;
      case ButtonVariant.warning:
        return AppColors.warningShadow;
      case ButtonVariant.danger:
        return AppColors.dangerShadow;
      case ButtonVariant.outlined:
        return AppColors.divider;
    }
  }

  Color _getTextColor() {
    switch (widget.variant) {
      case ButtonVariant.accent:
        return AppColors.textOnAccent;
      case ButtonVariant.outlined:
        return AppColors.primary;
      default:
        return AppColors.textOnPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final mainColor = _getMainColor();
    final shadowColor = _getShadowColor();
    final textColor = _getTextColor();

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) {
          setState(() => _isPressed = true);
          HapticFeedback.lightImpact();
        },
        onTapUp: isDisabled ? null : (_) {
          setState(() => _isPressed = false);
        },
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          width: widget.fullWidth ? double.infinity : null,
          height: widget.height,
          margin: EdgeInsets.only(bottom: _isPressed ? 0 : 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isPressed
                ? []
                : [
                    BoxShadow(
                      color: shadowColor,
                      offset: const Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: mainColor,
              borderRadius: BorderRadius.circular(16),
              border: widget.variant == ButtonVariant.outlined
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: textColor,
                        strokeWidth: 3,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: textColor, size: 22),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

enum ButtonVariant {
  primary,
  secondary,
  accent,
  warning,
  danger,
  outlined,
}
```

### Step 2: Create PlayfulIconButton

Create `lib/widgets/playful_icon_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';

/// Round icon button for top bar, FAB actions.
/// 
/// Usage:
/// ```dart
/// PlayfulIconButton(
///   icon: PhosphorIcons.bold.bell,
///   onPressed: () => showNotifications(),
/// )
/// ```
class PlayfulIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;

  const PlayfulIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
    this.iconSize = 24,
  });

  @override
  State<PlayfulIconButton> createState() => _PlayfulIconButtonState();
}

class _PlayfulIconButtonState extends State<PlayfulIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppColors.bgAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: widget.iconColor ?? AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
```

### Step 3: Create VoiceFAB widget

Create `lib/widgets/voice_fab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
// Replace with actual phosphor import
// import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Voice recording FAB with pulse animation when active.
class VoiceFAB extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isRecording;

  const VoiceFAB({
    super.key,
    this.onPressed,
    this.isRecording = false,
  });

  @override
  State<VoiceFAB> createState() => _VoiceFABState();
}

class _VoiceFABState extends State<VoiceFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onPressed?.call();
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = widget.isRecording
              ? 1.0 + (_pulseController.value * 0.1)
              : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: widget.isRecording ? AppColors.danger : AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (widget.isRecording
                            ? AppColors.danger
                            : AppColors.accent)
                        .withOpacity(0.4),
                    offset: const Offset(0, 4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Icon(
                widget.isRecording ? Icons.stop : Icons.mic,
                color: AppColors.textPrimary,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}
```

### Step 4: Refactor existing buttons

Find all `ElevatedButton`, `TextButton`, `OutlinedButton` usages and replace:

**Before:**
```dart
ElevatedButton(
  onPressed: _save,
  child: const Text('Saqlash'),
)
```

**After:**
```dart
PlayfulButton(
  label: 'SAQLASH',
  onPressed: _save,
  variant: ButtonVariant.primary,
)
```

**Strategy:**
1. Find all button usages: `grep -rn "ElevatedButton\|TextButton\|OutlinedButton" lib/`
2. List in SCRATCH.md
3. Replace one screen at a time
4. Test after each screen
5. Commit per screen

### Step 5: Verify

```bash
flutter analyze
flutter run -d <device>
```

Test on each screen:
- [ ] Buttons render correctly
- [ ] Press animation works (shadow disappears)
- [ ] Haptic feedback feels right
- [ ] Disabled state visible
- [ ] No layout shifts

---

## Sprint UI.3: Icons (Days 13-16)

### Step 1: Add Phosphor Icons dependency

```bash
cd ~/Projects/farzandim_child
flutter pub add phosphor_flutter
```

Verify `pubspec.yaml`:
```yaml
dependencies:
  phosphor_flutter: ^2.0.0
```

### Step 2: Icon mapping documentation

Create `lib/core/theme/app_icons.dart`:

```dart
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Centralized icon definitions using Phosphor Icons.
/// 
/// Style: Bold weight for primary actions, Regular for secondary.
/// Always use these constants instead of direct PhosphorIcons calls.
class AppIcons {
  AppIcons._();

  // ============ NAVIGATION ============
  static final home = PhosphorIcons.bold(PhosphorIconsBold.house);
  static final voice = PhosphorIcons.bold(PhosphorIconsBold.microphone);
  static final location = PhosphorIcons.bold(PhosphorIconsBold.mapPin);
  static final schedule = PhosphorIcons.bold(PhosphorIconsBold.clock);
  static final settings = PhosphorIcons.bold(PhosphorIconsBold.gear);
  static final profile = PhosphorIcons.bold(PhosphorIconsBold.userCircle);

  // ============ VOICE / AUDIO ============
  static final play = PhosphorIconsBold.play;
  static final pause = PhosphorIconsBold.pause;
  static final stop = PhosphorIconsBold.stop;
  static final replay = PhosphorIconsBold.arrowCounterClockwise;
  static final mic = PhosphorIconsBold.microphone;
  static final micOff = PhosphorIconsBold.microphoneSlash;

  // ============ ACTIONS ============
  static final send = PhosphorIconsBold.paperPlaneTilt;
  static final reply = PhosphorIconsBold.arrowBendUpLeft;
  static final delete = PhosphorIconsBold.trash;
  static final edit = PhosphorIconsBold.pencilSimple;
  static final close = PhosphorIconsBold.x;
  static final check = PhosphorIconsBold.check;
  static final add = PhosphorIconsBold.plus;
  static final back = PhosphorIconsBold.caretLeft;
  static final forward = PhosphorIconsBold.caretRight;

  // ============ STATUS ============
  static final success = PhosphorIconsBold.checkCircle;
  static final warning = PhosphorIconsBold.warning;
  static final error = PhosphorIconsBold.xCircle;
  static final info = PhosphorIconsBold.info;

  // ============ NOTIFICATIONS ============
  static final bell = PhosphorIconsBold.bell;
  static final bellOff = PhosphorIconsBold.bellSlash;
  static final message = PhosphorIconsBold.chatCircle;

  // ============ SCHEDULE ============
  static final scheduleActive = PhosphorIconsBold.timer;
  static final scheduleInactive = PhosphorIconsBold.timerX;
  static final calendar = PhosphorIconsBold.calendarBlank;

  // ============ LOCATION ============
  static final mapPin = PhosphorIconsBold.mapPin;
  static final geoZone = PhosphorIconsBold.mapTrifold;
  static final navigation = PhosphorIconsBold.navigationArrow;

  // ============ SETTINGS ============
  static final language = PhosphorIconsBold.translate;
  static final privacy = PhosphorIconsBold.shieldCheck;
  static final about = PhosphorIconsBold.info;
  static final logout = PhosphorIconsBold.signOut;

  // ============ REWARDS (kelajak, FARO) ============
  static final star = PhosphorIconsBold.star;
  static final trophy = PhosphorIconsBold.trophy;
  static final streak = PhosphorIconsBold.fire;
  static final gift = PhosphorIconsBold.gift;
  static final medal = PhosphorIconsBold.medal;
}
```

### Step 3: Replace Material Icons

Strategy: find and replace in priority order.

```bash
# Find all Icons.xxx usages
grep -rn "Icon(Icons\." lib/ > /tmp/icon-audit.txt
```

For each match, replace with AppIcons equivalent:
- `Icons.home` → `AppIcons.home`
- `Icons.mic` → `AppIcons.mic`
- `Icons.location_on` → `AppIcons.mapPin`
- `Icons.access_time` → `AppIcons.schedule`
- `Icons.settings` → `AppIcons.settings`
- `Icons.person` → `AppIcons.profile`
- `Icons.send` → `AppIcons.send`
- `Icons.play_arrow` → `AppIcons.play`
- `Icons.pause` → `AppIcons.pause`
- `Icons.check_circle` → `AppIcons.success`
- `Icons.warning` → `AppIcons.warning`
- `Icons.error` → `AppIcons.error`
- `Icons.notifications` → `AppIcons.bell`
- `Icons.close` → `AppIcons.close`
- `Icons.check` → `AppIcons.check`
- `Icons.add` → `AppIcons.add`
- `Icons.arrow_back` → `AppIcons.back`
- `Icons.arrow_forward` → `AppIcons.forward`

**Important:** Keep sizes and colors. Only swap the icon reference.

**Before:**
```dart
const Icon(Icons.mic, size: 24, color: Colors.blue)
```

**After:**
```dart
Icon(AppIcons.mic, size: 24, color: AppColors.secondary)
```

### Step 4: Verify

```bash
flutter analyze
flutter run -d <device>
```

- [ ] All icons render (no missing icon squares)
- [ ] Sizes consistent
- [ ] Colors match palette
- [ ] No layout shifts

---

## Final verification (Day 17)

### Automated checks
```bash
cd ~/Projects/farzandim_child
flutter clean
flutter pub get
flutter analyze              # Should show 0 issues
flutter test                 # Existing tests still pass
flutter build apk --debug    # Android builds
flutter build ios --debug    # iOS builds (if Mac)
```

### Manual QA — screens to test
Test these screens in order. Take before/after screenshot for each:

1. Splash / Onboarding (if exists)
2. Dashboard / Home
3. Voice messages list
4. Voice player / detail
5. Schedule list
6. Schedule create/edit
7. Location screen
8. Settings
9. Profile

### Git workflow

```bash
# Sprint UI.1
git add lib/core/theme/
git commit -m "feat(theme): add Duolingo-inspired color system (Sprint UI.1)

- New AppColors with primary green #58CC02
- ThemeData light/dark with google_fonts Inter
- Refactor hardcoded Color(0xFF...) → AppColors.X"

# Sprint UI.2
git add lib/widgets/playful_button.dart lib/widgets/playful_icon_button.dart lib/widgets/voice_fab.dart
git commit -m "feat(widgets): add Playful 3D button system (Sprint UI.2)

- PlayfulButton with shadow + press animation
- PlayfulIconButton for top bar actions
- VoiceFAB with pulse animation for recording
- Haptic feedback on all interactions"

# Refactor commit
git add -A
git commit -m "refactor: migrate ElevatedButton → PlayfulButton across all screens"

# Sprint UI.3
git add lib/core/theme/app_icons.dart pubspec.yaml pubspec.lock
git commit -m "feat(icons): switch to Phosphor Icons (Sprint UI.3)

- Add phosphor_flutter dependency
- AppIcons centralized definitions (bold weight)
- Replace Material Icons across all screens"

git push origin main
```

---

## Constraints & guardrails

**DO:**
- Read each existing file before modifying.
- Make small commits per logical change.
- Run `flutter analyze` after every significant edit.
- Test on real device after each sprint.
- Keep existing screen layouts identical.
- Preserve all existing functionality.

**DON'T:**
- Change navigation structure.
- Modify widget tree depth or hierarchy.
- Touch business logic, API calls, state management.
- Add new screens or remove existing ones.
- Change `pubspec.yaml` beyond adding `google_fonts` and `phosphor_flutter`.
- Skip tests or `flutter analyze` checks.

**If you find broken code or unclear logic:**
- Note it in `SCRATCH.md`
- Do NOT fix it (out of scope)
- Surface it to the user at sprint end

**If you encounter ambiguity:**
- Stop and ask the user
- Provide 2-3 options
- Wait for decision

---

## Output expectations

When sprint complete, provide:

1. **Sprint summary** in `~/Projects/farzandim_child/docs/sprint-ui-1-3-summary.md`:
   - What changed (file list)
   - What stayed the same
   - Known issues
   - Next steps

2. **Visual evidence**:
   - Before/after screenshots saved to `~/Projects/farzandim_child/docs/screenshots/`
   - 5+ key screens

3. **Metrics**:
   - Total files modified
   - Lines added/removed
   - `flutter analyze` final status
   - Build time before vs after

4. **Recommendations**:
   - Did anything take longer than expected?
   - Any technical debt accumulated?
   - Suggestions for Sprint UI.4 (animations)?

---

## Time budget

- **Sprint UI.1 (Colors)**: 5-7 days
- **Sprint UI.2 (Buttons)**: 4-5 days
- **Sprint UI.3 (Icons)**: 3-4 days
- **Total**: 12-16 days (2-2.5 weeks)

If exceeding 3 weeks total — STOP and consult user. Means scope is wrong.

---

## Done definition

✅ All 3 sprints merged to `main` branch
✅ `flutter analyze` shows 0 issues
✅ App builds and runs on Android + iOS
✅ All existing functionality preserved
✅ Before/after screenshots in docs/
✅ Sprint summary committed
✅ User has reviewed and approved

🚀 Ready to begin Sprint UI.4 (Animations) — next session.
