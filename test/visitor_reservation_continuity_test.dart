import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/gastronomy/presentation/table_reservation_screen.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

void main() {
  testWidgets(
      'table reservation keeps the draft in the integrated contact form',
      (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(
      initialLocation: '/business/food-1/table-reservation',
      routes: [
        GoRoute(
          path: '/business/:id/table-reservation',
          builder: (_, state) => TableReservationScreen(
            businessId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/visitor/profile',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.go(state.uri.queryParameters['next']!),
              child: const Text('Volver a reserva'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(
            id: 'visitor-1',
            email: null,
            emailConfirmed: false,
            isAnonymous: true,
          ))),
      currentProfileProvider.overrideWith((ref) async => const Profile(
            id: 'visitor-1',
            fullName: 'Visitante Ranco',
            phone: null,
            avatarUrl: null,
            role: ProfileRole.customer,
            accountStatus: 'active',
          )),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seleccionar fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Hora'), '20:30');
    await tester.enterText(find.widgetWithText(TextField, 'Comensales'), '4');
    await tester.enterText(find.widgetWithText(TextField, 'Mensaje opcional'),
        'Mesa junto a la ventana.');
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path,
        '/business/food-1/table-reservation');
    expect(find.text('Tus datos de contacto'), findsOneWidget);
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();

    expect(find.text('Seleccionar fecha'), findsNothing);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Hora'))
            .controller
            ?.text,
        '20:30');
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Comensales'))
            .controller
            ?.text,
        '4');
    expect(
        tester
            .widget<TextField>(
                find.widgetWithText(TextField, 'Mensaje opcional'))
            .controller
            ?.text,
        'Mesa junto a la ventana.');
    expect(tester.takeException(), isNull);
  });
}
