import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../network/admin_session.dart';
import 'app_error_handler.dart';

/// Listens for refresh-driven session loss and shows a blocking dialog before login.
class SessionExpiredHost extends StatefulWidget {
  const SessionExpiredHost({super.key, required this.child});

  final Widget child;

  @override
  State<SessionExpiredHost> createState() => _SessionExpiredHostState();
}

class _SessionExpiredHostState extends State<SessionExpiredHost> {
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    _seen = AdminSession.sessionExpiredTick.value;
    AdminSession.sessionExpiredTick.addListener(_onTick);
  }

  @override
  void dispose() {
    AdminSession.sessionExpiredTick.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    final v = AdminSession.sessionExpiredTick.value;
    if (v != _seen) {
      _seen = v;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        try {
          if (GoRouterState.of(context).matchedLocation == '/login') {
            return;
          }
        } on Object {
          return;
        }
        AppErrorHandler.showSessionExpiredDialog(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
