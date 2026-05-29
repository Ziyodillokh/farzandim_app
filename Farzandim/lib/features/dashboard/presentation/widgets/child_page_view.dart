import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/child_management/data/models/child_model.dart';
import 'package:farzandim/features/dashboard/presentation/providers/selected_child_index_provider.dart';
import 'package:farzandim/shared/widgets/child_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bolalar ro'yxati uchun swipe qilinadigan PageView.
///
/// Har sahifa: chap tomonda bola ismi + qurilma modeli + (1 dan ortiq
/// bola bo'lsa) swipe indicator; o'ngda 64dp avatar.
///
/// Swipe qilganda `selectedChildIndexProvider` yangilanadi —
/// Dashboard'ning boshqa kartalari (rating, screen time) shu indekska
/// bog'liq.
class ChildPageView extends ConsumerStatefulWidget {
  /// `ChildPageView` konstruktor.
  const ChildPageView({required this.children, super.key});

  /// Ko'rsatiladigan bolalar ro'yxati. Bo'sh bo'lmasligi shart
  /// (Dashboard empty state'ni alohida boshqaradi).
  final List<Child> children;

  @override
  ConsumerState<ChildPageView> createState() => _ChildPageViewState();
}

class _ChildPageViewState extends ConsumerState<ChildPageView> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    final initialPage = ref
        .read(selectedChildIndexProvider)
        .clamp(0, widget.children.length - 1);
    _controller = PageController(initialPage: initialPage);
  }

  @override
  void didUpdateWidget(covariant ChildPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Bola o'chirilsa, indeks ro'yxatdan tashqarida qolishi mumkin —
    // PageController'ni shu yerda to'g'irlaymiz.
    final selected = ref.read(selectedChildIndexProvider);
    if (selected >= widget.children.length && widget.children.isNotEmpty) {
      _controller.jumpToPage(widget.children.length - 1);
      ref.read(selectedChildIndexProvider.notifier).state =
          widget.children.length - 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tashqi Padding — PageView'ning o'zi narrow bo'ladi, content
    // hech qachon ekran chetiga yopishmaydi (har holatda 24dp masofa).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      child: SizedBox(
        height: 116,
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.children.length,
          onPageChanged: (index) {
            ref.read(selectedChildIndexProvider.notifier).state = index;
          },
          itemBuilder: (context, index) {
            final child = widget.children[index];
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        child.name,
                        style: AppTextStyles.headlineL.copyWith(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ConnectionStatus(isConnected: child.isConnected),
                      if (widget.children.length > 1) ...[
                        const SizedBox(height: 12),
                        _SwipeIndicator(
                          total: widget.children.length,
                          currentIndex: index,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                ChildAvatar(child: child, size: 88),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Yashil/kulrang nuqta + matn — bola qurilmasi ulanganmi yo'qmi.
///
/// Child App pairing tugagach Firestore'da `isConnected: true` yoziladi —
/// Parent App stream'i shu maydonni tinglagani uchun darhol yangilanadi.
class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.isConnected});
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isConnected ? AppColors.success : AppColors.textTertiary,
            shape: BoxShape.circle,
            boxShadow: isConnected
                ? [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isConnected
              ? 'dashboard.connection.connected'.tr()
              : 'dashboard.connection.disconnected'.tr(),
          style: AppTextStyles.bodyM.copyWith(
            color: isConnected
                ? AppColors.success
                : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Swipe indicator — gorizontal chiziqlar (`PageView` faol sahifasini
/// ko'rsatadi).
class _SwipeIndicator extends StatelessWidget {
  const _SwipeIndicator({required this.total, required this.currentIndex});
  final int total;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i == currentIndex;
        return Padding(
          padding: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
          child: Container(
            width: 20,
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
