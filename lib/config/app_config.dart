import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment parse(String value) {
    return AppEnvironment.values.firstWhere(
      (environment) => environment.name == value,
      orElse: () => AppEnvironment.development,
    );
  }
}

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory AppConfig.fromEnvironment() {
    const environment = String.fromEnvironment(
      'APP_ENVIRONMENT',
      defaultValue: 'development',
    );
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabasePublishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    );

    return AppConfig(
      environment: AppEnvironment.parse(environment),
      supabaseUrl: supabaseUrl.isEmpty ? null : supabaseUrl,
      supabasePublishableKey:
          supabasePublishableKey.isEmpty ? null : supabasePublishableKey,
    );
  }

  final AppEnvironment environment;
  final String? supabaseUrl;
  final String? supabasePublishableKey;

  bool get hasSupabaseConfig =>
      supabaseUrl != null && supabasePublishableKey != null;
}

final appConfigProvider =
    Provider<AppConfig>((ref) => AppConfig.fromEnvironment());
