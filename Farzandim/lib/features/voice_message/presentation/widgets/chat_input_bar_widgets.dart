// ARCH-13 davomi: monolit fayl `part` fayllarga bo'lindi — private
// nomlar va xulq o'zgarmagan, faqat fayl tashkiloti.
part of 'chat_input_bar.dart';

// ─── Telegram-style yashil send tugma ───────────────────────────────
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap, required this.disabled});

  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pBlue,
          boxShadow: [
            BoxShadow(
              color: _pBlue.withValues(alpha: 0.28),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.only(left: 2),
          child: Icon(
            SolarIconsBold.plain,
            color: AppColors.onPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Recording indicator (qizil dot + timer + jonli waveform) ────────
class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator({
    required this.elapsedSeconds,
    required this.amplitudes,
    this.amplitudeTick,
  });

  final int elapsedSeconds;
  final List<double> amplitudes;
  final Listenable? amplitudeTick;

  @override
  Widget build(BuildContext context) {
    final m = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _pChipBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$m:$s',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 26,
              // PERF-05: waveform amplitudeTick orqali O'ZI qayta chiziladi
              // (10Hz) — ota-ekran setState'siz. Tick berilmasa eski xulq
              // (parent rebuild'ida chiziladi).
              child: AnimatedBuilder(
                animation:
                    amplitudeTick ?? const AlwaysStoppedAnimation<int>(0),
                builder: (_, __) => amplitudes.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: amplitudes.length,
                        itemBuilder: (_, i) {
                          final amp = amplitudes[amplitudes.length - 1 - i];
                          final h = (amp * 26).clamp(2.0, 26.0);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Center(
                              child: Container(
                                width: 2.5,
                                height: h,
                                decoration: BoxDecoration(
                                  color: _pBlue,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Emoji panel — kategoriya tablar + grid (zero-dependency)
// ─────────────────────────────────────────────────────────────────────

class _EmojiPanel extends StatefulWidget {
  const _EmojiPanel({required this.onEmoji});

  final ValueChanged<String> onEmoji;

  @override
  State<_EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<_EmojiPanel> {
  int _category = 0;

  static const List<({IconData icon, List<String> emojis})> _categories = [
    (
      icon: SolarIconsBold.smileCircle,
      emojis: [
        '😀',
        '😃',
        '😄',
        '😁',
        '😆',
        '😅',
        '😂',
        '🤣',
        '🙂',
        '🙃',
        '😉',
        '😊',
        '😇',
        '🥰',
        '😍',
        '🤩',
        '😘',
        '😗',
        '😚',
        '😙',
        '😋',
        '😛',
        '😜',
        '🤪',
        '😝',
        '🤑',
        '🤗',
        '🤭',
        '🤫',
        '🤔',
        '🤐',
        '😐',
        '😑',
        '😶',
        '😏',
        '😒',
        '🙄',
        '😬',
        '😌',
        '😔',
        '😪',
        '🤤',
        '😴',
        '😷',
        '🤒',
        '🤕',
        '🥵',
        '🥶',
        '😵',
        '🤯',
        '🥳',
        '😎',
        '🤓',
        '🧐',
        '😕',
        '😟',
        '🙁',
        '😮',
        '😲',
        '😳',
        '🥺',
        '😦',
        '😨',
        '😰',
        '😢',
        '😭',
        '😱',
        '😖',
        '😣',
        '😞',
        '😤',
        '😡',
        '😠',
        '🤬',
        '😈',
        '👿',
        '💀',
        '😺',
        '😸',
        '😹',
      ],
    ),
    (
      icon: SolarIconsBold.handStars,
      emojis: [
        '👍',
        '👎',
        '👌',
        '🤌',
        '🤏',
        '✌️',
        '🤞',
        '🤟',
        '🤘',
        '🤙',
        '👈',
        '👉',
        '👆',
        '👇',
        '☝️',
        '✋',
        '🤚',
        '🖐️',
        '🖖',
        '👋',
        '🤝',
        '🙏',
        '✍️',
        '💅',
        '🤳',
        '💪',
        '👏',
        '🙌',
        '👐',
        '🤲',
        '🫶',
        '👊',
        '✊',
        '🤛',
        '🤜',
        '🫰',
        '🫵',
        '🦾',
        '🖕',
        '✔️',
      ],
    ),
    (
      icon: SolarIconsBold.heart,
      emojis: [
        '❤️',
        '🧡',
        '💛',
        '💚',
        '💙',
        '💜',
        '🖤',
        '🤍',
        '🤎',
        '💔',
        '❣️',
        '💕',
        '💞',
        '💓',
        '💗',
        '💖',
        '💘',
        '💝',
        '💟',
        '♥️',
        '💋',
        '💯',
        '💢',
        '💥',
        '💫',
        '💦',
        '💨',
        '🕳️',
        '💬',
        '🗯️',
        '⭐',
        '🌟',
        '✨',
        '⚡',
        '🔥',
        '🌈',
        '☀️',
        '🌙',
        '🎉',
        '🎊',
      ],
    ),
    (
      icon: SolarIconsBold.paw,
      emojis: [
        '🐶',
        '🐱',
        '🐭',
        '🐹',
        '🐰',
        '🦊',
        '🐻',
        '🐼',
        '🐨',
        '🐯',
        '🦁',
        '🐮',
        '🐷',
        '🐸',
        '🐵',
        '🐔',
        '🐧',
        '🐦',
        '🐤',
        '🦆',
        '🦅',
        '🦉',
        '🐺',
        '🐗',
        '🐴',
        '🦄',
        '🐝',
        '🐛',
        '🦋',
        '🐌',
        '🐢',
        '🐍',
        '🐙',
        '🐠',
        '🐟',
        '🐬',
        '🐳',
        '🐋',
        '🦈',
        '🌸',
        '🌹',
        '🌻',
        '🌼',
        '🌷',
        '🌲',
        '🌳',
        '🌴',
        '🌵',
        '🍀',
        '🍁',
      ],
    ),
    (
      icon: SolarIconsBold.chefHat,
      emojis: [
        '🍏',
        '🍎',
        '🍐',
        '🍊',
        '🍋',
        '🍌',
        '🍉',
        '🍇',
        '🍓',
        '🫐',
        '🍈',
        '🍒',
        '🍑',
        '🥭',
        '🍍',
        '🥥',
        '🥝',
        '🍅',
        '🍆',
        '🥑',
        '🥦',
        '🥕',
        '🌽',
        '🌶️',
        '🥔',
        '🍠',
        '🥐',
        '🍞',
        '🥖',
        '🧀',
        '🥚',
        '🍳',
        '🥞',
        '🧇',
        '🥓',
        '🍔',
        '🍟',
        '🍕',
        '🌭',
        '🥪',
        '🌮',
        '🌯',
        '🍜',
        '🍲',
        '🍛',
        '🍣',
        '🍱',
        '🍦',
        '🍩',
        '🍪',
        '🎂',
        '🍰',
        '🧁',
        '🍫',
        '🍬',
        '🍭',
        '☕',
        '🍵',
        '🥤',
        '🧃',
      ],
    ),
    (
      icon: SolarIconsBold.football,
      emojis: [
        '⚽',
        '🏀',
        '🏈',
        '⚾',
        '🥎',
        '🎾',
        '🏐',
        '🏉',
        '🎱',
        '🏓',
        '🏸',
        '🥅',
        '🏒',
        '🏑',
        '🥍',
        '🏏',
        '⛳',
        '🏹',
        '🎣',
        '🥊',
        '🥋',
        '🎽',
        '⛸️',
        '🥌',
        '🛷',
        '🎿',
        '⛷️',
        '🏂',
        '🏋️',
        '🤸',
        '🤼',
        '🤽',
        '🤾',
        '🚴',
        '🚵',
        '🏆',
        '🥇',
        '🥈',
        '🥉',
        '🎮',
        '🎯',
        '🎲',
        '🎸',
        '🎹',
        '🎺',
        '🎻',
        '🥁',
        '🎤',
        '🎧',
        '🎬',
      ],
    ),
    (
      icon: SolarIconsBold.lightbulb,
      emojis: [
        '⌚',
        '📱',
        '💻',
        '⌨️',
        '🖥️',
        '🖨️',
        '🖱️',
        '💽',
        '💾',
        '📷',
        '📸',
        '📹',
        '🎥',
        '📞',
        '☎️',
        '📟',
        '📠',
        '📺',
        '📻',
        '🔋',
        '🔌',
        '💡',
        '🔦',
        '🕯️',
        '🧯',
        '🛢️',
        '💸',
        '💵',
        '💴',
        '💶',
        '💷',
        '💰',
        '💳',
        '💎',
        '⚖️',
        '🔧',
        '🔨',
        '⚙️',
        '🔑',
        '🔒',
        '📚',
        '📖',
        '📝',
        '✏️',
        '🖊️',
        '📌',
        '📎',
        '✂️',
        '📅',
        '⏰',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final emojis = _categories[_category].emojis;
    return Container(
      height: 256,
      color: _pSheetBg,
      child: Column(
        children: [
          // Kategoriya tablari.
          SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_categories.length, (i) {
                final selected = i == _category;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _category = i),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selected
                                ? _pBlue
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Icon(
                        _categories[i].icon,
                        size: 22,
                        color: selected
                            ? _pBlue
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: emojis.length,
              itemBuilder: (_, i) {
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => widget.onEmoji(emojis[i]),
                  child: Center(
                    child: Text(
                      emojis[i],
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
