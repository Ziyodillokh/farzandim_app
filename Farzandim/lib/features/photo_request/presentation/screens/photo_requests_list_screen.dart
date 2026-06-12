// ─────────────────────────────────────────────────────────────────────
// PhotoRequestsListScreen — Parent rasm so'rovlar (4.4.16 + 4.4.20 enh.)
// ─────────────────────────────────────────────────────────────────────
//
// State machine: PENDING → COMPLETED | DECLINED.
// Tabs: Hammasi / Kutilmoqda / Bajarilgan / Rad etilgan.
// Fullscreen: tap qilingan rasm InteractiveViewer bilan zoomable.
// Delete: long-press → confirmation dialog → DELETE /photo-requests/:id.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim/core/network/friendly_error.dart';
import 'package:farzandim/core/theme/app_colors.dart';
import 'package:farzandim/core/theme/app_dimensions.dart';
import 'package:farzandim/core/theme/app_text_styles.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/photo_request/data/repositories/backend_photo_request_repository.dart';
import 'package:farzandim/features/photo_request/presentation/providers/photo_request_provider.dart';
import 'package:farzandim/features/photo_request/presentation/widgets/photo_request_dialog.dart';
import 'package:farzandim/shared/widgets/gradient_background.dart';
import 'package:farzandim/shared/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PhotoRequestsListScreen extends ConsumerWidget {
  const PhotoRequestsListScreen({required this.childId, super.key});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(childByIdProvider(childId));
    final childName = child?.name ?? 'photoRequests.fallbackChildName'.tr();
    final requestsAsync = ref.watch(photoRequestsProvider(childId));

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _Header(childName: childName),
                const _FilterTabs(),
                Expanded(
                  child: requestsAsync.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                    error: (e, _) => Center(child: Text(friendlyError(e))),
                    data: (requests) => TabBarView(
                      children: [
                        _RequestsView(childId: childId, requests: requests),
                        _RequestsView(
                          childId: childId,
                          requests: requests
                              .where((r) => r['status'] == 'PENDING')
                              .toList(),
                          emptyHint: 'photoRequests.emptyPending'.tr(),
                        ),
                        _RequestsView(
                          childId: childId,
                          requests: requests
                              .where((r) => r['status'] == 'COMPLETED')
                              .toList(),
                          emptyHint: 'photoRequests.emptyCompleted'.tr(),
                        ),
                        _RequestsView(
                          childId: childId,
                          requests: requests
                              .where((r) => r['status'] == 'DECLINED')
                              .toList(),
                          emptyHint: 'photoRequests.emptyDeclined'.tr(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => PhotoRequestDialog.show(context, childId: childId),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          icon: const Icon(Icons.photo_camera_rounded),
          label: Text(
            'photoRequests.requestButton'.tr(),
            style: AppTextStyles.bodyM.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.childName});
  final String childName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                'photoRequests.headerTitle'.tr(namedArgs: {'name': childName}),
                style: AppTextStyles.headlineL.copyWith(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.onPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTextStyles.bodyM.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTextStyles.bodyM,
        tabs: [
          Tab(text: 'photoRequests.tabAll'.tr()),
          Tab(text: 'photoRequests.tabPending'.tr()),
          Tab(text: 'photoRequests.tabCompleted'.tr()),
          Tab(text: 'photoRequests.tabDeclined'.tr()),
        ],
      ),
    );
  }
}

class _RequestsView extends ConsumerWidget {
  const _RequestsView({
    required this.childId,
    required this.requests,
    this.emptyHint,
  });

  final String childId;
  final List<Map<String, dynamic>> requests;
  final String? emptyHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (requests.isEmpty) {
      return _EmptyState(hint: emptyHint);
    }
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        ref.invalidate(photoRequestsProvider(childId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg,
          AppDimensions.md,
          AppDimensions.lg,
          AppDimensions.xl * 2,
        ),
        itemCount: requests.length,
        itemBuilder: (_, i) =>
            _RequestTile(request: requests[i], childId: childId),
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.request, required this.childId});
  final Map<String, dynamic> request;
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = request['id'] as String? ?? '';
    final status = (request['status'] as String?) ?? 'PENDING';
    final message = (request['message'] as String?) ?? '';
    final requestedAt = request['requestedAt'] as String?;
    final time = requestedAt != null
        ? DateTime.tryParse(requestedAt)?.toLocal()
        : null;

    final (icon, color, label) = switch (status) {
      'COMPLETED' => (
        Icons.check_circle_rounded,
        AppColors.success,
        'photoRequests.statusCompleted'.tr(),
      ),
      'DECLINED' => (
        Icons.cancel_rounded,
        AppColors.error,
        'photoRequests.statusDeclined'.tr(),
      ),
      _ => (
        Icons.schedule_rounded,
        AppColors.warning,
        'photoRequests.statusPending'.tr(),
      ),
    };

    return GestureDetector(
      onLongPress: id.isEmpty ? null : () => _confirmDelete(context, ref, id),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.md),
        child: SettingsCard(
          accent: AppColors.featurePurple,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SettingsIconChip(icon: icon, accent: color),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.bodyM.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (time != null)
                    Text(
                      _formatTime(time),
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                Text(
                  '"$message"',
                  style: AppTextStyles.bodyS.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (status == 'COMPLETED') ...[
                const SizedBox(height: AppDimensions.md),
                _CompletedPhoto(requestId: id),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String requestId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'photoRequests.deleteDialogTitle'.tr(),
          style: AppTextStyles.headlineL.copyWith(fontSize: 18),
        ),
        content: Text(
          'photoRequests.deleteDialogContent'.tr(),
          style: AppTextStyles.bodyM.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'common.cancel'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'common.delete'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref
        .read(photoRequestActionsProvider.notifier)
        .deleteRequest(childId: childId, requestId: requestId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'photoRequests.deletedSnack'.tr()
              : 'photoRequests.deleteErrorSnack'.tr(),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'formatters.now'.tr();
    if (diff.inMinutes < 60) {
      return 'photoRequests.minutesShort'.tr(
        namedArgs: {'minutes': '${diff.inMinutes}'},
      );
    }
    if (diff.inHours < 24) {
      return 'photoRequests.hoursShort'.tr(
        namedArgs: {'hours': '${diff.inHours}'},
      );
    }
    return '${dt.day}.${dt.month}';
  }
}

/// Bola yuborgan rasm — signed URL lazy fetch + tap → fullscreen.
class _CompletedPhoto extends ConsumerStatefulWidget {
  const _CompletedPhoto({required this.requestId});
  final String requestId;

  @override
  ConsumerState<_CompletedPhoto> createState() => _CompletedPhotoState();
}

class _CompletedPhotoState extends ConsumerState<_CompletedPhoto> {
  String? _signedUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final url = await ref
        .read(backendPhotoRequestRepositoryProvider)
        .getFileUrl(widget.requestId);
    if (!mounted) return;
    setState(() {
      _signedUrl = url;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }
    if (_signedUrl == null) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'photoRequests.photoLoadFailed'.tr(),
          style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _openFullscreen(context, _signedUrl!),
      child: Hero(
        tag: 'photo_${widget.requestId}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          // MEM-4: disk kesh + cheklangan dekod (memCacheWidth)
          child: CachedNetworkImage(
            imageUrl: _signedUrl!,
            fit: BoxFit.cover,
            height: 240,
            width: double.infinity,
            memCacheWidth: 720,
            errorWidget: (_, __, ___) => Container(
              height: 100,
              alignment: Alignment.center,
              color: AppColors.surfaceVariant,
              child: Icon(
                Icons.broken_image_rounded,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context, String url) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) =>
            _FullscreenPhoto(url: url, tag: 'photo_${widget.requestId}'),
      ),
    );
  }
}

class _FullscreenPhoto extends StatelessWidget {
  const _FullscreenPhoto({required this.url, required this.tag});
  final String url;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: Hero(
                tag: tag,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  // MEM-4: disk kesh + cheklangan dekod (memCacheWidth)
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    memCacheWidth: 1080,
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.hint});
  final String? hint;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              color: AppColors.textSecondary,
              size: 64,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              hint ?? 'photoRequests.emptyDefault'.tr(),
              style: AppTextStyles.bodyM.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              'photoRequests.emptySubtitle'.tr(),
              style: AppTextStyles.bodyS.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
