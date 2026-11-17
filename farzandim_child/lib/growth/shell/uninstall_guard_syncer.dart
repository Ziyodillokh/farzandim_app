// «O'chirishni taqiqlash» siyosati sinxroni (sof mantiq, platformasiz):
// sessiyada ko'pi bilan bitta faollashtirish tizim dialogi, bir vaqtda bitta
// so'rov. Qobiqqa ulanishi — `uninstall_guard_sync.dart`.

/// Ota-onaning `blockUninstall` qiymati (`null` — o'qib bo'lmadi).
typedef UninstallPolicyReader = Future<bool?> Function(String childId);

/// Siyosatni qo'llaydi (`UninstallProtectionService.apply`); admin holati.
typedef UninstallPolicyApplier =
    Future<bool> Function(bool? shouldProtect, {required bool allowPrompt});

class UninstallGuardSyncer {
  UninstallGuardSyncer({
    required UninstallPolicyReader readPolicy,
    required Future<bool> Function() isActive,
    required UninstallPolicyApplier apply,
  }) : _readPolicy = readPolicy,
       _isActive = isActive,
       _apply = apply;

  final UninstallPolicyReader _readPolicy;
  final Future<bool> Function() _isActive;
  final UninstallPolicyApplier _apply;

  bool _promptedThisSession = false;
  Future<void>? _running;

  /// Siyosatni o'qib qo'llaydi. Ochilish va qaytish ketma-ket kelsa — bitta
  /// so'rov (ikkinchisi birinchisini kutadi).
  Future<void> sync(String childId) =>
      _running ??= _run(childId).whenComplete(() => _running = null);

  Future<void> _run(String childId) async {
    // Tarmoq xatosi (`null`) — apply hech narsani o'zgartirmaydi.
    final shouldProtect = await _readPolicy(childId);
    var prompt = false;
    // Dialog faqat haqiqatan kerak bo'lsa (admin o'chiq) va sessiyada birinchi
    // marta — admin allaqachon yoqilgan bo'lsa «imkoniyat» sarflanmaydi.
    if (shouldProtect == true && !_promptedThisSession && !await _isActive()) {
      prompt = true;
      _promptedThisSession = true;
    }
    await _apply(shouldProtect, allowPrompt: prompt);
  }
}
