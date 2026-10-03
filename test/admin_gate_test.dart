import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_providers.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_screens.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

void main() {
  for (final role in [ProfileRole.admin, ProfileRole.superAdmin]) {
    testWidgets('$role opens admin content', (tester) async {
      await _pumpGate(tester, role);
      expect(find.text('Contenido administrativo'), findsOneWidget);
      expect(find.text('No tienes acceso administrativo.'), findsNothing);
    });
  }

  for (final role in [ProfileRole.provider, null]) {
    testWidgets('$role cannot open admin content', (tester) async {
      await _pumpGate(tester, role);
      expect(find.text('Contenido administrativo'), findsNothing);
      expect(find.text('No tienes acceso administrativo.'), findsOneWidget);
    });
  }
}

Future<void> _pumpGate(WidgetTester tester, ProfileRole? role) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [currentAdminRoleProvider.overrideWith((ref) async => role)],
    child: const MaterialApp(
      home: AdminGate(child: Scaffold(body: Text('Contenido administrativo'))),
    ),
  ));
  await tester.pumpAndSettle();
}
