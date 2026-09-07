import '../../../shared/models/business.dart';

bool isOpenNow(List<BusinessHour> hours, DateTime now) {
  final day = now.weekday;
  final today = hours.where((hour) => hour.dayOfWeek == day).firstOrNull;
  if (today == null ||
      today.isClosed ||
      today.openTime == null ||
      today.closeTime == null) {
    return false;
  }
  final open = _parseTime(today.openTime!);
  final close = _parseTime(today.closeTime!);
  final current = Duration(hours: now.hour, minutes: now.minute);
  return current >= open && current <= close;
}

Duration _parseTime(String value) {
  final parts = value.split(':');
  return Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]));
}
