// "Kunlik vaqt limiti" — har ilovaga kunlik vaqt limiti (daqiqa/kun)
// qo'yiladigan Parvoz tortiladigan varaq. Ilovalar ro'yxati bola
// qurilmasidan (installedAppsProvider) keladi; joriy limitlar
// restrictionsProvider'dan. "Limit qo'yish"ni bossa Parvoz g'ildirak
// vaqt-tanlagich ochiladi (soat + daqiqa). Pastdagi "Saqlash" barcha
// o'zgarishlarni backend'ga yuboradi (setLimit / removeLimit).
//
// Eslatma: limit MINUTDA saqlanadi; facade.setLimit uni millisekundga
// aylantiradi. Limitni olib tashlash uchun removeLimit (DELETE)
// chaqiriladi — 0 daqiqa = blok (limit emas), shuning uchun minimum 1.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/features/app_restrictions/data/models/app_restriction.dart';
import 'package:farzandim/features/app_restrictions/data/repositories/backend_app_limit_repository.dart';
import 'package:farzandim/features/app_restrictions/presentation/providers/app_usage_providers.dart';
import 'package:farzandim/features/app_restrictions/presentation/widgets/app_icon_widget.dart';
import 'package:farzandim/shared/widgets/app_toast.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════ Parvoz tokenlar (lokal) ════════════
const _bg = Color(0xFF00060A);
const _blue = Color(0xFF216BFF);
const _card = Color(0xFF12171E);
const _fieldBorder = Color(0x1FFFFFFF); // oq 12%
const _dim = Color(0x8CFFFFFF); // oq 55%
const _danger = Color(0xFFFF5A5A);

const _minLimit = 1; // 0 daqiqa = blok bo'lib qoladi, shuning uchun min 1
const _maxLimit = 24 * 60 - 1; // 1439 (23s 59d) — g'ildirak chegarasi
const _defaultLimit = 60;

TextStyle _unb(
  double size, {
  FontWeight w = FontWeight.w600,
  Color c = Colors.white,
  double ls = -0.3,
}) => GoogleFonts.unbounded(
  fontSize: size,
  fontWeight: w,
  color: c,
  letterSpacing: ls,
  height: 1.25,
);

TextStyle _pop(
  double size, {
  FontWeight w = FontWeight.w400,
  Color c = Colors.white,
}) => GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c, height: 1.5);

/// Daqiqani "30 daqiqa / kun" ko'rinishida formatlaydi.
String _formatPerDay(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) {
    return 'dailyLimit.perDayMinutes'.tr(namedArgs: {'minutes': '$m'});
  }
  if (m == 0) {
    return 'dailyLimit.perDayHours'.tr(namedArgs: {'hours': '$h'});
  }
  return 'dailyLimit.perDayHoursMinutes'.tr(
    namedArgs: {'hours': '$h', 'minutes': '$m'},
  );
}

/// "Kunlik vaqt limiti"ni tortiladigan modal varaq sifatida ochadi.
void showDailyLimitSheet(
  BuildContext context, {
  required String childId,
  String? title,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _DailyLimitSheet(childId: childId, title: title),
  );
}

// ════════════ Drag qobig'i ════════════
/// Tepaga/pastga tortiladi; minimumdan past tortilsa yopiladi.
class _DailyLimitSheet extends StatefulWidget {
  const _DailyLimitSheet({required this.childId, this.title});

  final String childId;
  final String? title;

  @override
  State<_DailyLimitSheet> createState() => _DailyLimitSheetState();
}

class _DailyLimitSheetState extends State<_DailyLimitSheet> {
  bool _opened = false; // ochilish tugadimi (drag-yopish faqat shundan keyin)
  bool _dismissing = false; // qayta-qayta pop bo'lmasin

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _opened = true);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        if (n.extent >= 0.85) _opened = true;
        if (_opened && !_dismissing && n.extent <= 0.46) {
          _dismissing = true;
          Navigator.of(context).maybePop();
        }
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.45,
        maxChildSize: 0.96,
        snap: true,
        snapSizes: const [0.9],
        expand: false,
        builder: (ctx, scrollController) => _DailyLimitBody(
          childId: widget.childId,
          scrollController: scrollController,
          title: widget.title,
        ),
      ),
    );
  }
}

// ════════════ Varaq tanasi ════════════
class _DailyLimitBody extends ConsumerStatefulWidget {
  const _DailyLimitBody({
    required this.childId,
    required this.scrollController,
    this.title,
  });

  final String childId;
  final ScrollController scrollController;
  final String? title;

  @override
  ConsumerState<_DailyLimitBody> createState() => _DailyLimitBodyState();
}

