// ─────────────────────────────────────────────────────────────────────
// ListenScreen — ota-ona bola atrofini JONLI eshitadigan ekran
// ─────────────────────────────────────────────────────────────────────
//
// ⚠️ Ovoz SAQLANMAYDI — faqat jonli. Ekran ochilganda sessiya boshlanadi
// (bola qurilmasi uyg'onadi), yopilganda yoki "To'xtatish"da hammasi
// yopiladi. Bola tomonida "Ota-onangiz tinglamoqda" indikatori ko'rinadi.

import 'package:farzandim/core/realtime/socket_client.dart';
import 'package:farzandim/features/listen/data/repositories/listen_repository.dart';
import 'package:farzandim/features/listen/data/services/parent_listen_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ListenScreen extends ConsumerStatefulWidget {
  const ListenScreen({
    required this.childId,
    required this.childName,
    super.key,
  });

  final String childId;
  final String childName;

  @override
  ConsumerState<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends ConsumerState<ListenScreen> {
  ParentListenController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    final controller = ParentListenController(
      socket: ref.read(socketClientProvider),
      repo: ref.read(listenRepositoryProvider),
    );
    setState(() => _controller = controller);
    final ok = await controller.start(widget.childId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Eshitishni boshlab bo'lmadi")),
      );
    }
  }

  Future<void> _stop() async {
    await _controller?.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: SafeArea(
        child: controller == null
            ? const Center(child: CircularProgressIndicator())
            : ValueListenableBuilder<ListenPhase>(
                valueListenable: controller.phase,
                builder: (context, phase, _) => _body(phase),
              ),
      ),
    );
  }

  Widget _body(ListenPhase phase) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          _pulse(phase),
          const SizedBox(height: 32),
          Text(
            widget.childName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusText(phase),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9999A8), fontSize: 15),
          ),
          const SizedBox(height: 12),
          const Text(
            "Bola qurilmasida sizning tinglayotganingiz ko'rinib turibdi.\n"
            'Ovoz hech qayerda saqlanmaydi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B6B78), fontSize: 12),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _stop,
              icon: const Icon(Icons.stop_rounded),
              label: const Text(
                "To'xtatish",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pulse(ListenPhase phase) {
    final active = phase == ListenPhase.listening;
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? const Color(0xFFEF4444).withValues(alpha: 0.15)
            : const Color(0xFF252530),
        border: Border.all(
          color: active ? const Color(0xFFEF4444) : const Color(0xFF2A2A35),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.mic,
        size: 56,
        color: active ? const Color(0xFFEF4444) : const Color(0xFF9999A8),
      ),
    );
  }

  String _statusText(ListenPhase phase) {
    switch (phase) {
      case ListenPhase.connecting:
        return "Ulanmoqda… bola qurilmasi uyg'onmoqda";
      case ListenPhase.listening:
        return 'Jonli eshitilmoqda';
      case ListenPhase.ended:
        return 'Eshitish tugadi';
      case ListenPhase.error:
        return "Ulanib bo'lmadi. Bola telefoni oflayn bo'lishi mumkin.";
    }
  }
}
