// ARCH-13 davomi: monolit fayl `part` fayllarga bo'lindi — private
// nomlar va xulq o'zgarmagan, faqat fayl tashkiloti.
part of 'voice_chat_screen.dart';

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.childName,
    required this.avatar,
    required this.onBack,
    required this.onInfo,
  });

  final String childName;
  final Widget avatar;
  final VoidCallback onBack;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
            ),
            onPressed: onBack,
          ),
          avatar,
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  childName,
                  style: AppTextStyles.bodyM.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'voiceChat.headerSubtitle'.tr(),
                  style: AppTextStyles.bodyS.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: AppColors.textPrimary,
            ),
            onPressed: onInfo,
            tooltip: 'chatSettings.title'.tr(),
          ),
        ],
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        color: AppColors.accent,
        size: 22,
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.childName, required this.onRefresh});

  final String childName;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    // RefreshIndicator ListView yoki scrollable child kutadi —
    // empty holatda ham swipe ishlashi uchun SingleChildScrollView'ga
    // o'rab qo'yamiz (always-scrollable physics bilan).
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_outlined,
                      size: 50,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  Text(
                    'voiceChat.emptyTitle'.tr(),
                    style: AppTextStyles.headlineL.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'voiceChat.emptySubtitle'.tr(
                      namedArgs: {'name': childName},
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
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

class _ChatLoadingSkeleton extends StatelessWidget {
  const _ChatLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    // Aralash o'ng/chap bubble shaklidagi 3 ta placeholder. Stream
    // tez yuklanadi, shuning uchun bu kamdan-kam ko'rinadi (sekin
    // internetda foydali).
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: 3,
      itemBuilder: (_, i) {
        final isOwn = i.isEven;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          child: Row(
            mainAxisAlignment:
                isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (isOwn) const Spacer(),
              Flexible(
                flex: 4,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              if (!isOwn) const Spacer(),
            ],
          ),
        );
      },
    );
  }
}
