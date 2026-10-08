import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_providers.dart';
import 'package:ranco_conecta_2/features/admin/data/admin_settings_repository.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_settings_screens.dart';
import 'package:ranco_conecta_2/features/legal/presentation/legal_screen.dart';
import 'package:ranco_conecta_2/features/notifications/application/notification_providers.dart';
import 'package:ranco_conecta_2/features/notifications/presentation/notifications_screen.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/shared/models/app_notification.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

/// FASE 3.25: legales sin resumen, Contacto, Notificaciones, Usuarios y
/// Configuración (solo UI).
void main() {
  setUpAll(() => initializeDateFormatting('es'));

  const widths = [390.0, 768.0, 1024.0, 1440.0, 1600.0];

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
      for (final path in ['/terminos', '/politica-privacidad', '/contacto'])
        GoRoute(
            path: path, builder: (_, __) => Scaffold(body: Text('Ruta $path'))),
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
    await tester.pumpAndSettle();
  }

  // --- Legales -------------------------------------------------------------
  group('legal', () {
    testWidgets('no summary block; cards still expand', (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const LegalScreen(privacy: true));
      expect(find.text('EN POCAS PALABRAS'), findsNothing);
      expect(find.text('Ver detalle'), findsNWidgets(5));
      await tester.tap(find.text('Tus opciones'));
      await tester.pumpAndSettle();
      expect(find.text('Ocultar detalle'), findsOneWidget);
    });

    testWidgets('closing legal navigation is a clean pill strip',
        (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const LegalScreen(privacy: false));
      final links = find.byKey(const ValueKey('legal-links'));
      expect(
          find.descendant(of: links, matching: find.text('Información legal')),
          findsOneWidget);
      expect(
          find.descendant(of: links, matching: find.text('·')), findsNothing);
      for (final label in ['Términos', 'Privacidad', 'Contacto']) {
        expect(find.descendant(of: links, matching: find.text(label)),
            findsOneWidget);
      }
    });
  });

  // --- Contacto ------------------------------------------------------------
  group('contact', () {
    testWidgets('form fields, reasons and helper text', (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const ContactScreen());
      expect(find.text('Hablemos'), findsOneWidget);
      expect(find.text('Consultas, ayuda y solicitudes sobre Ranco Conecta.'),
          findsOneWidget);
      for (final label in ['Nombre', 'Correo', 'Mensaje']) {
        expect(find.widgetWithText(TextFormField, label), findsOneWidget);
      }
      expect(find.text('Motivo de contacto'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(contactReasons.length));
      expect(
        find.text('Responderemos utilizando los datos que nos proporciones '
            'en este formulario.'),
        findsOneWidget,
      );
      // El envío lo conecta Codex: aquí solo se verifica la presencia del CTA
      // y que no se inventen canales.
      expect(find.text('Enviar mensaje'), findsOneWidget);
      expect(find.text('Otros canales'), findsNothing);
    });

    testWidgets('selecting a reason marks only that chip', (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const ContactScreen());
      await tester.tap(find.text('Privacidad y datos').first);
      await tester.pump();
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      expect(chips.where((chip) => chip.selected), hasLength(1));
      final selected = tester.widget<ChoiceChip>(find.ancestor(
          of: find.text('Privacidad y datos').first,
          matching: find.byType(ChoiceChip)));
      expect(selected.selected, isTrue);
    });

    for (final width in widths) {
      testWidgets('contact fits at ${width.toInt()}px', (tester) async {
        await setSize(tester, width);
        await pump(tester, const ContactScreen());
        expect(tester.takeException(), isNull);
      });
    }
  });

  // --- Notificaciones ------------------------------------------------------
  group('notifications', () {
    final now = DateTime.now();
    AppNotification item(String id, String type,
            {bool read = false, int daysAgo = 0}) =>
        AppNotification(
          id: id,
          type: type,
          title: 'Aviso $id',
          body: 'Detalle del aviso $id.',
          createdAt: now.subtract(Duration(days: daysAgo)),
          readAt: read ? now : null,
          deepLink: '/requests',
        );
    final mixed = [
      item('1', 'service_request_created'),
      item('2', 'provider_pending_review', read: true),
      item('3', 'new_message', daysAgo: 1),
      item('4', 'system_notice', read: true, daysAgo: 20),
    ];

    Future<void> pumpList(WidgetTester tester, List<AppNotification> items,
        [double width = 1440]) async {
      await setSize(tester, width);
      await pump(tester, const NotificationsScreen(), [
        notificationListProvider.overrideWith((ref) async => items),
      ]);
    }

    test('categories derive from real notification types', () {
      expect(notificationCategoryOf('service_request_created'),
          NotificationCategory.requests);
      expect(notificationCategoryOf('new_lodging_booking'),
          NotificationCategory.requests);
      expect(notificationCategoryOf('provider_pending_review'),
          NotificationCategory.business);
      expect(notificationCategoryOf('something_else'),
          NotificationCategory.system);
    });

    testWidgets('header, read and category filters', (tester) async {
      await pumpList(tester, mixed);
      expect(find.text('Revisa novedades sobre tu cuenta y actividad.'),
          findsOneWidget);
      expect(find.text('2 sin leer · 4 en total'), findsOneWidget);
      for (final label in [
        'Todas',
        'Sin leer',
        'Todos',
        'Negocios',
        'Solicitudes',
        'Cuenta',
        'Sistema'
      ]) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('AYER'), findsOneWidget);
      expect(find.text('ANTERIORES'), findsOneWidget);

      await tester.tap(find.text('Sin leer'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso 1'), findsOneWidget);
      expect(find.text('Aviso 2'), findsNothing);

      await tester.tap(find.text('Sin leer'));
      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Negocios'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Negocios'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso 2'), findsOneWidget);
      expect(find.text('Aviso 1'), findsNothing);
    });

    testWidgets('filtered empty offers to see all', (tester) async {
      await pumpList(tester, mixed);
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('No hay notificaciones en esta categoría.'),
          findsOneWidget);
      await tester.tap(find.text('Ver todas'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso 1'), findsOneWidget);
    });

    testWidgets('empty state copy', (tester) async {
      await pumpList(tester, const []);
      expect(find.text('No tienes notificaciones pendientes.'), findsOneWidget);
    });

    for (final count in [1, 2, 20]) {
      for (final width in [390.0, 1024.0, 1440.0]) {
        testWidgets('$count items fit at ${width.toInt()}px', (tester) async {
          await pumpList(
            tester,
            [
              for (var i = 0; i < count; i++)
                item('$i', 'new_message', daysAgo: i)
            ],
            width,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  // --- Admin / Usuarios ----------------------------------------------------
  group('admin users', () {
    const rows = [
      {
        'id': 'u1',
        'full_name': 'Vecina Ranco',
        'email': 'vecina@example.com',
        'role': 'customer',
        'account_status': 'active',
        'created_at': '2026-09-30T12:00:00Z',
      },
    ];
    final overrides = <Override>[
      adminUserMutationsReadyProvider.overrideWith((ref) async => false),
      adminUsersProvider.overrideWith(
          (ref, query) async => const AdminUsersPage(rows: rows, total: 1)),
    ];

    testWidgets('create admin dialog offers invitation', (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminUsersScreen(), overrides);
      await tester.tap(find.text('Crear administrador'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Nombre'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Correo'), findsOneWidget);
      expect(find.text('Rol'), findsWidgets);
      expect(find.text(adminCreationUnavailableHint), findsNothing);
      final submit = tester.widget<FilledButton>(find.ancestor(
          of: find.text('Crear administrador').last,
          matching: find.byType(FilledButton)));
      expect(submit.onPressed, isNotNull);
    });

    testWidgets('menu offers account deactivation with history preservation',
        (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminUsersScreen(), overrides);
      await tester.tap(find.byTooltip('Acciones de la cuenta').first);
      await tester.pumpAndSettle();
      for (final label in [
        'Ver detalle',
        'Cambiar rol',
        'Suspender cuenta',
        'Eliminar usuario',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      final delete = tester.widget<PopupMenuItem<String>>(
          find.byWidgetPredicate((widget) =>
              widget is PopupMenuItem<String> && widget.value == 'delete'));
      expect(delete.enabled, isFalse);
      expect(find.text(AdminUserActions.unavailableHint), findsWidgets);
    });

    testWidgets('detail shows account, role and activity sections',
        (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminUsersScreen(), overrides);
      await tester.tap(find.text('Vecina Ranco'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle de usuario'), findsOneWidget);
      for (final title in [
        'INFORMACIÓN DE CUENTA',
        'ROL Y PERMISOS',
        'ACTIVIDAD',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('30/09/2026'), findsWidgets);
    });

    for (final width in [390.0, 768.0, 1440.0]) {
      testWidgets('users toolbar and dialog fit at ${width.toInt()}px',
          (tester) async {
        await setSize(tester, width, 844);
        await pump(tester, const AdminUsersScreen(), overrides);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Crear administrador'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Crear administrador'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  // --- Admin / Configuración -----------------------------------------------
  group('admin settings', () {
    final overrides = <Override>[
      adminWhatsAppSettingsProvider.overrideWith(
        (ref) async => const AdminWhatsAppSettings(
          number: '56912345678',
          enabled: true,
          newBusiness: true,
          businessChanges: false,
          userReports: true,
        ),
      ),
    ];

    Future<void> openTab(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    testWidgets('general shows real values and "No configurado"',
        (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminWhatsAppSettingsScreen(), overrides);
      expect(find.text('Pronto'), findsNothing);
      await openTab(tester, 'General');
      for (final title in [
        'Información de la plataforma',
        'Contacto y soporte',
        'Operación',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('Ranco Conecta'), findsWidgets);
      expect(find.text('No configurado'), findsWidgets);
    });

    testWidgets('notifications groups show persisted event switches',
        (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminWhatsAppSettingsScreen(), overrides);
      await openTab(tester, 'Notificaciones');
      // "Negocios"/"Usuarios" también existen en el sidebar admin.
      for (final group in ['Negocios', 'Usuarios', 'Plataforma']) {
        expect(find.text(group), findsWidgets);
      }
      expect(find.byType(Switch), findsNWidgets(6));
      expect(
          find.textContaining('eventos sin generación activa'), findsOneWidget);
      expect(find.text('Guardar configuración'), findsNothing);
    });

    testWidgets('integrations show an honest empty state', (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminWhatsAppSettingsScreen(), overrides);
      await openTab(tester, 'Integraciones');
      expect(find.text('No hay integraciones configuradas.'), findsOneWidget);
      expect(find.textContaining('Conectar'), findsNothing);
    });

    testWidgets('whatsapp keeps its flow with "Otros eventos"', (tester) async {
      await setSize(tester, 1440);
      await pump(tester, const AdminWhatsAppSettingsScreen(), overrides);
      expect(find.text('Envío manual'), findsOneWidget);
      expect(find.text('Otros eventos (2)'), findsOneWidget);
      expect(find.text('Guardar configuración'), findsOneWidget);
    });

    for (final width in widths) {
      testWidgets('all settings tabs fit at ${width.toInt()}px',
          (tester) async {
        await setSize(tester, width, 844);
        await pump(tester, const AdminWhatsAppSettingsScreen(), overrides);
        for (final tab in ['General', 'Notificaciones', 'Integraciones']) {
          await openTab(tester, tab);
          expect(tester.takeException(), isNull, reason: tab);
        }
      });
    }
  });
}
