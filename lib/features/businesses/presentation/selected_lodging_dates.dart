import 'package:flutter/material.dart';

/// Converts selected nights into the existing check-in/check-out contract.
/// Each gap creates a separate request, so unselected nights stay unbooked.
List<DateTimeRange> groupSelectedNights(Iterable<DateTime> selectedDates) {
  final dates = selectedDates
      .map((day) => DateTime(day.year, day.month, day.day))
      .toSet()
      .toList()
    ..sort();
  if (dates.isEmpty) return [];
  final groups = <DateTimeRange>[];
  var start = dates.first;
  var last = start;
  for (final day in dates.skip(1)) {
    if (day.difference(last).inDays != 1) {
      groups.add(
          DateTimeRange(start: start, end: last.add(const Duration(days: 1))));
      start = day;
    }
    last = day;
  }
  groups
      .add(DateTimeRange(start: start, end: last.add(const Duration(days: 1))));
  return groups;
}
