import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_providers.dart';
import 'package:ranco_conecta_2/features/admin/data/admin_business_review_repository.dart';
import 'package:ranco_conecta_2/features/admin/data/admin_settings_repository.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_screens.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_settings_screens.dart';
import 'package:ranco_conecta_2/features/categories/application/category_providers.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';

void main() {
  for (final width in [1366.0, 1024.0, 768.0, 390.0]) {
    testWidgets(
        'admin dashboard fits at ${width.toInt()}px through bottom panels',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(initialLocation: '/admin', routes: [
        ShellRoute(
          builder: (context, state, child) => AdminWorkspaceShell(
            path: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(
                path: '/admin',
                builder: (_, __) => const AdminDashboardScreen())
          ],
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentAdminRoleProvider
              .overrideWith((ref) async => ProfileRole.admin),
          adminReviewStatsProvider.overrideWith((ref) async => {
                'pending_review': 2,
                'changes_requested': 0,
                'published': 6,
                'rejected': 0,
              }),
          adminUsersProvider.overrideWith(
              (ref, query) async => const AdminUsersPage(rows: [], total: 10)),
          adminBusinessReviewPageProvider.overrideWith((ref, query) async =>
              const AdminBusinessReviewPage(items: [], totalCount: 0)),
          adminAnalyticsSummaryProvider.overrideWith((ref) async => {}),
          adminWhatsAppSettingsProvider
              .overrideWith((ref) async => const AdminWhatsAppSettings(
                    number: '',
                    enabled: false,
                    newBusiness: false,
                    businessChanges: false,
                    userReports: false,
                  )),
          categoriesProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Panel administrativo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 390) {
        expect(find.text('Revisiones pendientes'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Publicados'),
          300,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          tester.getTopLeft(find.text('Revisiones pendientes')).dy,
          lessThan(tester.getTopLeft(find.text('Publicados')).dy),
        );
      }

      await tester.scrollUntilVisible(
        find.text('Estado de la plataforma'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Estado de la plataforma'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('admin modules share navigation and back returns to dashboard',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(initialLocation: '/admin', routes: [
      ShellRoute(
        builder: (context, state, child) => AdminWorkspaceShell(
          path: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
              path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
          GoRoute(
              path: '/admin/categories',
              builder: (_, __) => const AdminCategoriesScreen()),
        ],
      ),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAdminRoleProvider.overrideWith((ref) async => ProfileRole.admin),
        adminReviewStatsProvider.overrideWith((ref) async => {
              'pending_review': 2,
              'changes_requested': 0,
              'published': 3,
              'rejected': 1,
            }),
        adminUsersProvider.overrideWith(
            (ref, query) async => const AdminUsersPage(rows: [], total: 9)),
        adminBusinessReviewPageProvider
            .overrideWith((ref, query) async => AdminBusinessReviewPage(items: [
                  AdminBusinessReviewSummary(
                    id: 'business-1',
                    name: 'Taller Ranco',
                    businessType: BusinessType.service,
                    publicationStatus: BusinessPublicationStatus.pendingReview,
                    verificationStatus: 'unverified',
                    categoryName: 'Mecánica',
                    ownerName: 'Vecino Ranco',
                    ownerEmail: 'vecino@example.com',
                    submittedAt: DateTime(2026, 9, 30),
                    createdAt: DateTime(2026, 9, 29),
                    totalCount: 1,
                  ),
                ], totalCount: 1)),
        adminAnalyticsSummaryProvider.overrideWith((ref) async => {
              'PROFILE_VIEW': 4,
              'CLICK_WHATSAPP': 2,
            }),
        adminWhatsAppSettingsProvider
            .overrideWith((ref) async => const AdminWhatsAppSettings(
                  number: '56912345678',
                  enabled: true,
                  newBusiness: true,
                  businessChanges: false,
                  userReports: false,
                )),
        categoriesProvider.overrideWith((ref) async => []),
        adminCategoriesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Panel administrativo'), findsOneWidget);
    expect(find.text('Publicados'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Taller Ranco'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Taller Ranco'), findsOneWidget);

    router.push('/admin/categories');
    await tester.pumpAndSettle();
    expect(find.text('0 categorías'), findsOneWidget);

    // En móvil (sin sidebar) se mantiene el retorno explícito al panel.
    await tester.tap(find.text('Volver al panel'));
    await tester.pumpAndSettle();
    expect(find.text('Panel administrativo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
