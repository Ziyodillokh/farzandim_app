// Kirish so'rovlarini tasdiqlash/rad etish — ulangan qurilma ko'radi.
//
// Push (session_access_request) bosilganda ochiladi. Tasdiqlansa — Faol
// seanslar sahifasiga o'tadi ("bitta qurilmani chiqaring" banneri bilan),
// so'ng qurilma chiqarilgach 3-qurilma avtomatik kiradi.

import 'package:farzandim/core/routing/app_routes.dart';
import 'package:farzandim/features/auth/data/repositories/backend_session_access_repository.dart';
import 'package:farzandim/shared/widgets/parvoz_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionAccessApproveScreen extends ConsumerStatefulWidget {
  const SessionAccessApproveScreen({super.key});

  @override
  ConsumerState<SessionAccessApproveScreen> createState() =>
      _SessionAccessApproveScreenState();
}

class _SessionAccessApproveScreenState
    extends ConsumerState<SessionAccessApproveScreen> {
  late Future<List<SessionAccessRequestInfo>> _future;
  bool _acting = false;

  BackendSessionAccessRepository get _repo =>
      ref.read(backendSessionAccessRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _future = _repo.listPending();
  }

  void _reload() => setState(() => _future = _repo.listPending());

  Future<void> _approve(String id) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await _repo.approve(id);
      if (!mounted) return;
      // Faol seanslarga o'tamiz — "bitta qurilmani chiqaring" banneri bilan.
      context.go('${AppRoutes.settingsSessions}?remove=1');
    } catch (_) {
      if (!mounted) return;
      setState(() => _acting = false);
      _snack("Tasdiqlab bo'lmadi. Qayta urining.");
    }
  }

  Future<void> _reject(String id) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await _repo.reject(id);
      if (!mounted) return;
      setState(() => _acting = false);
      _reload();
      _snack("So'rov rad etildi");
    } catch (_) {
      if (!mounted) return;
      setState(() => _acting = false);
      _snack("Rad etib bo'lmadi. Qayta urining.");
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF10151C),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
      ),
    );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParvozColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: FutureBuilder<List<SessionAccessRequestInfo>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: ParvozColors.blue,
                      ),
                    );
                  }
                  final items = snap.data ?? const <SessionAccessRequestInfo>[];
                  if (items.isEmpty) return _empty();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _requestCard(items[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
        ),
        const Expanded(
          child: Text(
            "Kirish so'rovlari",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 44),
      ],
    ),
  );

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_rounded,
            size: 56,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            "Ochiq so'rov yo'q",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _requestCard(SessionAccessRequestInfo r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: ParvozColors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.smartphone_rounded,
                  color: ParvozColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.ipAddress ?? 'Yangi qurilma kirmoqchi',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _btn(
                  label: 'Rad etish',
                  color: const Color(0xFFFF453A),
                  filled: false,
                  onTap: () => _reject(r.id),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _btn(
                  label: 'Tasdiqlash',
                  color: const Color(0xFF22C55E),
                  filled: true,
                  onTap: () => _approve(r.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn({
    required String label,
    required Color color,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _acting ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: filled ? 1 : 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : color,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
