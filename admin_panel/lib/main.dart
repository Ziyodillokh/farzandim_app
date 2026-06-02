import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_environment.dart';
import 'core/network/admin_api.dart';
import 'core/layout/admin_layout.dart';
import 'core/layout/sidebar_cubit.dart';
import 'core/layout/sidebar_rail_cubit.dart';
import 'core/logging/app_logger.dart';
import 'core/network/admin_session.dart';
import 'core/storage/secure_token_storage_factory.dart';
import 'core/theme/app_theme.dart';
import 'core/ux/connectivity_cubit.dart';
import 'features/analytics/analytics_page.dart';
import 'features/auth/login_page.dart';
import 'features/content/audiobooks_page.dart';
import 'features/content/books_page.dart';
import 'features/content/content_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/moderators/moderator_form_page.dart';
import 'features/moderators/moderators_page.dart';
import 'features/monetization/monetization_payments_page.dart';
import 'features/monetization/monetization_plans_page.dart';
import 'features/monetization/monetization_promocodes_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/settings/audit_log_page.dart';
import 'features/settings/settings_page.dart';
import 'features/users/users_page.dart';
import 'features/konkurs/konkurslar_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironment.assertConfiguration();
  try {
    final storage = await createSecureTokenStorage();
    AdminSession.bindStorage(storage);
    await AdminSession.hydrate();
    if (AdminSession.token != null) {
      try {
        final me = await AdminApi().fetchStaffMe();
        if (me.isNotEmpty) {
          AdminSession.applyStaffProfile(me);
        }
      } catch (_) {
        // Offline / expired — sidebar falls back until next login.
      }
    }
    AppLogger.info('Admin panel starting ${AppEnvironment.flavor.name}');
  } catch (e, st) {
    AppLogger.error('Startup storage failed', error: e, stackTrace: st);
  }
  runApp(const AdminPanelApp());
}

class AdminPanelApp extends StatelessWidget {
  const AdminPanelApp({super.key});

  static final _router = GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: AdminSession.authRevision,
    redirect: (context, state) {
      final token = AdminSession.token;
      final isLoggedIn = token != null && token.trim().isNotEmpty;
      final isLoginRoute = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/dashboard', builder: (context, state) => const AdminLayout(child: DashboardPage())),
      GoRoute(path: '/users', builder: (context, state) => const AdminLayout(child: UsersPage())),
      GoRoute(
        path: '/content',
        redirect: (context, state) => '/content/videos',
      ),
      GoRoute(
        path: '/content/videos',
        builder: (context, state) => const AdminLayout(child: ContentPage()),
      ),
      GoRoute(
        path: '/content/audiobooks',
        builder: (context, state) => const AdminLayout(child: AudiobooksPage()),
      ),
      GoRoute(
        path: '/content/books',
        builder: (context, state) => const AdminLayout(child: BooksPage()),
      ),
      GoRoute(path: '/contests', builder: (context, state) => const AdminLayout(child: KonkurslarPage())),
      GoRoute(path: '/settings', builder: (context, state) => const AdminLayout(child: SettingsPage())),
      GoRoute(path: '/settings/audit-log', builder: (context, state) => const AdminLayout(child: AuditLogPage())),
      GoRoute(
        path: '/moderators/new',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return AdminLayout(
            child: ModeratorFormPage(
              editId: id == null || id.isEmpty ? null : id,
            ),
          );
        },
      ),
      GoRoute(path: '/moderators', builder: (context, state) => const AdminLayout(child: ModeratorsPage())),
      GoRoute(
        path: '/monetization',
        redirect: (context, state) => '/monetization/plans',
      ),
      GoRoute(
        path: '/monetization/plans',
        builder: (context, state) => const AdminLayout(child: MonetizationPlansPage()),
      ),
      GoRoute(
        path: '/monetization/promocodes',
        builder: (context, state) => const AdminLayout(child: MonetizationPromocodesPage()),
      ),
      GoRoute(
        path: '/monetization/payments',
        builder: (context, state) => const AdminLayout(child: MonetizationPaymentsPage()),
      ),
      GoRoute(path: '/analytics', builder: (context, state) => const AdminLayout(child: AnalyticsPage())),
      GoRoute(path: '/notifications', builder: (context, state) => const AdminLayout(child: NotificationsPage())),
      GoRoute(path: '/settings', builder: (context, state) => const AdminLayout(child: _PlaceholderPage(title: 'Sozlamalar'))),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SidebarCubit()),
        BlocProvider(create: (_) => SidebarRailCubit()),
        BlocProvider(create: (_) => ConnectivityCubit()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Farzandim Admin Panel',
        theme: AppTheme.light(),
        routerConfig: _router,
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
    );
  }
}
