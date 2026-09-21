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
    this.featureFlags = const FeatureFlags(),
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
      featureFlags: FeatureFlags.fromEnvironment(),
    );
  }

  final AppEnvironment environment;
  final String? supabaseUrl;
  final String? supabasePublishableKey;
  final FeatureFlags featureFlags;

  bool get hasSupabaseConfig =>
      supabaseUrl != null && supabasePublishableKey != null;
}

class FeatureFlags {
  const FeatureFlags({
    this.chatEnabled = false,
    this.paymentsEnabled = false,
    this.quotesEnabled = false,
    this.lodgingEnabled = true,
  });

  factory FeatureFlags.fromEnvironment() {
    const chatEnabled = bool.fromEnvironment('CHAT_ENABLED');
    const paymentsEnabled = bool.fromEnvironment('PAYMENTS_ENABLED');
    const quotesEnabled = bool.fromEnvironment('QUOTES_ENABLED');
    const lodgingEnabled = bool.fromEnvironment(
      'LODGING_ENABLED',
      defaultValue: true,
    );

    return const FeatureFlags(
      chatEnabled: chatEnabled,
      paymentsEnabled: paymentsEnabled,
      quotesEnabled: quotesEnabled,
      lodgingEnabled: lodgingEnabled,
    );
  }

  final bool chatEnabled;
  final bool paymentsEnabled;
  final bool quotesEnabled;
  final bool lodgingEnabled;
}

final appConfigProvider =
    Provider<AppConfig>((ref) => AppConfig.fromEnvironment());
