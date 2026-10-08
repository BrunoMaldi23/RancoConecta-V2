import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/core/errors/app_failure.dart';
import 'package:ranco_conecta_2/core/result/result.dart';
import 'package:ranco_conecta_2/core/widgets/ranco_status_badge.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_providers.dart';
import 'package:ranco_conecta_2/features/admin/data/admin_settings_repository.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_audit_view.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_screens.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_settings_screens.dart';
import 'package:ranco_conecta_2/features/auth/data/supabase_auth_repository.dart';
import 'package:ranco_conecta_2/features/auth/presentation/sign_in_screen.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

/// FASE 3.22A: recuperar contraseña, Usuarios, Configuración y Auditoría.
void main() {
  Future<void> setSize(WidgetTester tester, double width,
      [double height = 900]) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pump(
    WidgetTester tester,
    Widget screen, [
    List<Override> overrides = const [],
  ]) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => screen),
      GoRoute(
        path: '/sign-in',
        builder: (_, __) => const Scaffold(body: Text('Ingreso UI')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: null,
          supabasePublishableKey: null,
        )),
        currentAdminRoleProvider
            .overrideWith((ref) async => ProfileRole.superAdmin),
        currentProfileProvider.overrideWith((ref) async => const Profile(
              id: 'admin-1',
              fullName: 'Admin Ranco',
              phone: null,
              avatarUrl: null,
              role: ProfileRole.superAdmin,
              accountStatus: 'active',
            )),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // ---------------------------------------------------------------------------
  // Recuperar contraseña
  // ---------------------------------------------------------------------------
  group('forgot password', () {
    for (final width in [390.0, 768.0, 1024.0, 1366.0, 1440.0, 1600.0]) {
      testWidgets('form and success state fit at ${width.toInt()}px',
          (tester) async {
        await setSize(tester, width);
        final auth = _ResetAuth();
        await pump(tester, const ForgotPasswordScreen(), [
          authRepositoryProvider.overrideWithValue(auth),
        ]);
        expect(find.text('Recuperar contraseña'), findsOneWidget);
        expect(find.text('Ingresa el correo asociado a tu cuenta.'),
            findsOneWidget);
        expect(find.text('Volver a iniciar sesión'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), 'vecina@ranco.cl');
        await tester.tap(find.text('Enviar instrucciones'));
        await tester.pumpAndSettle();

        expect(find.text('Revisa tu correo'), findsOneWidget);
        expect(find.textContaining('vecina@ranco.cl', findRichText: true),
            findsOneWidget);
        expect(find.text('Reenviar correo'), findsOneWidget);
        expect(find.text('Enviar instrucciones'), findsNothing);
        expect(auth.calls, 1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('resend reuses the existing call; "otro correo" goes back',
        (tester) async {
      await setSize(tester, 1366);
      final auth = _ResetAuth();
      await pump(tester, const ForgotPasswordScreen(), [
        authRepositoryProvider.overrideWithValue(auth),
      ]);
      await tester.enterText(find.byType(TextFormField), 'vecina@ranco.cl');
      await tester.tap(find.text('Enviar instrucciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reenviar correo'));
      await tester.pumpAndSettle();
      expect(auth.calls, 2);
      expect(find.text('Te reenviamos el correo.'), findsOneWidget);
      await tester.tap(find.text('Usar otro correo'));
      await tester.pumpAndSettle();
      expect(find.text('Enviar instrucciones'), findsOneWidget);
    });

    testWidgets('invalid email validates in place; failures stay in form',
        (tester) async {
      await setSize(tester, 390);
      final auth = _ResetAuth(fail: true);
      await pump(tester, const ForgotPasswordScreen(), [
        authRepositoryProvider.overrideWithValue(auth),
      ]);
      await tester.tap(find.text('Enviar instrucciones'));
      await tester.pumpAndSettle();
      expect(auth.calls, 0);
      await tester.enterText(find.byType(TextFormField), 'vecina@ranco.cl');
      await tester.tap(find.text('Enviar instrucciones'));
      await tester.pumpAndSettle();
      expect(find.text('No pudimos enviar el correo.'), findsOneWidget);
      expect(find.text('Revisa tu correo'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Admin > Usuarios
  // ---------------------------------------------------------------------------
  const rows = [
    {
      'id': 'u1',
      'full_name': 'Vecina Ranco',
      'email': 'vecina@example.com',
      'role': 'customer',
      'account_status': 'active',
      'created_at': '2026-09-30T12:00:00Z',
    },
    {
      'id': 'admin-1',
      'full_name': 'Admin Ranco',
      'email': 'admin@example.com',
      'role': 'admin',
      'account_status': 'active',
      'created_at': '2026-09-01T12:00:00Z',
    },
  ];

  List<Override> usersOverrides({bool ready = false}) => [
        adminUserMutationsReadyProvider.overrideWith((ref) async => ready),
        adminUsersProvider.overrideWith((ref, query) async {
          final filtered = query.role == 'ADMIN'
              ? rows.where((row) => row['role'] == 'admin').toList()
              : rows.toList();
          return AdminUsersPage(rows: filtered, total: filtered.length);
        }),
      ];

  group('admin users', () {
    testWidgets('desktop table with hierarchy, counts and compact actions',
        (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminUsersScreen(), usersOverrides());
      await tester.pumpAndSettle();
      for (final header in ['Rol', 'Estado', 'Registro', 'Acciones']) {
        expect(find.text(header), findsOneWidget);
      }
      expect(find.text('2 cuentas'), findsOneWidget);
      expect(find.text('vecina@example.com'), findsOneWidget);
      await tester.ensureVisible(find.text('Administradores'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Administradores'));
      await tester.pumpAndSettle();
      expect(find.text('1 administrador'), findsOneWidget);
      expect(find.text('Vecina Ranco'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('blocked actions stay disabled with a visible reason',
        (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminUsersScreen(), usersOverrides());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Acciones de la cuenta').first);
      await tester.pumpAndSettle();
      expect(find.text('Ver detalle'), findsOneWidget);
      expect(find.text('Cambiar rol'), findsOneWidget);
      expect(find.text('Suspender cuenta'), findsOneWidget);
      expect(find.text(AdminUserActions.unavailableHint), findsNWidgets(2));
      final role = tester.widget<PopupMenuItem<String>>(find.ancestor(
        of: find.text('Cambiar rol'),
        matching: find.byType(PopupMenuItem<String>),
      ));
      expect(role.enabled, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('own account cannot be suspended even when ready',
        (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminUsersScreen(), usersOverrides(ready: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Acciones de la cuenta').last);
      await tester.pumpAndSettle();
      expect(
          find.text('No puedes suspender tu propia cuenta.'), findsOneWidget);
    });

    testWidgets('tablet hides the Registro column', (tester) async {
      // Contenido ~810 px junto al sidebar admin: tabla compacta.
      await setSize(tester, 1100);
      await pump(tester, const AdminUsersScreen(), usersOverrides());
      await tester.pumpAndSettle();
      expect(find.text('Rol'), findsOneWidget);
      expect(find.text('Registro'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile shows one card per account and the menu fits',
        (tester) async {
      await setSize(tester, 390, 844);
      await pump(tester, const AdminUsersScreen(), usersOverrides());
      await tester.pumpAndSettle();
      expect(find.text('Rol'), findsNothing);
      expect(find.text('Vecina Ranco'), findsOneWidget);
      await tester.tap(find.byTooltip('Acciones de la cuenta').first);
      await tester.pumpAndSettle();
      expect(find.text('Suspender cuenta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading keeps search and filters mounted', (tester) async {
      await setSize(tester, 1440);
      final pending = Completer<AdminUsersPage>();
      await pump(tester, const AdminUsersScreen(), [
        adminUserMutationsReadyProvider.overrideWith((ref) async => false),
        adminUsersProvider.overrideWith((ref, query) => pending.future),
      ]);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Administradores'), findsOneWidget);
      expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    });

    testWidgets('error offers retry without technical details', (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminUsersScreen(), [
        adminUserMutationsReadyProvider.overrideWith((ref) async => false),
        adminUsersProvider
            .overrideWith((ref, query) async => throw StateError('PGRST500')),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar las cuentas.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.textContaining('PGRST'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Admin > Configuración
  // ---------------------------------------------------------------------------
  final whatsApp = adminWhatsAppSettingsProvider.overrideWith(
    (ref) async => const AdminWhatsAppSettings(
      number: '56912345678',
      enabled: true,
      newBusiness: true,
      businessChanges: false,
      userReports: true,
    ),
  );

  group('admin settings', () {
    testWidgets('WhatsApp separates status, configuration and events',
        (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminWhatsAppSettingsScreen(), [whatsApp]);
      await tester.pumpAndSettle();
      expect(find.text('Pronto'), findsNothing);
      expect(find.text('Envío manual'), findsOneWidget);
      expect(find.text('+56912345678'), findsOneWidget);
      expect(find.text('Activar avisos'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(3));
      expect(find.text('Guardar configuración'), findsOneWidget);
      // Eventos no disponibles: plegados, no ocupan espacio.
      expect(find.text('Negocio rechazado'), findsNothing);
      await tester.ensureVisible(find.text('Otros eventos (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otros eventos (2)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Negocio rechazado'));
      expect(find.text('Negocio rechazado'), findsOneWidget);
    });

    testWidgets('sections without backend explain, never simulate',
        (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminWhatsAppSettingsScreen(), [whatsApp]);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Integraciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Integraciones'));
      await tester.pumpAndSettle();
      // FASE 3.25: estado vacío honesto, sin controles simulados.
      expect(find.text('No hay integraciones configuradas.'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await tester.ensureVisible(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      expect(find.text('Activar avisos'), findsOneWidget);
    });

    for (final width in [360.0, 390.0, 768.0]) {
      testWidgets('tabs and events fit at ${width.toInt()}px', (tester) async {
        await setSize(tester, width, 844);
        await pump(tester, const AdminWhatsAppSettingsScreen(), [whatsApp]);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('loading keeps the tabs and shows a skeleton', (tester) async {
      await setSize(tester, 1440);
      final pending = Completer<AdminWhatsAppSettings>();
      await pump(tester, const AdminWhatsAppSettingsScreen(), [
        adminWhatsAppSettingsProvider.overrideWith((ref) => pending.future),
      ]);
      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Admin > Auditoría
  // ---------------------------------------------------------------------------
  final now = DateTime.now().toUtc();
  final events = [
    {
      'id': 'e1',
      'actor_id': 'a1b2c3d4-0000',
      'action': 'business_published',
      'entity_type': 'business',
      'entity_id': 'b1234567-89',
      'created_at': now.toIso8601String(),
    },
    {
      'id': 'e2',
      'actor_id': 'a1b2c3d4-0000',
      'action': 'user_suspended',
      'entity_type': 'profile',
      'entity_id': 'u7654321-00',
      'created_at': now.subtract(const Duration(days: 40)).toIso8601String(),
    },
    {
      'id': 'e3',
      'actor_id': null,
      'action': 'category_created',
      'entity_type': 'category',
      'entity_id': 'c1',
      'created_at': now.subtract(const Duration(days: 2)).toIso8601String(),
    },
  ];

  group('admin audit', () {
    test('action codes become human labels and results', () {
      expect(adminAuditActionLabel('business_published'), 'Negocio publicado');
      expect(adminAuditActionLabel('user_role_changed'), 'Rol actualizado');
      expect(adminAuditActionLabel('some_future_event'), 'Some future event');
      expect(adminAuditResourceLabel('profile'), 'Cuenta');
      expect(adminAuditResult('business_rejected').$2, RancoStatusTone.danger);
      expect(adminAuditResult('business_published').$1, 'Activo');
      expect(adminAuditResult('category_updated').$1, 'Registrado');
    });

    testWidgets('desktop table with real rows, filters and summary',
        (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminAuditScreen(), [
        adminAuditEventsProvider.overrideWith((ref) async => events),
      ]);
      await tester.pumpAndSettle();
      for (final header in ['Fecha', 'Actor', 'Acción', 'Recurso']) {
        expect(find.text(header), findsOneWidget);
      }
      expect(find.text('Resultado'), findsOneWidget);
      expect(find.text('Últimas 3 acciones'), findsOneWidget);
      expect(find.text('Negocio publicado'), findsOneWidget);
      expect(find.text('Cuenta suspendida'), findsOneWidget);
      expect(find.text('Sistema'), findsOneWidget);

      await tester.tap(find.text('Cuentas'));
      await tester.pumpAndSettle();
      expect(find.text('Negocio publicado'), findsNothing);
      expect(find.text('Cuenta suspendida'), findsOneWidget);

      await tester.tap(find.text('Todo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filtrar por fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Últimos 7 días').last);
      await tester.pumpAndSettle();
      expect(find.text('Cuenta suspendida'), findsNothing);
      expect(find.text('Categoría creada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no match offers to clear filters', (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminAuditScreen(), [
        adminAuditEventsProvider.overrideWith((ref) async => events),
      ]);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Ninguna acción coincide con los filtros.'),
          findsOneWidget);
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Negocio publicado'), findsOneWidget);
    });

    testWidgets('empty, error and loading states are compact', (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminAuditScreen(), [
        adminAuditEventsProvider.overrideWith((ref) async => const []),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('No hay acciones registradas todavía.'), findsOneWidget);
      expect(find.text('Limpiar filtros'), findsNothing);
    });

    testWidgets('error state retries', (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminAuditScreen(), [
        adminAuditEventsProvider
            .overrideWith((ref) async => throw StateError('rls')),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar el historial.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('loading shows a table-shaped skeleton', (tester) async {
      await setSize(tester, 1440);
      final pending = Completer<List<Map<String, dynamic>>>();
      await pump(tester, const AdminAuditScreen(), [
        adminAuditEventsProvider.overrideWith((ref) => pending.future),
      ]);
      expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    for (final width in [390.0, 768.0, 1024.0]) {
      testWidgets('timeline/table fit at ${width.toInt()}px', (tester) async {
        await setSize(tester, width, 844);
        await pump(tester, const AdminAuditScreen(), [
          adminAuditEventsProvider.overrideWith((ref) async => events),
        ]);
        await tester.pumpAndSettle();
        expect(find.text('Negocio publicado'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// Auth mínima: solo `sendPasswordResetEmail` (sin Supabase).
class _ResetAuth implements AuthRepository {
  _ResetAuth({this.fail = false});

  final bool fail;
  int calls = 0;

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    calls++;
    return fail
        ? const Failure(AppFailure(
            type: AppFailureType.network,
            message: 'No pudimos enviar el correo.',
          ))
        : const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
