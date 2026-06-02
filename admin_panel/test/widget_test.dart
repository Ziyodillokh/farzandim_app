import 'package:flutter_test/flutter_test.dart';

import 'package:admin_panel_flutter/core/layout/admin_layout.dart';
import 'package:admin_panel_flutter/core/network/admin_session.dart';
import 'package:admin_panel_flutter/main.dart';

import 'support/memory_token_storage.dart';
import 'support/test_jwt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AdminSession.bindStorage(
      MemoryTokenStorage(
        accessToken: testAccessJwt(),
        refreshToken: 'test-refresh',
      ),
    );
    await AdminSession.hydrate();
  });

  testWidgets('renders admin shell', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminPanelApp());
    await tester.pumpAndSettle();
    expect(find.byType(AdminLayout), findsOneWidget);
  });
}