class _DailyLimitBodyState extends ConsumerState<_DailyLimitBody> {
  // packageName → kerakli limit (daqiqa). null = limit olib tashlanadi.
  // Map'da bo'lmasa — o'zgarmagan (asl holat ishlatiladi).
  final Map<String, int?> _local = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: _bg,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title ?? 'dailyLimit.title'.tr(),
                textAlign: TextAlign.center,
                style: _unb(18, w: FontWeight.w700, ls: -0.4),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'dailyLimit.subtitle'.tr(),
                    style: _pop(13, c: _dim),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildList()),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _SaveButton(loading: _saving, onTap: _onSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Drag ishlashi uchun har holat ham scrollController + always-scrollable.
  Widget _fill(Widget child) {
    return ListView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [SizedBox(height: 320, child: Center(child: child))],
    );
  }

  Widget _buildList() {
    final apps = ref.watch(installedAppsProvider(widget.childId)).valueOrNull;
    final restr = ref.watch(restrictionsProvider(widget.childId)).valueOrNull;
    // Ikkalasini ham kutamiz — aks holda limit bir lahza yo'q ko'rinadi.
    if (apps == null || restr == null) return _fill(const _Loading());
    if (apps.isEmpty) {
      return _fill(
        _Empty(
          title: 'dailyLimit.empty'.tr(),
          hint: 'dailyLimit.emptyHint'.tr(),
        ),
      );
    }
    final orig = _origLimits(restr);
    return ListView.separated(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: apps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final e = apps[i];
        final pkg = e.packageName;
        final minutes = _local.containsKey(pkg) ? _local[pkg] : orig[pkg];
        return _AppLimitRow(
          appName: e.appName,
          packageName: pkg,
          iconUrl: e.iconUrl,
          iconBase64: e.iconBase64,
          minutes: minutes,
          onTap: () => _editApp(pkg, minutes),
        );
      },
    );
  }

  /// Asl vaqt-limitlari (blok emas, daqiqa > 0): packageName → daqiqa.
  Map<String, int> _origLimits(List<AppRestriction> restr) {
    final orig = <String, int>{};
    for (final r in restr) {
      // Faqat vaqt-limiti: blok bo'lmagan va daqiqasi musbat.
      if (!r.isBlocked && r.limitMinutes > 0) {
        orig[r.packageName] = r.limitMinutes;
      }
    }
    return orig;
  }

  Future<void> _editApp(String pkg, int? current) async {
    final choice = await _showDurationPicker(
      context,
      initialMinutes: current ?? _defaultLimit,
      canRemove: current != null,
    );
    if (choice == null || !mounted) return;
    setState(() => _local[pkg] = choice.remove ? null : choice.minutes);
  }

  Future<void> _onSave() async {
    if (_saving) return;
    // O'zgarish bo'lmasa — shunchaki yopamiz.
    if (_local.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final facade = ref.read(appRestrictionRepositoryProvider);
      final restr = ref.read(restrictionsProvider(widget.childId)).valueOrNull;
      final orig = restr == null ? <String, int>{} : _origLimits(restr);
      final installed = ref
          .read(installedAppsProvider(widget.childId))
          .valueOrNull;
      final names = <String, String>{};
      if (installed != null) {
        for (final e in installed) {
          names[e.packageName] = e.appName;
        }
      }
      for (final entry in _local.entries) {
        final pkg = entry.key;
        final desired = entry.value; // null = olib tashlash
        if (desired == orig[pkg]) continue; // o'zgarmagan
        if (desired == null) {
          await facade.removeLimit(childId: widget.childId, packageName: pkg);
        } else {
          await facade.setLimit(
            childId: widget.childId,
            packageName: pkg,
            appName: names[pkg] ?? pkg,
            limitMinutes: desired,
          );
        }
      }
      ref.invalidate(restrictionsProvider(widget.childId));
      if (!mounted) return;
      AppToast.success(context, 'dailyLimit.saved'.tr());
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final msg = e is AppLimitException
          ? e.message
          : 'dailyLimit.saveError'.tr();
      AppToast.error(context, msg);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ════════════ Ilova qatori ════════════
class _AppLimitRow extends StatelessWidget {
  const _AppLimitRow({
    required this.appName,
    required this.packageName,
    required this.iconUrl,
    required this.iconBase64,
    required this.minutes,
    required this.onTap,
  });

  final String appName;
  final String packageName;
  final String? iconUrl;
  final String? iconBase64;
  final int? minutes; // null = limit yo'q
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLimit = minutes != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasLimit ? _blue.withValues(alpha: 0.5) : _fieldBorder,
          ),
        ),
        child: Row(
          children: [
            AppIconWidget(
              packageName: packageName,
              iconUrl: iconUrl,
              iconBase64: iconBase64,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                appName.isEmpty ? packageName : appName,
                style: _pop(15, w: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            if (hasLimit)
              Text(
                _formatPerDay(minutes!),
                style: _pop(13, w: FontWeight.w500, c: const Color(0xD9FFFFFF)),
              )
            else
              _SetLimitPill(onTap: onTap),
          ],
        ),
      ),
    );
  }
}

