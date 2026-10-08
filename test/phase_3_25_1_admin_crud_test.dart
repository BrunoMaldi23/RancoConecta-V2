import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_settings_screens.dart';

void main() {
  final actions = AdminUserActions(
    onChangeRole: (_) async {},
    onToggleSuspension: (_) async {},
    onDelete: (_) async {},
  );

  test('client guards self deletion, legacy roles and deleted accounts', () {
    expect(
        adminDeletionBlockedReason({'id': 'self', 'role': 'admin'}, actions,
            selfId: 'self'),
        isNotNull);
    expect(
        adminDeletionBlockedReason(
            {'id': 'other', 'role': 'super_admin'}, actions,
            selfId: 'self'),
        isNotNull);
    expect(
        adminDeletionBlockedReason({
          'id': 'other',
          'role': 'customer',
          'account_status': 'deleted'
        }, actions, selfId: 'self'),
        isNotNull);
    expect(
        adminDeletionBlockedReason({'id': 'other', 'role': 'customer'}, actions,
            selfId: 'self'),
        isNotNull);
    expect(
        adminSuspensionBlockedReason({'id': 'self', 'role': 'admin'}, actions,
            selfId: 'self'),
        isNotNull);
    expect(adminRoleChangeBlockedReason({'role': 'super_admin'}, actions),
        isNotNull);
  });

  testWidgets('delete requires confirmation and invokes mutation once',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showDeleteUserDialog(
            context, {'id': 'other', 'full_name': 'Vecina Ranco'},
            onDelete: (_) async {
          calls++;
        }),
        child: const Text('Abrir'),
      ),
    ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.textContaining('registros relacionados', findRichText: true),
        findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar usuario').last);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('admin invitation validates and calls server callback',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
        onPressed: () =>
            showCreateAdminDialog(context, onCreate: (name, email) async {
          expect(name, 'Ana Pérez');
          expect(email, 'ana@example.com');
          calls++;
        }),
        child: const Text('Abrir'),
      ),
    ))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear administrador').last);
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.enterText(
        find.widgetWithText(TextField, 'Nombre'), 'Ana Pérez');
    await tester.enterText(
        find.widgetWithText(TextField, 'Correo'), 'ana@example.com');
    await tester.tap(find.text('Crear administrador').last);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
