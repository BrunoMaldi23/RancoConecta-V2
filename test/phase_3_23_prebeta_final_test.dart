import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/core/widgets/ranco_brand.dart';
import 'package:ranco_conecta_2/core/widgets/ranco_site_footer.dart';
import 'package:ranco_conecta_2/core/widgets/ranco_states.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_providers.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_screens.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_settings_screens.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/legal/presentation/legal_screen.dart';
import 'package:ranco_conecta_2/router/app_router.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

/// FASE 3.23: legales compactos, footer, bootstrap y estados.
void main() {
  const widths = [390.0, 430.0, 768.0, 1024.0, 1280.0, 1366.0, 1440.0, 1600.0];

  Future<void> setSize(WidgetTester tester, double width,
      [double height = 900]) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  GoRouter legalRouter({String initial = '/terminos'}) => GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('Home'))),
          GoRoute(
              path: '/terminos',
              builder: (_, __) => const LegalScreen(privacy: false)),
          GoRoute(
              path: '/politica-privacidad',
              builder: (_, __) => const LegalScreen(privacy: true)),
          GoRoute(path: '/contacto', builder: (_, __) => const ContactScreen()),
          GoRoute(
              path: '/explore',
              builder: (_, __) => const Scaffold(body: Text('Explorar'))),
        ],
      );

  Future<void> pumpLegal(WidgetTester tester, GoRouter router) async {
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  group('legal', () {
    testWidgets('desktop: compact header and content above the fold',
        (tester) async {
      await setSize(tester, 1440);
      await pumpLegal(tester, legalRouter(initial: '/politica-privacidad'));
      final title = tester.getRect(find.text('Política de privacidad').first);
      expect(title.top, lessThan(140));
      // FASE 3.24.1: sin índice lateral; las cards empiezan sin bajar.
      expect(find.text('EN ESTA PÁGINA'), findsNothing);
      expect(tester.getRect(find.text('Datos que solicitamos')).top,
          lessThan(520));
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile: one column of cards, no horizontal index',
        (tester) async {
      await setSize(tester, 390, 844);
      await pumpLegal(tester, legalRouter(initial: '/politica-privacidad'));
      final first = tester.getRect(find.text('Datos que solicitamos'));
      final second = tester.getRect(find.text('Para qué los usamos'));
      expect(second.top, greaterThan(first.bottom));
      expect(first.left, moreOrLessEquals(second.left, epsilon: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('closing legal links keep real history for Back',
        (tester) async {
      await setSize(tester, 1366);
      final router = legalRouter(initial: '/');
      await pumpLegal(tester, router);
      router.push('/terminos');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find
            .descendant(
                of: find.byKey(const ValueKey('legal-links')),
                matching: find.text('Privacidad'))
            .hitTestable(),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find
          .descendant(
              of: find.byKey(const ValueKey('legal-links')),
              matching: find.text('Privacidad'))
          .hitTestable());
      await tester.pumpAndSettle();
      expect(
          tester.widget<LegalScreen>(find.byType(LegalScreen)).privacy, isTrue);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('footer follows the content without stretching',
        (tester) async {
      await setSize(tester, 1440);
      await pumpLegal(tester, legalRouter());
      await tester.scrollUntilVisible(
        find.byType(RancoSiteFooter),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final footer = tester.getRect(find.byType(RancoSiteFooter));
      final more = tester.getRect(find.byKey(const ValueKey('legal-links')));
      // Inmediatamente después del contenido, sin zona vacía intermedia.
      expect(footer.top, greaterThanOrEqualTo(more.bottom));
      expect(footer.top - more.bottom, lessThan(48));
      // Altura controlada (compacto, sin franja gigante).
      expect(footer.height, lessThan(260));
    });

    for (final width in widths) {
      for (final (name, route) in const [
        ('terms', '/terminos'),
        ('privacy', '/politica-privacidad'),
        ('contact', '/contacto'),
      ]) {
        testWidgets('$name has no layout errors at ${width.toInt()}px',
            (tester) async {
          await setSize(tester, width);
          await pumpLegal(tester, legalRouter(initial: route));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('bootstrap', () {
    Future<ProviderContainer> pumpBootstrap(
        WidgetTester tester, Stream<AuthUser?> auth) async {
      final container = ProviderContainer(overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: null,
          supabasePublishableKey: null,
        )),
        authStateProvider.overrideWith((ref) => auth),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BootstrapScreen()),
      ));
      await tester.pump();
      return container;
    }

    testWidgets('clean loading: brand, short copy, no page spinner',
        (tester) async {
      final pending = StreamController<AuthUser?>();
      addTearDown(pending.close);
      await pumpBootstrap(tester, pending.stream);
      expect(find.byType(RancoBrandMark), findsOneWidget);
      expect(find.text('Preparando tu cuenta…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // El indicador aparece con fundido (sin destello inmediato).
      final opacity = tester.widget<Opacity>(find
          .ancestor(
            of: find.byType(LinearProgressIndicator),
            matching: find.byType(Opacity),
          )
          .first);
      expect(opacity.opacity, lessThan(.1));
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        tester
            .widget<Opacity>(find
                .ancestor(
                  of: find.byType(LinearProgressIndicator),
                  matching: find.byType(Opacity),
                )
                .first)
            .opacity,
        1,
      );
    });

    testWidgets('error keeps a calm message without the loader',
        (tester) async {
      await pumpBootstrap(tester, Stream.error(StateError('auth')));
      await tester.pump();
      expect(find.text('No pudimos preparar tu sesión.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
    });
  });

  group('admin states', () {
    testWidgets('admin gate loads with a skeleton, not a spinner',
        (tester) async {
      await setSize(tester, 1440);
      final pending = Completer<ProfileRole?>();
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const AdminAuditScreen()),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentAdminRoleProvider.overrideWith((ref) => pending.future),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump();
      expect(find.byType(RancoLoadingState), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('statistics stay within a readable width at 1600px',
        (tester) async {
      await setSize(tester, 1600);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const AdminAnalyticsScreen()),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentAdminRoleProvider
              .overrideWith((ref) async => ProfileRole.superAdmin),
          adminAnalyticsSummaryProvider.overrideWith((ref) async => const {}),
          adminReviewStatsProvider.overrideWith((ref) async => const {}),
          adminUsersProvider.overrideWith(
              (ref, query) async => throw StateError('sin datos')),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      final row = tester.getRect(find.text('Clics en teléfono'));
      final metric = tester.getRect(find
          .ancestor(
              of: find.text('Clics en teléfono'),
              matching: find.byType(Container))
          .last);
      expect(metric.width, lessThanOrEqualTo(981));
      expect(row.left, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  });
}
