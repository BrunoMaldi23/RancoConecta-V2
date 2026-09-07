import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/config/app_config.dart';

void main() {
  test('detects missing Supabase configuration', () {
    const config = AppConfig(
      environment: AppEnvironment.development,
      supabaseUrl: null,
      supabaseAnonKey: null,
    );

    expect(config.hasSupabaseConfig, isFalse);
  });
}
