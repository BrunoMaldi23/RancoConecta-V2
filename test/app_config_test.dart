import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/config/app_config.dart';

void main() {
  test('detects missing Supabase configuration', () {
    const config = AppConfig(
      environment: AppEnvironment.development,
      supabaseUrl: null,
      supabasePublishableKey: null,
    );

    expect(config.hasSupabaseConfig, isFalse);
  });

  test('detects complete Supabase publishable-key configuration', () {
    const config = AppConfig(
      environment: AppEnvironment.staging,
      supabaseUrl: 'https://example.supabase.co',
      supabasePublishableKey: 'sb_publishable_fake',
    );

    expect(config.hasSupabaseConfig, isTrue);
  });
}
