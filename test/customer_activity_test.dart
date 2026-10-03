import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/service_requests/application/service_request_providers.dart';
import 'package:ranco_conecta_2/features/service_requests/data/customer_activity_repository.dart';
import 'package:ranco_conecta_2/features/service_requests/domain/customer_activity_item.dart';
import 'package:ranco_conecta_2/features/service_requests/presentation/requests_screen.dart';

const _userA = AuthUser(
  id: 'user-a',
  email: 'a@example.test',
  emailConfirmed: true,
  isAnonymous: false,
);
const _userB = AuthUser(
  id: 'user-b',
  email: 'b@example.test',
  emailConfirmed: true,
  isAnonymous: false,
);

CustomerActivityItem _item(String id, CustomerActivityType type,
        {CustomerActivityStage stage = CustomerActivityStage.pending}) =>
    CustomerActivityItem(
      id: id,
      businessId: 'business-$id',
      businessName: 'Negocio $id',
      type: type,
      createdAt: DateTime.utc(2026, 10, 3),
      stage: stage,
      statusLabel:
          stage == CustomerActivityStage.accepted ? 'Aceptada' : 'Pendiente',
      summary: switch (type) {
        CustomerActivityType.service => 'Servicio',
        CustomerActivityType.lodging => 'Alojamiento',
        CustomerActivityType.gastronomy => 'Reserva de mesa',
        CustomerActivityType.tourism => 'Turismo',
      },
      detailRoute: type == CustomerActivityType.service
          ? '/requests/$id'
          : '/business/business-$id',
    );

class _ActivityRepository extends CustomerActivityRepository {
  _ActivityRepository() : super(null);

  final calls = <String>[];
  final values = <String, List<CustomerActivityItem>>{};

  @override
  Future<List<CustomerActivityItem>> listMine(String userId) async {
    calls.add(userId);
    return values[userId] ?? const [];
  }
}

void main() {
  test('activity provider changes requester and refreshes after invalidation',
      () async {
    final auth = StreamController<AuthUser?>.broadcast();
    final repository = _ActivityRepository()
      ..values['user-a'] = [_item('a', CustomerActivityType.lodging)]
      ..values['user-b'] = [_item('b', CustomerActivityType.gastronomy)];
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => auth.stream),
      customerActivityRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(() async {
      container.dispose();
      await auth.close();
    });
    final subscription =
        container.listen(myCustomerActivityProvider, (_, __) {});
    addTearDown(subscription.close);

    auth.add(_userA);
    expect((await container.read(myCustomerActivityProvider.future)).single.id,
        'a');
    repository.values['user-a'] = [
      _item('a', CustomerActivityType.lodging),
      _item('new', CustomerActivityType.service),
    ];
    container.invalidate(myCustomerActivityProvider);
    expect((await container.read(myCustomerActivityProvider.future)).length, 2);

    auth.add(_userB);
    await container.read(authStateProvider.future);
    expect((await container.read(myCustomerActivityProvider.future)).single.id,
        'b');
    expect(repository.calls, ['user-a', 'user-a', 'user-b']);
  });

  testWidgets('requests includes service, lodging, and gastronomy activity',
      (tester) async {
    final router = GoRouter(initialLocation: '/requests', routes: [
      GoRoute(path: '/requests', builder: (_, __) => const RequestsScreen()),
      GoRoute(
          path: '/requests/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Solicitud ${state.pathParameters['id']}'))),
      GoRoute(
          path: '/business/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Negocio ${state.pathParameters['id']}'))),
      GoRoute(
          path: '/explore',
          builder: (_, __) => const Scaffold(body: Text('Explorar'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_userA)),
        myCustomerActivityProvider.overrideWith((ref) async => [
              _item('service', CustomerActivityType.service),
              _item('lodging', CustomerActivityType.lodging),
              _item('table', CustomerActivityType.gastronomy),
            ]),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(
        find.text('3 solicitudes registradas en tu cuenta.'), findsOneWidget);
    expect(find.text('Negocio service'), findsOneWidget);
    expect(find.text('Negocio lodging'), findsOneWidget);
    expect(find.text('Negocio table'), findsOneWidget);
    expect(find.text('Aún no tienes solicitudes'), findsNothing);

    await tester.tap(find.text('Negocio lodging'));
    await tester.pumpAndSettle();
    expect(find.text('Negocio business-lodging'), findsOneWidget);
  });

  test('vertical statuses map without changing backend values', () {
    expect(CustomerActivityItem.lodgingStage('accepted'),
        CustomerActivityStage.accepted);
    expect(CustomerActivityItem.gastronomyStage('confirmed'),
        CustomerActivityStage.accepted);
    expect(CustomerActivityItem.gastronomyStage('rejected'),
        CustomerActivityStage.rejected);
    expect(CustomerActivityItem.lodgingStage('cancelled'),
        CustomerActivityStage.cancelled);
  });
}
