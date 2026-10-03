import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/core/widgets/ranco_error_state.dart';

void main() {
  testWidgets('a loading failure keeps its actual message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: RancoErrorState(message: 'No se pudo cargar tu cuenta.'),
      ),
    ));

    expect(find.text('No se pudo cargar tu cuenta.'), findsOneWidget);
    expect(find.textContaining('conectar'), findsNothing);
  });
}
