import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/core/utils/extensions.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/primary_button.dart';
import 'package:farzandim/shared/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

/// Oila kodi ekrani — bola qo'shilgandan keyin shu ekranga o'tiladi.
///
/// Foydalanuvchi shu ekranda 5-raqamli oila kodini ko'radi va boshqa
/// ilovalar (WhatsApp, Telegram, SMS) orqali bola qurilmasiga yuboradi.
///
/// **Riverpod orqali bola olish:** route'da faqat `childId` keladi —
/// `ref.watch(childrenProvider)` orqali ro'yxatdan to'g'ri bolani topamiz.
/// Topilmasa Dashboard'ga qaytaramiz (masalan, ekranni reload qilsa,
/// state yo'qolib, childId topilmaydi).
///
/// **Yangi qurilma ulash** (Account Recovery Bosqich 2): "Yangi qurilma
/// ulash" tugmasi orqali eski Anonymous Auth UID bekor qilinadi va yangi
/// 5-raqamli familyCode generatsiya qilinadi (24 soatga). Bola yangi
/// qurilmasida shu kodni kiritsa, **eski child document'ga** ulanadi —
/// barcha xabarlar / zonalar / jadval saqlanadi (faqat
/// `linkedDeviceUid` o'zgaradi). Stream-based `childrenProvider`
/// Firestore yangilangach yangi kodni avtomatik refresh qiladi.
class FamilyCodeScreen extends ConsumerStatefulWidget {
  /// `FamilyCodeScreen` konstruktor.
  const FamilyCodeScreen({required this.childId, this.initialChild, super.key});

  /// Qaysi bolaning kodi ko'rsatilishi kerak (URL'dan).
  final String childId;

  /// AddChildScreen'dan to'g'ridan-to'g'ri kelgan Child obyekti
  /// (race condition oldini olish — childrenProvider GET javobini
  /// kutmasdan darhol ko'rsatish uchun).
  final Child? initialChild;

  @override
  ConsumerState<FamilyCodeScreen> createState() => _FamilyCodeScreenState();
}

