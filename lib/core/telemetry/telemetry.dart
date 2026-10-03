import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Sends only named, anonymous product events. Never attach contact details.
class Telemetry {
  Telemetry._();

  static const _projectToken = String.fromEnvironment('POSTHOG_PROJECT_TOKEN');
  static const _legacyToken = String.fromEnvironment('POSTHOG_KEY');
  static const _token = _projectToken == '' ? _legacyToken : _projectToken;
  static const _host = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );
  static final _sessionId = _newSessionId();

  static void capture(String event) {
    if (_token.isEmpty) return;
    final uri = Uri.tryParse(_host);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
    unawaited(_send(uri.resolve('/i/v0/e/'), event));
  }

  static Future<void> _send(Uri endpoint, String event) async {
    try {
      await http
          .post(endpoint,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                'api_key': _token,
                'distinct_id': _sessionId,
                'event': event,
                'properties': {'\$process_person_profile': false},
              }))
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Analytics must never interrupt an action.
    }
  }

  static String _newSessionId() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
