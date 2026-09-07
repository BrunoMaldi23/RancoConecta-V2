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
    required this.supabaseAnonKey,
  });

  factory AppConfig.fromEnvironment() {
    const environment = String.fromEnvironment(
      'APP_ENVIRONMENT',
      defaultValue: 'development',
    );
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    return AppConfig(
      environment: AppEnvironment.parse(environment),
      supabaseUrl: supabaseUrl.isEmpty ? null : supabaseUrl,
      supabaseAnonKey: supabaseAnonKey.isEmpty ? null : supabaseAnonKey,
    );
  }

  final AppEnvironment environment;
  final String? supabaseUrl;
  final String? supabaseAnonKey;

  bool get hasSupabaseConfig => supabaseUrl != null && supabaseAnonKey != null;
}

final appConfigProvider =
    Provider<AppConfig>((ref) => AppConfig.fromEnvironment());
