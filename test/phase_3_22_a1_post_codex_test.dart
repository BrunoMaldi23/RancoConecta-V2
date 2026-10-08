import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/core/errors/app_failure.dart';
import 'package:ranco_conecta_2/core/result/result.dart';
import 'package:ranco_conecta_2/core/widgets/ranco_status_badge.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_audit_view.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_settings_screens.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/data/supabase_auth_repository.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/auth/presentation/sign_in_screen.dart';

/// MICROFASE 3.22A.1: vistas nuevas o alteradas por Codex en 3.22B.
void main() {
  const recovering = AuthUser(
    id: 'u1',
    email: 'vecina@ranco.cl',
    emailConfirmed: true,
  );

  Future<void> setSize(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpReset(
    WidgetTester tester, {
    required Stream<AuthUser?> Function() auth,
    required _RecoveryAuth repository,
  }) async {
    final router = GoRouter(initialLocation: '/reset-password', routes: [
      GoRoute(
        path: '/reset-password',
        builder: (_, __) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/provider/sign-in',
        builder: (_, __) => const Scaffold(body: Text('Ingreso proveedor UI')),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const Scaffold(body: Text('Recuperar UI')),
      ),
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
        authStateProvider.overrideWith((ref) => auth()),
        authRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('reset password', () {
    for (final width in [390.0, 768.0, 1024.0, 1366.0, 1600.0]) {
      testWidgets('form aligned with auth screens at ${width.toInt()}px',
          (tester) async {
        await setSize(tester, width);
        await pumpReset(
          tester,
          auth: () => Stream.value(recovering),
          repository: _RecoveryAuth(),
        );
        expect(find.text('Crear nueva contraseña'), findsOneWidget);
        expect(
          find.text('Elige una contraseña para volver a ingresar a tu cuenta.'),
          findsOneWidget,
        );
        expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);
        expect(find.text('Al menos 8 caracteres'), findsOneWidget);
        expect(find.text('Guardar contraseña'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('toggle shows both fields; requirement updates live',
        (tester) async {
      await setSize(tester, 390);
      await pumpReset(
        tester,
        auth: () => Stream.value(recovering),
        repository: _RecoveryAuth(),
      );
      final fields = find.byType(TextField);
      expect(tester.widget<TextField>(fields.first).obscureText, isTrue);
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(tester.widget<TextField>(fields.first).obscureText, isFalse);
      expect(tester.widget<TextField>(fields.last).obscureText, isFalse);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      await tester.enterText(fields.first, 'clave-segura');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('mismatch validates in place without calling the backend',
        (tester) async {
      await setSize(tester, 1366);
      final repository = _RecoveryAuth();
      await pumpReset(
        tester,
        auth: () => Stream.value(recovering),
        repository: repository,
      );
      await tester.enterText(find.byType(TextField).first, 'clave-segura');
      await tester.enterText(find.byType(TextField).last, 'otra-clave');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(repository.updates, 0);
    });

    testWidgets('backend failure shows a friendly message', (tester) async {
      await setSize(tester, 1366);
      final repository = _RecoveryAuth(fail: true);
      await pumpReset(
        tester,
        auth: () => Stream.value(recovering),
        repository: repository,
      );
      await tester.enterText(find.byType(TextField).first, 'clave-segura');
      await tester.enterText(find.byType(TextField).last, 'clave-segura');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pumpAndSettle();
      expect(
          find.text('El enlace caducó. Solicita uno nuevo.'), findsOneWidget);
      expect(find.text('Contraseña actualizada'), findsNothing);
      expect(repository.signOuts, 0);
    });

    testWidgets('success keeps the existing flow and confirms on sign-in',
        (tester) async {
      await setSize(tester, 1366);
      final repository = _RecoveryAuth(signOutDelay: true);
      await pumpReset(
        tester,
        auth: () => Stream.value(recovering),
        repository: repository,
      );
      await tester.enterText(find.byType(TextField).first, 'clave-segura');
      await tester.enterText(find.byType(TextField).last, 'clave-segura');
      await tester.tap(find.text('Guardar contraseña'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Mientras corre el cierre de sesión se ve el éxito.
      expect(find.text('Contraseña actualizada'), findsOneWidget);
      expect(repository.updates, 1);
      repository.completeSignOut();
      await tester.pumpAndSettle();
      expect(repository.signOuts, 1);
      expect(find.text('Ingreso proveedor UI'), findsOneWidget);
      expect(
        find.text('Contraseña actualizada. Ingresa con tu nueva contraseña.'),
        findsOneWidget,
      );
    });

    testWidgets('expired link explains and offers a new link', (tester) async {
      await setSize(tester, 390);
      await pumpReset(
        tester,
        auth: () => Stream.value(null),
        repository: _RecoveryAuth(),
      );
      expect(find.text('El enlace caducó o ya fue utilizado.'), findsOneWidget);
      await tester.tap(find.text('Solicitar otro enlace'));
      await tester.pumpAndSettle();
      expect(find.text('Recuperar UI'), findsOneWidget);
    });

    testWidgets('session loading uses a form-shaped skeleton', (tester) async {
      await setSize(tester, 1366);
      final pending = StreamController<AuthUser?>();
      addTearDown(pending.close);
      await pumpReset(
        tester,
        auth: () => pending.stream,
        repository: _RecoveryAuth(),
      );
      expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('3.22B labels', () {
    test('blocked accounts and settings audit rows are human', () {
      expect(adminAccountStatusLabel('blocked'), 'Bloqueado');
      expect(rancoToneForStatusLabel('Bloqueado'), RancoStatusTone.danger);
      expect(adminAuditActionLabel('admin_settings_updated'),
          'Configuración actualizada');
      expect(adminAuditResourceLabel('system_settings'), 'Configuración');
    });
  });
}

/// Auth mínima para la recuperación: actualizar contraseña y cerrar sesión.
class _RecoveryAuth implements AuthRepository {
  _RecoveryAuth({this.fail = false, this.signOutDelay = false});

  final bool fail;
  final bool signOutDelay;
  int updates = 0;
  int signOuts = 0;
  final _signOut = Completer<void>();

  void completeSignOut() => _signOut.complete();

  @override
  Future<Result<void>> updateRecoveredPassword(String password) async {
    updates++;
    return fail
        ? const Failure(AppFailure(
            type: AppFailureType.auth,
            message: 'El enlace caducó. Solicita uno nuevo.',
          ))
        : const Success(null);
  }

  @override
  Future<Result<void>> signOut() async {
    if (signOutDelay) await _signOut.future;
    signOuts++;
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
