// ─────────────────────────────────────────────────────────────────────
// PhotoRequestBanner — ota-ona foto so'raganda paydo bo'ladi
// ─────────────────────────────────────────────────────────────────────
//
// `pendingPhotoRequestsProvider` orqali pending so'rov bor-yo'qligini
// kuzatadi. Bor bo'lsa: orange tint banner + 2 ta tugma:
//   - "Foto olish"  → kamera ochiladi, Storage'ga yuklanadi
//   - "Rad etish"   → status `declined` ga o'tadi
// Yo'q bo'lsa: SizedBox.shrink (joy band qilmaydi).

import 'package:farzandim_child/core/theme/app_icons.dart';
import 'package:farzandim_child/core/theme/app_colors.dart';
import 'package:farzandim_child/features/photo/data/models/photo_request.dart';
import 'package:farzandim_child/features/photo/presentation/providers/photo_request_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PhotoRequestBanner extends ConsumerWidget {
  const PhotoRequestBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingPhotoRequestsProvider);
    final capture = ref.watch(photoCaptureProvider);

    return pending.when(
      data: (requests) {
        if (requests.isEmpty) return const SizedBox.shrink();
        return _Banner(
          request: requests.first,
          captureState: capture,
          onCapture: () =>
              ref.read(photoCaptureProvider.notifier).capture(requests.first),
          onDecline: () => ref
              .read(photoCaptureProvider.notifier)
              .decline(requests.first.id),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.request,
    required this.captureState,
    required this.onCapture,
    required this.onDecline,
  });

  final PhotoRequest request;
  final CaptureState captureState;
  final VoidCallback onCapture;
  final VoidCallback onDecline;

  static const Color _orange = Color(0xFFFF6B35);

  bool get _busy =>
      captureState.status == CaptureStatus.capturing ||
      captureState.status == CaptureStatus.uploading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: _orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          // ignore: deprecated_member_use
          color: _orange.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: _orange.withOpacity(0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.camera,
                  color: _orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Otangiz foto so\'rayapti',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hozir bir foto oling — sizning xavfsizligingiz uchun',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : onCapture,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(AppIcons.camera, size: 18),
                  label: Text(_busy ? 'Yuborilmoqda...' : 'Foto olish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _busy ? null : onDecline,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                child: const Text('Rad etish'),
              ),
            ],
          ),
          if (captureState.status == CaptureStatus.error)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Xato: ${captureState.errorMessage ?? 'noma\'lum'}",
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
