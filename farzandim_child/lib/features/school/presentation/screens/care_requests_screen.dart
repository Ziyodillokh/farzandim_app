// ─────────────────────────────────────────────────────────────────────
// CareRequestsScreen — "Murojaatlarim" (`/school/requests`)
// ─────────────────────────────────────────────────────────────────────
//
// Bolaning psixologga murojaatlari (yangisi birinchi, oxirgi 20 ta): mavzu,
// holat va belgilangan suhbat vaqti (Toshkent vaqtida). Holat o'zgarishi
// push bilan kelmaydi — sahifa ochilganda va pastga tortilganda yangilanadi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/design_scale.dart';
import 'package:farzandim_child/features/dashboard/presentation/widgets/home/home_style.dart';
import 'package:farzandim_child/features/learning/presentation/widgets/setup/setup_widgets.dart';
import 'package:farzandim_child/features/school/data/school_repository.dart';
import 'package:farzandim_child/features/school/domain/care_models.dart';
import 'package:farzandim_child/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim_child/features/school/presentation/school_navigation.dart';
import 'package:farzandim_child/features/school/presentation/widgets/care/care_request_tile.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_message_view.dart';
import 'package:farzandim_child/features/school/presentation/widgets/school_section.dart';
import 'package:farzandim_child/features/tests/presentation/widgets/inner_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class CareRequestsScreen extends ConsumerWidget {
  const CareRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(careRequestsProvider);
    // Yangilanayotganda / oflaynda oxirgi ma'lum ro'yxat ko'rinadi.
    final requests = state.valueOrNull;
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: DesignScale(
        child: Builder(
          builder: (context) {
            final insets = MediaQuery.paddingOf(context);
            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: HomeColors.primary,
                    backgroundColor: HomeColors.card,
                    edgeOffset: insets.top,
                    onRefresh: () async {
                      ref.invalidate(careRequestsProvider);
                      try {
                        await ref.read(careRequestsProvider.future);
                      } on SchoolException {
                        // Xato sahifada ko'rinadi.
                      }
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        growthTopInset(context),
                        16,
                        24,
                      ),
                      children: [
                        InnerPageHeader(
                          title: 'school.requests.title'.tr(),
                          fallbackRoute: SchoolRoutes.hub,
                        ),
                        const SizedBox(height: 16),
                        if (requests != null && requests.isNotEmpty)
                          ..._list(requests)
                        else
                          _status(ref, state),
                      ],
                    ),
                  ),
                ),
                SchoolBottomBar(
                  children: [
                    SetupButton(
                      label: 'school.requests.newRequest'.tr(),
                      onTap: () => openNewCareRequest(context),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _list(List<CareRequest> requests) => [
    SchoolNote(
      icon: SolarIconsOutline.lockKeyhole,
      text: 'school.requests.privacy'.tr(),
    ),
    for (final request in requests) ...[
      const SizedBox(height: 10),
      CareRequestTile(request: request),
    ],
  ];

  /// Ro'yxat bo'sh: yuklanmoqda, xato yoki murojaat yo'q. Bo'sh ro'yxat
  /// xato bilan kelsa (masalan, bog'lanish aniqlanguncha bo'sh qiymat) —
  /// xato ko'rsatiladi.
  Widget _status(WidgetRef ref, AsyncValue<List<CareRequest>> state) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 96),
        child: Center(
          child: CircularProgressIndicator(color: HomeColors.primary),
        ),
      );
    }
    final error = state.error;
    if (error != null) {
      final code = error is SchoolException
          ? error.code
          : SchoolErrorCode.unknown;
      return SchoolMessageView(
        icon: code == SchoolErrorCode.network
            ? Icons.wifi_off_rounded
            : SolarIconsOutline.dangerCircle,
        message: code.messageKey.tr(),
        actionLabel: 'common.retry'.tr(),
        onAction: () => ref.invalidate(careRequestsProvider),
      );
    }
    return SchoolMessageView(
      icon: SolarIconsOutline.chatRoundDots,
      iconColor: HomeColors.blue,
      title: 'school.requests.emptyTitle'.tr(),
      message: 'school.requests.emptyBody'.tr(),
    );
  }
}
