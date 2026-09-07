import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void warn(String message) {
    debugPrint('[RancoConecta][WARN] $message');
  }
}
