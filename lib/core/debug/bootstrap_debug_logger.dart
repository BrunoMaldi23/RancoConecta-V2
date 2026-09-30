import 'package:flutter/foundation.dart';

void logBootstrapEvent(
  String event, [
  Map<String, Object?> details = const {},
]) {
  if (!kDebugMode) {
    return;
  }

  final suffix = details.entries
      .where((entry) => entry.value != null)
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' ');

  debugPrint(suffix.isEmpty ? event : '$event $suffix');
}
