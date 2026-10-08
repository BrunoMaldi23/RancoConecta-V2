import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/ranco_app.dart';
import '../config/app_config.dart';
import '../core/logging/app_logger.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  if (config.hasSupabaseConfig) {
    await Supabase.initialize(
      url: config.supabaseUrl!,
      publishableKey: config.supabasePublishableKey!,
    );
  } else if (const String.fromEnvironment('APP_ENVIRONMENT') != 'production') {
    AppLogger.warn(
        'Supabase is not configured. Running in local development mode.');
  } else {
    throw StateError('Production Supabase configuration is missing.');
  }

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const RancoApp(),
    ),
  );
}
