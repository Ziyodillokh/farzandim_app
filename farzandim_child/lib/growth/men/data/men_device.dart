// Shu qurilmadagi holat: ruxsatlar (I05, faqat ko'rish), qurilma nomi (I04)
// va matn o'lchami (I04 — butun v5 interfeysiga qo'llanadi).

import 'package:device_info_plus/device_info_plus.dart';
import 'package:farzandim_child/core/platform/platform_capabilities.dart';
import 'package:farzandim_child/features/app_restrictions/data/services/health_steps_service.dart';
import 'package:farzandim_child/features/app_restrictions/presentation/providers/usage_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ruxsat holati: yoqilgan / o'chirilgan / bu qurilmada mavjud emas.
enum PermissionState { on, off, unavailable }

@immutable
class MyPermissions {
  const MyPermissions({
    required this.location,
    required this.steps,
    required this.device,
    required this.screenTime,
  });

  final PermissionState location;
  final PermissionState steps;

  /// Batareya va model — ruxsatsiz yuboriladi (doim yoqilgan).
  final PermissionState device;

  /// iPhone'da ekran vaqti qurilmadan chiqmaydi — «Mavjud emas».
  final PermissionState screenTime;

  int get enabledCount => [
    location,
    steps,
    device,
    screenTime,
  ].where((s) => s == PermissionState.on).length;
}

abstract interface class MyPermissionsSource {
  Future<MyPermissions> read();
}

class DeviceMyPermissionsSource implements MyPermissionsSource {
  const DeviceMyPermissionsSource(this._ref);

  final Ref _ref;

  @override
  Future<MyPermissions> read() async {
    Future<PermissionState> state(Future<bool> Function() check) async {
      try {
        return await check() ? PermissionState.on : PermissionState.off;
      } on Object {
        return PermissionState.off;
      }
    }

    return MyPermissions(
      location: await state(() => Permission.location.isGranted),
      steps: await state(HealthStepsService.instance.hasPermission),
      device: PermissionState.on,
      screenTime: PlatformCapabilities.canUploadAppUsage
          ? await state(_ref.read(usageStatsServiceProvider).hasPermission)
          : PermissionState.unavailable,
    );
  }
}

final myPermissionsSourceProvider = Provider<MyPermissionsSource>(
  DeviceMyPermissionsSource.new,
);

final myPermissionsProvider = FutureProvider.autoDispose<MyPermissions>(
  (ref) => ref.watch(myPermissionsSourceProvider).read(),
);

/// Bu qurilma nomi («Galaxy A15» / «iPhone 13»).
final thisDeviceNameProvider = FutureProvider<String?>((ref) async {
  try {
    final info = DeviceInfoPlugin();
    if (PlatformCapabilities.isIOS) {
      final ios = await info.iosInfo;
      // `name` — foydalanuvchi bergan nom (ism bo'lishi mumkin) — olinmaydi.
      return ios.model;
    }
    if (PlatformCapabilities.isAndroid) {
      final android = await info.androidInfo;
      return android.model;
    }
  } on Object catch (e) {
    debugPrint('[men] qurilma nomi o\'qilmadi: ${e.runtimeType}');
  }
  return null;
});

/// Matn o'lchami: Oddiy / Katta / Juda katta.
enum G5TextSize {
  normal(1),
  large(1.15),
  extraLarge(1.3);

  const G5TextSize(this.factor);

  final double factor;
}

const _textSizeKey = 'g5_text_size_v1';

final g5TextSizeProvider =
    AsyncNotifierProvider<G5TextSizeNotifier, G5TextSize>(
      G5TextSizeNotifier.new,
    );

class G5TextSizeNotifier extends AsyncNotifier<G5TextSize> {
  @override
  Future<G5TextSize> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_textSizeKey);
      return G5TextSize.values.where((s) => s.name == name).firstOrNull ??
          G5TextSize.normal;
    } on Object {
      return G5TextSize.normal;
    }
  }

  Future<void> set(G5TextSize size) async {
    state = AsyncData(size);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_textSizeKey, size.name);
    } on Object catch (e) {
      debugPrint('[men] matn o\'lchami saqlanmadi: ${e.runtimeType}');
    }
  }
}

/// v5 interfeysiga tanlangan matn o'lchamini qo'llaydi (tizim o'lchami ustiga).
class G5TextScale extends ConsumerWidget {
  const G5TextScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factor =
        ref.watch(g5TextSizeProvider).valueOrNull?.factor ??
        G5TextSize.normal.factor;
    if (factor == 1) return child;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(media.textScaler.scale(1) * factor),
      ),
      child: child,
    );
  }
}
