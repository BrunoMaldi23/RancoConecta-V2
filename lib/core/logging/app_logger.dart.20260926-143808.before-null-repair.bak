import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void warn(String message) {
    debugPrint('[RancoConecta][WARN] $message');
  }

  static void dataQueryFailure({
    required String feature,
    required String endpoint,
    required Object error,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '[RancoConecta][DATA] feature=$feature endpoint=$endpoint '
      '${_describeError(error)}',
    );
  }

  static String _describeError(Object error) {
    final type = error.runtimeType;
    final code = _readProperty(error, 'code');
    final message = _readProperty(error, 'message') ?? error.toString();

    return 'type=$type code=${code ?? 'n/a'} message=$message';
  }

  static Object? _readProperty(Object error, String property) {
    try {
      final dynamic value = error;
      switch (property) {
        case 'code':
          return value.code;
        case 'message':
          return value.message;
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
