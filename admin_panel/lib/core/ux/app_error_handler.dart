import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../errors/app_exceptions.dart';
import '../network/admin_session.dart';
import '../network/dio_error_mapper.dart';

/// Maps errors to Uzbek copy and surfaces snackbars / dialogs.
abstract final class AppErrorHandler {
  static String userMessage(Object error) {
    if (error is AppException) {
      if (error is NetworkException) {
        switch (error.kind) {
          case NetworkFailureKind.noConnection:
            return "Internet yo'q";
          case NetworkFailureKind.timeout:
            return 'Ulanish vaqti tugadi';
          case NetworkFailureKind.cancelled:
            return 'So‘rov bekor qilindi';
          case NetworkFailureKind.serverError:
            return 'Server bilan aloqa xatosi';
          case NetworkFailureKind.unknown:
            return 'Tarmoq xatosi';
        }
      }
      if (error is ServerException) {
        return 'Serverda muammo';
      }
      if (error is AuthException) {
        return 'Ruxsat yo‘q';
      }
      return error.message;
    }
    if (error is DioException) {
      return userMessage(mapDioException(error));
    }
    return 'Noma’lum xato';
  }

  /// Strong error feedback with optional retry (never silent).
  static void showError(
    BuildContext context,
    Object error, {
    VoidCallback? onRetry,
  }) {
    final msg = userMessage(error);
    if (error is AuthException && AdminSession.isAuthenticated) {
      unawaited(AdminSession.clear(cause: SessionClearCause.forcedAuthFailure));
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2D3142),
        duration: const Duration(seconds: 6),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        action: onRetry == null
            ? null
            : SnackBarAction(
                label: 'Qayta urinish',
                textColor: Colors.white,
                onPressed: onRetry,
              ),
      ),
    );
  }

  static Future<void> showSessionExpiredDialog(BuildContext context) async {
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sessiya tugadi'),
        content: const Text('Sessiya tugadi. Qayta login qiling.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ctx.go('/login');
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}
