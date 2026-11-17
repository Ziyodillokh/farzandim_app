// HomeGate (`/home`) — kirgandan keyin: farzandlar va maktab bog'lanishlari
// yuklanguncha logotip, so'ng [homeLanding] bo'yicha Maktab / Nazorat tabi
// yoki «Qanday boshlaymiz?». Farzandlar ro'yxati xato bersa yoki javob
// kechiksa — Nazorat (u yerda xato holati va qayta urinish bor).

import 'dart:async';

import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/child_management/presentation/providers/children_provider.dart';
import 'package:farzandim/features/home/domain/home_landing.dart';
import 'package:farzandim/features/school/presentation/providers/school_providers.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Javob shuncha kechiksa — Nazorat tabi (abadiy logotip yo'q).
const _kGateTimeout = Duration(seconds: 8);

class HomeGate extends ConsumerStatefulWidget {
  const HomeGate({super.key});

  @override
  ConsumerState<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends ConsumerState<HomeGate> {
  bool? _startSeen;
  bool _left = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    unawaited(_readStartSeen());
    _timeout = Timer(_kGateTimeout, () => _leave(AppRoutes.dashboard));
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _readStartSeen() async {
    var seen = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(kHomeStartSeenKey) ?? false;
    } on Object catch (e) {
      debugPrint("[home] start belgisi o'qilmadi: ${e.runtimeType}");
    }
    if (mounted) setState(() => _startSeen = seen);
  }

  void _leave(String location) {
    if (_left || !mounted) return;
    _left = true;
    _timeout?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(location);
    });
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenProvider);
    final links = ref.watch(schoolLinksProvider);
    final startSeen = _startSeen;
    if (children.hasError) {
      _leave(AppRoutes.dashboard);
    } else if (startSeen != null && children.hasValue && !links.isLoading) {
      _leave(
        homeLanding(
          hasChildren: children.requireValue.isNotEmpty,
          hasSchool: links.valueOrNull?.hasLinks ?? false,
          startSeen: startSeen,
        ),
      );
    }
    return Scaffold(
      backgroundColor: ParvozColors.bg,
      body: Stack(
        children: [
          const Align(alignment: Alignment(0, -0.3), child: ParvozTopGlow()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/icons/parvoz_logo_mark.svg',
                  width: 72,
                  height: 72,
                ),
                const SizedBox(height: 28),
                const SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: ParvozColors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
