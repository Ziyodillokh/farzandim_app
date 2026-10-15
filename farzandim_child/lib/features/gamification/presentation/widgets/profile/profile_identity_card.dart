// Profil — shaxsiy karta: avatar (bosilsa akkauntni tahrirlash), ism,
// sinf + qurilma • batareya.
//
// Avatar: yuklangan rasm (`childAvatarUrlProvider`), bo'lmasa bolaning
// jinsi + yoshiga mos default avatar, u ham bo'lmasa bosh harf.
// Qurilma qatori faqat REAL qiymatlar — aniqlanmagan qism yashiriladi.

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/providers/child_data_provider.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/gamification/presentation/widgets/profile/learning_profile_card.dart';
import 'package:farzandim_child/features/learning/presentation/providers/learning_providers.dart';
import 'package:farzandim_child/features/pairing/presentation/providers/pairing_provider.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';

const _avatarSize = 66.0;
const _cardTop = Color(0xFF0D2038);

/// Batareya shu foizdan past bo'lsa "kam" ikoni.
const _batteryLow = 20;
const _batteryHalf = 60;

/// Qurilma nomi + batareya foizi — REAL qiymatlar. Aniqlab bo'lmagan qism
/// `null` (UI uni yashiradi).
final _deviceLineProvider = FutureProvider<(String?, int?)>((ref) async {
  String? model;
  int? battery;
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final a = await DeviceInfoPlugin().androidInfo;
      model = '${a.brand} ${a.model}';
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final i = await DeviceInfoPlugin().iosInfo;
      // `modelName` — "iPhone 15 Pro" kabi tijoriy nom; bo'lmasa "iPhone".
      model = i.modelName.trim().isNotEmpty ? i.modelName : i.model;
    }
  } catch (e) {
    debugPrint('[Profile] qurilma nomi aniqlanmadi: $e');
  }
  try {
    final level = await Battery().batteryLevel;
    // iOS simulyatorda/aniqlanmaganda -1 qaytishi mumkin.
    if (level >= 0 && level <= 100) battery = level;
  } catch (e) {
    debugPrint('[Profile] batareya aniqlanmadi: $e');
  }
  return (model, battery);
});

/// Jins + yoshga mos default avatar asset yo'li (parent app mantiqidek).
///   - `female` → yoshga qarab 3 xil: <10 → 6_10, 10-13 → 10_14, ≥14 → 14
///   - aks holda (male yoki noma'lum) → bitta `boy.png`
String _defaultAvatarPath(String? gender, int? age) {
  if (gender != 'female') return 'assets/default_avatars/boy.png';
  final a = age ?? 6;
  final band = a >= 14
      ? '14'
      : a >= 10
      ? '10_14'
      : '6_10';
  return 'assets/default_avatars/girl_$band.png';
}

class ProfileIdentityCard extends ConsumerWidget {
  const ProfileIdentityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairing = ref.watch(pairingStateProvider);
    final childId = pairing.childId;
    final parentUid = pairing.parentUid;
    final hasChild = childId != null && childId.isNotEmpty;
    final rawName = pairing.childName?.trim() ?? '';
    final name = rawName.isNotEmpty ? rawName : 'common.fallbackChildName'.tr();

    final avatarUrl = hasChild
        ? ref.watch(childAvatarUrlProvider(childId)).valueOrNull
        : null;
    final childData = (hasChild && parentUid != null)
        ? ref
              .watch(
                childDataStreamProvider((
                  parentUid: parentUid,
                  childId: childId,
                )),
              )
              .valueOrNull
        : null;
    final gender = childData?['gender'];
    final age = childData?['age'];
    final avatarAsset = _defaultAvatarPath(
      gender is String ? gender : null,
      age is num ? age.toInt() : null,
    );

    final device = ref.watch(_deviceLineProvider).valueOrNull;
    final grade = ref.watch(learningProfileProvider)?.grade;
    final hasDevice =
        device != null && (device.$1 != null || device.$2 != null);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeColors.cardBorder),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cardTop, HomeColors.card],
        ),
      ),
      child: Row(
        children: [
          _Avatar(
            url: avatarUrl,
            assetPath: avatarAsset,
            name: name,
            onTap: () => context.push('/account-edit'),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: homeDisplay(20, letterSpacing: -0.2),
                ),
                if (grade != null || hasDevice) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (grade != null) GradeChip(grade: grade),
                      if (hasDevice)
                        _DeviceLine(model: device.$1, battery: device.$2),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.assetPath,
    required this.name,
    required this.onTap,
  });

  final String? url;
  final String assetPath;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final link = url;
    final fallback = _AvatarFallback(assetPath: assetPath, name: name);
    return Semantics(
      button: true,
      label: 'settings.editProfile'.tr(),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: _avatarSize,
          height: _avatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: _avatarSize,
                height: _avatarSize,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: HomeColors.primary.withValues(alpha: 0.65),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HomeColors.primary.withValues(alpha: 0.25),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: (link != null && link.isNotEmpty)
                      ? Image.network(
                          link,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => fallback,
                        )
                      : fallback,
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: HomeColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: HomeColors.card, width: 2),
                  ),
                  child: const Icon(
                    SolarIconsBold.pen,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Default avatar; asset yuklanmasa — bosh harf (eng oxirgi zaxira).
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.assetPath, required this.name});

  final String assetPath;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      cacheWidth: 256,
      errorBuilder: (_, _, _) => Container(
        color: HomeColors.primary,
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
          style: homeDisplay(26),
        ),
      ),
    );
  }
}

/// "iPhone 15 Pro • 🔋 98%" — faqat aniqlangan qismlar.
class _DeviceLine extends StatelessWidget {
  const _DeviceLine({required this.model, required this.battery});

  final String? model;
  final int? battery;

  @override
  Widget build(BuildContext context) {
    final style = homeText(12.5, color: HomeColors.textDim, height: 1.2);
    final m = model;
    final b = battery;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (m != null) ...[
          const Icon(
            SolarIconsOutline.smartphone,
            size: 14,
            color: HomeColors.textDim,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              m,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
        if (m != null && b != null) Text('  •  ', style: style),
        if (b != null) ...[
          Icon(_batteryIcon(b), size: 15, color: _batteryColor(b)),
          const SizedBox(width: 3),
          Text('$b%', maxLines: 1, style: style),
        ],
      ],
    );
  }

  static IconData _batteryIcon(int level) {
    if (level < _batteryLow) return SolarIconsOutline.batteryLow;
    if (level < _batteryHalf) return SolarIconsOutline.batteryHalf;
    return SolarIconsOutline.batteryFull;
  }

  static Color _batteryColor(int level) =>
      level < _batteryLow ? HomeColors.orange : HomeColors.textDim;
}
