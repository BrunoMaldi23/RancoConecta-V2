import 'bootstrap/bootstrap.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  const dsn = String.fromEnvironment('SENTRY_DSN');
  const environment = String.fromEnvironment('APP_ENVIRONMENT');
  const release = String.fromEnvironment('SENTRY_RELEASE');
  if (environment != 'production' || dsn.isEmpty) {
    await bootstrap();
    return;
  }
  await SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.environment = environment;
      if (release.isNotEmpty) options.release = release;
      options.sendDefaultPii = false;
      options.tracesSampleRate = 0;
    },
    appRunner: bootstrap,
  );
}
