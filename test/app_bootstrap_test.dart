import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ranco_conecta_2/app/ranco_app.dart';
import 'package:ranco_conecta_2/config/app_config.dart';

void main() {
  testWidgets(
    'renders app in development mode without Supabase config',
    (tester) async {
      await tester.binding.setSurfaceSize(
        const Size(390, 844),
      );

      addTearDown(
        () => tester.binding.setSurfaceSize(null),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                environment: AppEnvironment.development,
                supabaseUrl: null,
                supabasePublishableKey: null,
              ),
            ),
          ],
          child: const RancoApp(),
        ),
      );

      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 300),
      );

      expect(
        find.byType(MaterialApp),
        findsOneWidget,
      );

      expect(
        tester.takeException(),
        isNull,
      );
    },
  );
}