/// "Limit qo'yish" — limit yo'q ilovalardagi ikkilamchi tugma.
class _SetLimitPill extends StatelessWidget {
  const _SetLimitPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _fieldBorder),
        ),
        child: Text(
          'dailyLimit.setLimit'.tr(),
          style: _pop(13, w: FontWeight.w500),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: _blue),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: _pop(15, w: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(hint, textAlign: TextAlign.center, style: _pop(13, c: _dim)),
        ],
      ),
    );
  }
}

/// Pastdagi asosiy "Saqlash" tugmasi.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: ParvozGlass(
        blue: true,
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: Colors.white,
                ),
              )
            : Text('dailyLimit.save'.tr(), style: _pop(16, w: FontWeight.w500)),
      ),
    );
  }
}

// ════════════ Davomiylik tanlagich (g'ildirak) ════════════
/// Limit tanlovi natijasi: yangi qiymat yoki "olib tashlash".
class _LimitChoice {
  const _LimitChoice.set(this.minutes) : remove = false;
  const _LimitChoice.remove() : minutes = 0, remove = true;

  final int minutes;
  final bool remove;
}

/// Parvoz uslubidagi soat+daqiqa g'ildirak tanlagichni ochadi.
Future<_LimitChoice?> _showDurationPicker(
  BuildContext context, {
  required int initialMinutes,
  required bool canRemove,
}) {
  return showModalBottomSheet<_LimitChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => _DurationPicker(
      initialMinutes: initialMinutes,
      canRemove: canRemove,
    ),
  );
}

class _DurationPicker extends StatefulWidget {
  const _DurationPicker({
    required this.initialMinutes,
    required this.canRemove,
  });

  final int initialMinutes;
  final bool canRemove;

  @override
  State<_DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<_DurationPicker> {
  late int _hours;
  late int _minutes;
  late final FixedExtentScrollController _hCtrl;
  late final FixedExtentScrollController _mCtrl;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMinutes.clamp(_minLimit, _maxLimit);
    _hours = m ~/ 60;
    _minutes = m % 60;
    _hCtrl = FixedExtentScrollController(initialItem: _hours);
    _mCtrl = FixedExtentScrollController(initialItem: _minutes);
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _mCtrl.dispose();
    super.dispose();
  }

  // G'ildirakdagi xom qiymat (00:00 = 0). Yorliq shuni ko'rsatadi; 0 bo'lsa
  // Saqlash o'chiriladi (0 = blok bo'lardi). Tanlangan qiymat 0..1439 oralig'i.
  int get _raw => _hours * 60 + _minutes;
  bool get _valid => _raw >= _minLimit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: _bg,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'dailyLimit.pickerTitle'.tr(),
                textAlign: TextAlign.center,
                style: _unb(18, w: FontWeight.w700, ls: -0.4),
              ),
              const SizedBox(height: 6),
              Text(
                'dailyLimit.pickerSubtitle'.tr(),
                textAlign: TextAlign.center,
                style: _pop(13, c: _dim),
              ),
              const SizedBox(height: 18),
              _buildWheels(),
              const SizedBox(height: 12),
              Text(
                _formatPerDay(_raw),
                textAlign: TextAlign.center,
                style: _pop(14, w: FontWeight.w600, c: const Color(0xE6FFFFFF)),
              ),
              const SizedBox(height: 16),
              if (widget.canRemove)
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pop(const _LimitChoice.remove()),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'dailyLimit.removeLimit'.tr(),
                      style: _pop(14, w: FontWeight.w500, c: _danger),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Opacity(
                  opacity: _valid ? 1 : 0.5,
                  child: GestureDetector(
                    onTap: _valid
                        ? () =>
                              Navigator.of(context).pop(_LimitChoice.set(_raw))
                        : null,
                    behavior: HitTestBehavior.opaque,
                    child: ParvozGlass(
                      blue: true,
                      child: Text(
                        'dailyLimit.save'.tr(),
                        style: _pop(16, w: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWheels() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'dailyLimit.unitHour'.tr(),
                  textAlign: TextAlign.center,
                  style: _pop(12, c: _dim),
                ),
              ),
              Expanded(
                child: Text(
                  'dailyLimit.unitMinute'.tr(),
                  textAlign: TextAlign.center,
                  style: _pop(12, c: _dim),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 176,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Markaziy tanlov polosasi.
              Center(
                child: Container(
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _fieldBorder),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _Wheel(
                      controller: _hCtrl,
                      count: 24,
                      onChanged: (v) => setState(() => _hours = v),
                    ),
                  ),
                  Expanded(
                    child: _Wheel(
                      controller: _mCtrl,
                      count: 60,
                      onChanged: (v) => setState(() => _minutes = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bitta raqamli g'ildirak (00..count-1).
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.count,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 44,
      perspective: 0.004,
      diameterRatio: 1.7,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, i) => Center(
          child: Text(
            i.toString().padLeft(2, '0'),
            style: _pop(24, w: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
