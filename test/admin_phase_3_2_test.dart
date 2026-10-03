import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_providers.dart';
import 'package:ranco_conecta_2/features/admin/data/admin_settings_repository.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_settings_screens.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/features/profile/presentation/account_screen.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

void main() {
  test('review WhatsApp link uses configured number and encodes details', () {
    const details = ReviewWhatsAppDetails(
      number: '+56 9 1234 5678',
      businessName: 'Cabañas Ranco & Lago',
      category: 'Turismo y Aventura',
      location: 'Lago Ranco',
      eventType: 'submitted',
    );
    expect(details.link.host, 'wa.me');
    expect(details.link.path, '/56912345678');
    expect(
        details.link.queryParameters['text'], contains('Cabañas Ranco & Lago'));
    expect(
        details.link.queryParameters['text'], contains('Turismo y Aventura'));
  });

  testWidgets(
      'admin account shows admin access without provider promotion at 360px',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const AccountScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const Scaffold()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: null,
          supabasePublishableKey: null,
        )),
        authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(
              id: 'admin-1',
              email: 'admin@example.com',
              emailConfirmed: true,
            ))),
        currentProfileProvider.overrideWith((ref) async => const Profile(
              id: 'admin-1',
              fullName: 'Admin Ranco',
              phone: null,
              avatarUrl: null,
              role: ProfileRole.admin,
              accountStatus: 'active',
            )),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    // Cuenta muestra un único acceso al panel; los módulos viven en /admin.
    expect(find.text('Administración'), findsOneWidget);
    expect(find.text('Panel administrativo'), findsOneWidget);
    expect(find.text('Abrir panel'), findsOneWidget);
    expect(find.text('Revisiones pendientes'), findsNothing);
    expect(find.text('Publicar negocio gratis'), findsNothing);
    expect(find.text('¿Tienes un negocio?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('WhatsApp settings fit at 360px', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(routes: [
      GoRoute(
          path: '/', builder: (_, __) => const AdminWhatsAppSettingsScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAdminRoleProvider.overrideWith((ref) async => ProfileRole.admin),
        adminWhatsAppSettingsProvider.overrideWith((ref) async =>
            const AdminWhatsAppSettings(
                number: '',
                enabled: false,
                newBusiness: true,
                businessChanges: true,
                userReports: true)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Admin / Configuración'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(
          CheckboxListTile, 'Nuevo negocio pendiente de revisión'),
      220,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.widgetWithText(
        CheckboxListTile,
        'Nuevo negocio pendiente de revisión',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin users directory fits at tablet width', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const AdminUsersScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAdminRoleProvider.overrideWith((ref) async => ProfileRole.admin),
        adminUsersProvider.overrideWith((ref, query) async {
          final rows = <Map<String, dynamic>>[
            <String, dynamic>{
              'full_name': 'Vecina Ranco',
              'email': 'vecina@example.com',
              'role': 'customer',
              'account_status': 'active',
            },
            <String, dynamic>{
              'full_name': 'Admin Ranco',
              'email': 'admin@example.com',
              'role': 'admin',
              'account_status': 'active',
            },
          ];
          final filteredByRole = query.role == null
              ? rows
              : rows
                  .where((row) => row['role'] == query.role!.toLowerCase())
                  .toList();
          final filtered = filteredByRole
              .where((row) =>
                  query.search == null ||
                  query.search!.isEmpty ||
                  row['full_name']
                      .toString()
                      .toLowerCase()
                      .contains(query.search!.toLowerCase()) ||
                  row['email']
                      .toString()
                      .toLowerCase()
                      .contains(query.search!.toLowerCase()))
              .toList();
          return AdminUsersPage(rows: filtered, total: filtered.length);
        }),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Vecina Ranco'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Administradores'));
    await tester.pumpAndSettle();
    expect(find.text('Vecina Ranco'), findsNothing);
    expect(find.text('Admin Ranco'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'nadie');
    await tester.pumpAndSettle();
    expect(find.text('No hay usuarios en esta página.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
