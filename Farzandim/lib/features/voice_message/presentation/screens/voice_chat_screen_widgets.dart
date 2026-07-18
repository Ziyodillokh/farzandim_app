// Voice chat ekranining yordamchi widget'lari (header, empty, skeleton).
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
    // Bola chati bilan bir xil tuzilish: [orqa chip] [ism markazda Unbounded]
    // [avatar o'ngда]. 3-nuqta menyu olib tashlandi — avatar bosilsa
    // sozlamalar ochiladi (bolada ham shunday). Avatar OTA-ONAning haqiqiy
    // rasmi bo'lib qoladi (bola generic ikona ishlatadi — bu ustunlik).
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          // Orqa tugma — 44×44 yumaloq-kvadrat chip.
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1B2128),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  childName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.unbounded(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'voiceChat.headerSubtitle'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0x8CFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Avatar o'ngда — bosilsa chat sozlamalari (bola bilan bir xil).
          GestureDetector(onTap: onInfo, child: avatar),
        ],
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar();

  @override
  Widget build(BuildContext context) {
    // Bola chatidagi avatar bilan bir xil: 44px, nozik chegara, ko'k tint 18%,
    // ikon ham ko'k (#216BFF).
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF216BFF).withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: const Icon(
        SolarIconsBold.user,
        color: Color(0xFF216BFF),
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
      color: const Color(0xFF216BFF),
      backgroundColor: const Color(0xFF12171E),
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (_, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF216BFF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      SolarIconsBold.microphone,
                      size: 50,
                      color: Color(0xFF508AFF),
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
                      color: const Color(0x8CFFFFFF),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: isOwn
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (isOwn) const Spacer(),
              Flexible(
                flex: 4,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF12171E).withValues(alpha: 0.5),
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
