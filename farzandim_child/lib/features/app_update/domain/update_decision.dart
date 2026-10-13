// ─────────────────────────────────────────────────────────────────────
// UpdateDecision — yangilanish holatini hisoblash (sof mantiq, test qilinadi)
// ─────────────────────────────────────────────────────────────────────
//
// Android (o'zgarmagan): minSupported'dan past yoki umumiy `isForceUpdate`
// → majburiy; latest'dan past → yumshoq banner; havola — `storeUrl`.
//
// iOS (App Store 2.1/2.3): umumiy (Android uchun yoqilgan) bayroq iOS'ni
// HECH QACHON bloklamaydi va Android reliz matni ko'rinmaydi. iOS'da faqat:
//   • haqiqiy App Store havolasi (https://apps.apple.com/...) bo'lsa;
//   • majburiy — versiya ios.minSupported'dan past YOKI ios.isForceUpdate
//     yoqilgan va versiya ios.latest'dan past (eng yangi versiya hech qachon
//     bloklanmaydi);
//   • banner — versiya ios.latest'dan past.

import 'package:farzandim_child/features/app_update/data/models/app_version_info.dart';

const _appStoreHosts = {'apps.apple.com', 'itunes.apple.com'};

/// Faqat https App Store havolasi qaytadi, aks holda `null`.
String? validAppStoreUrl(String? url) {
  if (url == null) return null;
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https') return null;
  return _appStoreHosts.contains(uri.host) ? uri.toString() : null;
}

/// Hisoblangan qaror (dismiss tekshiruvi chaqiruvchida).
class UpdateDecision {
  const UpdateDecision({
    required this.state,
    this.targetUrl,
    this.releaseNotes = '',
  });

  final UpdateState state;
  final String? targetUrl;
  final String releaseNotes;
}

UpdateDecision decideUpdate({
  required String currentVersion,
  required AppVersionInfo info,
  required bool isIOS,
}) {
  return isIOS
      ? _decideIos(currentVersion, info.ios)
      : _decideAndroid(currentVersion, info);
}

UpdateDecision _decideAndroid(String current, AppVersionInfo info) {
  final platform = info.android;
  final ltMin = compareSemver(current, platform.minSupported) < 0;
  if (info.isForceUpdate || ltMin) {
    return UpdateDecision(
      state: UpdateState.forceUpdateRequired,
      targetUrl: platform.storeUrl,
      releaseNotes: info.releaseNotes,
    );
  }
  if (compareSemver(current, platform.latest) < 0) {
    return UpdateDecision(
      state: UpdateState.softUpdateAvailable,
      targetUrl: platform.storeUrl,
      releaseNotes: info.releaseNotes,
    );
  }
  return const UpdateDecision(state: UpdateState.upToDate);
}

UpdateDecision _decideIos(String current, PlatformVersionInfo platform) {
  final storeUrl = validAppStoreUrl(platform.appStoreUrl);
  // Havolasiz yangilash tugmasi "berk ko'cha" — hech narsa ko'rsatmaymiz.
  if (storeUrl == null) {
    return const UpdateDecision(state: UpdateState.upToDate);
  }
  final notes = platform.releaseNotes ?? '';
  final ltLatest = compareSemver(current, platform.latest) < 0;
  final ltMin = compareSemver(current, platform.minSupported) < 0;
  if (ltMin || (platform.isForceUpdate == true && ltLatest)) {
    return UpdateDecision(
      state: UpdateState.forceUpdateRequired,
      targetUrl: storeUrl,
      releaseNotes: notes,
    );
  }
  if (ltLatest) {
    return UpdateDecision(
      state: UpdateState.softUpdateAvailable,
      targetUrl: storeUrl,
      releaseNotes: notes,
    );
  }
  return const UpdateDecision(state: UpdateState.upToDate);
}
