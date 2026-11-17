// Moslash varag'ining kichik qismlari: tortish belgisi, tanlov qatori,
// radio belgisi, farzand/"hech biri" belgilari, izoh qutisi va "Keyinroq".
// Tokenlar va matn uslublari asosiy faylda (`part of`).

part of 'student_child_match_sheet.dart';

/// Tortish belgisi.
class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

/// Tanlov qatori: avatar + nom (+ izoh) + radio belgisi.
class _Option extends StatelessWidget {
  const _Option({
    required this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.hint,
  });

  final Widget leading;
  final String title;
  final bool selected;
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _blue.withValues(alpha: 0.14) : _optionBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _blue : _optionBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _pop(15, w: FontWeight.w500),
                    ),
                    if (hint != null)
                      Text(
                        hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _pop(12.5, c: _dim),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RadioMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _blue : Colors.transparent,
        border: Border.all(
          color: selected ? _blue : Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

/// Farzand avatari (ilovada bo'lsa) yoki ismining bosh harfi.
class _ChildBadge extends ConsumerWidget {
  const _ChildBadge({required this.childId, required this.name});

  final String childId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(childByIdProvider(childId));
    if (child != null) {
      return ChildAvatar(child: child, size: 40, showBorder: false);
    }
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _chipBg, shape: BoxShape.circle),
      child: Text(initial, style: _pop(16, w: FontWeight.w600)),
    );
  }
}

/// "Hech biri" belgisi.
class _NoneBadge extends StatelessWidget {
  const _NoneBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _chipBg, shape: BoxShape.circle),
      child: const Icon(SolarIconsOutline.closeCircle, size: 20, color: _dim),
    );
  }
}

/// Izoh qutisi (faqat o'qish holati / farzand yo'q).
class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _optionBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _optionBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: _pop(14))),
        ],
      ),
    );
  }
}

/// "Keyinroq" — saqlamasdan keyingi o'quvchiga (yoki yopish).
class _LaterButton extends StatelessWidget {
  const _LaterButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              'school.match.later'.tr(),
              style: _pop(
                15,
                w: FontWeight.w600,
                c: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