class _FamilyCodeScreenState extends ConsumerState<FamilyCodeScreen> {
  bool _isRegenerating = false;

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenListProvider);
    // Initial — `state.extra` orqali AddChildScreen'dan kelgan bola.
    // Keyin (regenerate yoki refresh paytida) Riverpod ro'yxatidan.
    final child =
        children.firstWhereOrNull((c) => c.id == widget.childId) ??
        widget.initialChild;

    if (child == null) {
      // Reload yoki Riverpod state'i yo'q bo'lsa — Dashboard'ga qaytaramiz.
      // `addPostFrameCallback` — joriy frame tugagandan keyin go chaqiramiz
      // (build paytida navigatsiya qilib bo'lmaydi).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.dashboard);
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          // Pastki tugma fixed, qolgan content scrollable — kichik
          // ekranlarda ham "Yangi kod olish" tugmasi qoldirilmaydi.
          child: Column(
            children: [
              _Header(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: AppDimensions.md),
                  child: Column(
                    children: [
                      const SizedBox(height: AppDimensions.lg),
                      const _Illustration(),
                      const SizedBox(height: AppDimensions.xl),
                      const _TitleBlock(),
                      const SizedBox(height: AppDimensions.lg),
                      _CodeDisplay(code: child.familyCode),
                      const SizedBox(height: AppDimensions.sm),
                      _RegenerateCodeButton(
                        isLoading: _isRegenerating,
                        onPressed: _isRegenerating
                            ? null
                            : () => _onRegenerate(child.name),
                      ),
                    ],
                  ),
                ),
              ),
              _ShareButton(child: child),
              const SizedBox(height: AppDimensions.md),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirmation dialog → repository chaqirish → yangi kod modal.
  Future<void> _onRegenerate(String childName) async {
    final confirmed = await _confirmRegenerate(childName);
    if (!mounted || !confirmed) return;

    setState(() => _isRegenerating = true);

    final result = await ref
        .read(childActionsProvider.notifier)
        .regenerateFamilyCode(widget.childId);

    if (!mounted) return;
    setState(() => _isRegenerating = false);

    if (result.isSuccess) {
      // childrenProvider stream'i kodni avtomatik yangilaydi —
      // foydalanuvchiga modal'da yangi kodni ko'rsatamiz (copy + 24h info).
      await _showNewFamilyCodeDialog(result.data!, childName);
    } else {
      AppToast.error(
        context,
        'childManagement.familyCode.errorPrefix'.tr(
          namedArgs: {'error': result.error ?? ''},
        ),
      );
    }
  }

  /// Tasdiqlash dialog — eski qurilma uziladi, lekin xabarlar saqlanadi.
  /// Foydalanuvchi qo'rqmasligi uchun: sariq ogohlantirish va yashil
  /// "saqlanadi" karta.
  Future<bool> _confirmRegenerate(String childName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        title: Row(
          children: [
            Icon(Icons.smartphone, color: AppColors.accent),
            const SizedBox(width: AppDimensions.sm + 4),
            Expanded(
              child: Text(
                'childManagement.familyCode.regenerateConfirm.title'.tr(),
                style: AppTextStyles.headlineL.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'childManagement.familyCode.regenerateConfirm.question'.tr(
                namedArgs: {'name': childName},
              ),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            // Sariq ogohlantirish karta — nima o'zgaradi.
            _DialogInfoCard(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.warning,
              title: 'childManagement.familyCode.regenerateConfirm.warningTitle'
                  .tr(),
              titleColor: AppColors.warning,
              bullets: [
                'childManagement.familyCode.regenerateConfirm.warningBullet1'
                    .tr(),
                'childManagement.familyCode.regenerateConfirm.warningBullet2'
                    .tr(),
                'childManagement.familyCode.regenerateConfirm.warningBullet3'
                    .tr(),
              ],
            ),
            const SizedBox(height: AppDimensions.sm + 4),
            // Yashil ishonch karta — nima saqlanadi.
            _DialogInfoCard(
              icon: Icons.check_circle,
              iconColor: AppColors.accent,
              title: '',
              titleColor: AppColors.textPrimary,
              singleLine:
                  'childManagement.familyCode.regenerateConfirm.preservedNote'
                      .tr(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'childManagement.familyCode.regenerateConfirm.cancel'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
            ),
            child: Text(
              'childManagement.familyCode.regenerateConfirm.continue'.tr(),
              style: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Yangi familyCode dialog — monospace katta matn + nusxalash + Yopish.
  Future<void> _showNewFamilyCodeDialog(String code, String childName) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.accent),
            const SizedBox(width: AppDimensions.sm + 4),
            Expanded(
              child: Text(
                'childManagement.familyCode.newCodeDialog.title'.tr(),
                style: AppTextStyles.headlineL.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'childManagement.familyCode.newCodeDialog.instruction'.tr(
                namedArgs: {'name': childName},
              ),
              style: AppTextStyles.bodyM.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppDimensions.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.lg - 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: Center(
                child: Text(
                  code,
                  style: AppTextStyles.headlineXL.copyWith(
                    color: AppColors.accent,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.sm + 4),
            Center(
              child: Text(
                'childManagement.familyCode.newCodeDialog.expiryNote'.tr(),
                style: AppTextStyles.bodyS.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!ctx.mounted) return;
              AppToast.success(
                ctx,
                'childManagement.familyCode.newCodeDialog.copiedSnack'.tr(),
              );
            },
            icon: Icon(Icons.copy, color: AppColors.accent, size: 18),
            label: Text(
              'childManagement.familyCode.newCodeDialog.copy'.tr(),
              style: AppTextStyles.bodyM.copyWith(color: AppColors.accent),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
            ),
            child: Text('childManagement.familyCode.newCodeDialog.close'.tr()),
          ),
        ],
      ),
    );
  }
}

/// `_confirmRegenerate` dialog'idagi sariq/yashil info karta.
///
/// `bullets` berilgan bo'lsa marker bilan bir nechta qator (sariq
/// "Diqqat" karta uchun). `singleLine` berilgan bo'lsa bitta qator
/// (yashil "saqlanadi" karta uchun) — `title` bo'sh `''` qoldiriladi.
class _DialogInfoCard extends StatelessWidget {
  const _DialogInfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    this.bullets,
    this.singleLine,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final List<String>? bullets;
  final String? singleLine;

  @override
  Widget build(BuildContext context) {
    final isSingle = singleLine != null;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm + 4),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM - 4),
      ),
      child: isSingle
          ? Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Text(
                    singleLine!,
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 18),
                    const SizedBox(width: AppDimensions.sm),
                    Text(
                      title,
                      style: AppTextStyles.label.copyWith(
                        color: titleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.sm),
                ...?bullets?.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '•  ',
                          style: AppTextStyles.bodyS.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            b,
                            style: AppTextStyles.bodyS.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ════════════════════════ KICHIK WIDGET'LAR ════════════════════════

/// Tepa qator: chap — back tugma, markaz — sarlavha, o'ng — bo'sh joy
/// (sarlavhani markazda saqlab turish uchun).
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.lg,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go(AppRoutes.dashboard),
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.sm),
              child: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
                size: AppDimensions.iconM,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'childManagement.familyCode.headerTitle'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Back tugma kompensatsiyasi (24 icon + 8*2 padding = 40dp)
          // — sarlavhani haqiqiy markazda saqlash uchun.
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// Oila illyustratsiyasi — `assets/images/family_illustration.png`.
class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/family_illustration.png',
      width: 240,
      height: 240,
      fit: BoxFit.contain,
    );
  }
}

/// Sarlavha bloki: "Ilovani o'rnating" + ostida tushuntirish.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'childManagement.familyCode.title'.tr(),
          style: AppTextStyles.headlineL,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.sm),
        Text(
          'childManagement.familyCode.subtitle'.tr(),
          style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// 5-raqamli oila kodi pill ichida — har raqam orasida bo'shliq
/// ("2 4 3 7 0").
class _CodeDisplay extends StatelessWidget {
  const _CodeDisplay({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: SettingsCard(
        accent: AppColors.primary,
        padding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: AppDimensions.xl,
        ),
        child: Center(
          child: Text(
            // "24370" → "2 4 3 7 0"
            code.split('').join(' '),
            style: AppTextStyles.bodyM.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lime green outlined refresh tugmasi — yangi pairing kod olish.
///
/// Pill shaklida, primary border (50% alpha), refresh ikon va matn
/// `AppColors.primary` rangda. `isLoading == true` bo'lsa ikon
/// o'rnida 16dp `CircularProgressIndicator` va matn "Yaratilmoqda...".
class _RegenerateCodeButton extends StatelessWidget {
  const _RegenerateCodeButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimensions.radiusPill);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      child: SizedBox(
        width: double.infinity,
        height: AppDimensions.buttonHeight,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
            borderRadius: borderRadius,
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: borderRadius,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  else
                    Icon(Icons.smartphone, size: 18, color: AppColors.accent),
                  const SizedBox(width: AppDimensions.sm),
                  Text(
                    isLoading
                        ? 'childManagement.familyCode.regenerating'.tr()
                        : 'childManagement.familyCode.regenerateButton'.tr(),
                    style: AppTextStyles.bodyM.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
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

/// Pastdagi share tugma — native share sheet ochadi.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      child: PrimaryButton(
        label: 'childManagement.familyCode.shareButton'.tr(),
        icon: Icons.share,
        onPressed: () => _share(child),
      ),
    );
  }

  Future<void> _share(Child child) async {
    final message = 'childManagement.familyCode.shareMessage'.tr(
      namedArgs: {'code': child.familyCode},
    );
    final subject = 'childManagement.familyCode.shareSubject'.tr();
    await Share.share(message, subject: subject);
  }
}
