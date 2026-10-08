import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_providers.dart';
import 'package:ranco_conecta_2/features/admin/data/admin_settings_repository.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_settings_screens.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

class _SettingsRepository extends AdminSettingsRepository {
  _SettingsRepository() : super(null);

  String email = '';
  String whatsapp = '';
  final notices = <String, bool>{
    'notify_new_business': true,
    'notify_business_changes': true,
    'notify_contact_message': true,
  };

  @override
  Future<Map<String, String>> getContactChannels() async =>
      {'email': email, 'whatsapp': whatsapp};

  @override
  Future<void> saveContactChannels(String email, String whatsapp) async {
    this.email = email;
    this.whatsapp = whatsapp;
  }

  @override
  Future<Map<String, bool>> getNotificationSettings() async => notices;

  @override
  Future<void> saveNotificationSettings(Map<String, bool> values) async {
    notices.addAll(values);
  }
}

void main() {
  Future<void> pumpSettings(
      WidgetTester tester, _SettingsRepository repo) async {
    tester.view.physicalSize = const Size(1440, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(routes: [
      GoRoute(
          path: '/', builder: (_, __) => const AdminWhatsAppSettingsScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      appConfigProvider.overrideWithValue(const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabasePublishableKey: null,
      )),
      currentAdminRoleProvider
          .overrideWith((ref) async => ProfileRole.superAdmin),
      currentProfileProvider.overrideWith((ref) async => const Profile(
            id: 'admin-1',
            fullName: 'Admin',
            phone: null,
            avatarUrl: null,
            role: ProfileRole.superAdmin,
            accountStatus: 'active',
          )),
      adminSettingsRepositoryProvider.overrideWithValue(repo),
      adminWhatsAppSettingsProvider
          .overrideWith((ref) async => const AdminWhatsAppSettings(
                number: '',
                enabled: false,
                newBusiness: true,
                businessChanges: true,
                userReports: true,
              )),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
  }

  testWidgets('public contact channels load and save', (tester) async {
    final repo = _SettingsRepository();
    await pumpSettings(tester, repo);
    await tester.tap(find.text('General').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Correo de contacto'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'SOPORTE@example.com');
    await tester.enterText(fields.at(1), '+56912345678');
    await tester.tap(find.text('Guardar').last);
    await tester.pumpAndSettle();
    expect(repo.email, 'SOPORTE@example.com');
    expect(repo.whatsapp, '+56912345678');
    expect(find.text('SOPORTE@example.com'), findsOneWidget);
  });

  testWidgets(
      'real notification preferences save, unsupported events stay disabled',
      (tester) async {
    final repo = _SettingsRepository();
    await pumpSettings(tester, repo);
    await tester.tap(find.text('Notificaciones').first);
    await tester.pumpAndSettle();
    final active =
        find.widgetWithText(SwitchListTile, 'Nuevo negocio pendiente');
    await tester.tap(active);
    await tester.pumpAndSettle();
    expect(repo.notices['notify_new_business'], isFalse);
    final unsupported = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Negocio reportado'));
    expect(unsupported.onChanged, isNull);
  });
}
