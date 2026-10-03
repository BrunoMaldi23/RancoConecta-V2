import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ranco_conecta_2/core/layout/ranco_responsive.dart';
import 'package:ranco_conecta_2/theme/ranco_tokens.dart';

void main() {
  test('canonical breakpoints match responsive web targets', () {
    expect(RancoBreakpoints.medium, 600);
    expect(RancoBreakpoints.expanded, 1024);
    expect(RancoBreakpoints.large, 1440);

    expect(RancoBreakpoints.isCompact(390), isTrue);
    expect(RancoBreakpoints.isMedium(768), isTrue);
    expect(RancoBreakpoints.isExpanded(1366), isTrue);
    expect(RancoBreakpoints.isLarge(1920), isTrue);
  });

  test('business/category grids scale from mobile to large desktop', () {
    expect(
      rancoGridColumns(360, minItemWidth: 220, spacing: 10, maxColumns: 5),
      1,
    );
    expect(
      rancoGridColumns(
        390,
        minItemWidth: 220,
        spacing: 10,
        maxColumns: 5,
        minColumns: 2,
      ),
      2,
    );
    expect(
      rancoGridColumns(1024, minItemWidth: 260, spacing: 12, maxColumns: 4),
      3,
    );
    expect(
      rancoGridColumns(1366, minItemWidth: 260, spacing: 12, maxColumns: 5),
      5,
    );
    expect(
      rancoGridColumns(1920, minItemWidth: 300, spacing: 14, maxColumns: 4),
      4,
    );
  });

  testWidgets('adaptive modal uses bottom sheet on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpAdaptiveModalHarness(tester);
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('adaptive modal uses dialog on desktop', (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpAdaptiveModalHarness(tester);
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
  });
}

Future<void> _pumpAdaptiveModalHarness(WidgetTester tester) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: FilledButton(
                onPressed: () {
                  showRancoAdaptiveModal<void>(
                    context: context,
                    builder: (_) {
                      return const Material(
                        child: SizedBox(
                          width: 280,
                          height: 160,
                          child: Center(child: Text('Modal adaptativo')),
                        ),
                      );
                    },
                  );
                },
                child: const Text('Abrir'),
              ),
            );
          },
        ),
      ),
    ),
  );
}
