// Kamera ruxsati: Ekran vaqti kamerani cheklagan bo'lsa (iOS `restricted`,
// tizim oynasi chiqmaydi) ishlamaydigan "Ruxsat berish" o'rniga ota-onadan
// so'rash kerakligi aytiladi.

import 'package:easy_localization/easy_localization.dart';
import 'package:farzandim_child/features/school/presentation/widgets/qr_camera_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'fake_school_repository.dart';
import 'school_test_app.dart';

const _permissions = MethodChannel('flutter.baseflow.com/permissions/methods');

/// Kamera hech qachon ochilmaydi — yopilishdagi `stop` jim o'tsin.
const _scanner = MethodChannel('dev.steenbakker.mobile_scanner/scanner/method');

/// Kamera ruxsati shu holatda (so'ralsa ham o'zgarmaydi).
void _mockCameraStatus(PermissionStatus status) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_permissions, (call) async {
    return switch (call.method) {
      'checkPermissionStatus' => status.index,
      'requestPermissions' => {Permission.camera.value: status.index},
      _ => null,
    };
  });
  messenger.setMockMethodCallHandler(_scanner, (_) async => null);
  addTearDown(() {
    messenger
      ..setMockMethodCallHandler(_permissions, null)
      ..setMockMethodCallHandler(_scanner, null);
  });
}

void main() {
  test('ruxsat holati: berilgan, rad etilgan, cheklangan', () {
    expect(cameraAccessOf(PermissionStatus.granted), CameraAccess.granted);
    expect(cameraAccessOf(PermissionStatus.denied), CameraAccess.denied);
    expect(
      cameraAccessOf(PermissionStatus.permanentlyDenied),
      CameraAccess.denied,
    );
    expect(
      cameraAccessOf(PermissionStatus.restricted),
      CameraAccess.restricted,
    );
  });

  group('kamera ko\'rinishi', () {
    setUpAll(setUpSchoolWidgetTests);

    Future<void> pump(WidgetTester tester) async {
      await pumpSchoolApp(
        tester,
        repository: FakeSchoolRepository(),
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: QrCameraView(onCode: _ignore, overlay: SizedBox()),
            ),
          ),
        ],
      );
      await tester.pump();
    }

    testWidgets('Ekran vaqti cheklagan — tugmasiz izoh', (tester) async {
      _mockCameraStatus(PermissionStatus.restricted);
      await pump(tester);

      expect(find.text('school.checkIn.restrictedTitle'.tr()), findsOneWidget);
      expect(find.text('school.checkIn.restrictedBody'.tr()), findsOneWidget);
      expect(find.text('common.grantPermission'.tr()), findsNothing);
      expect(find.text('common.openSettings'.tr()), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('rad etilgan — "Ruxsat berish" va "Sozlamalarni ochish"', (
      tester,
    ) async {
      _mockCameraStatus(PermissionStatus.permanentlyDenied);
      await pump(tester);

      expect(find.text('school.checkIn.permissionTitle'.tr()), findsOneWidget);
      expect(find.text('common.grantPermission'.tr()), findsOneWidget);
      expect(find.text('common.openSettings'.tr()), findsOneWidget);
    });
  });
}

void _ignore(String _) {}
