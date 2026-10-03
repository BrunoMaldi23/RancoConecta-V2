import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/features/businesses/presentation/selected_lodging_dates.dart';

void main() {
  test('manual nights keep gaps outside every booking', () {
    final groups = groupSelectedNights([
      DateTime(2026, 10, 5),
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 3),
    ]);

    expect(groups.length, 3);
    expect(groups.map((group) => group.start.day), [1, 3, 5]);
    expect(groups.map((group) => group.end.day), [2, 4, 6]);
  });

  test('adjacent nights share a request and duplicate dates are ignored', () {
    final groups = groupSelectedNights([
      DateTime(2026, 10, 2),
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 5),
    ]);

    expect(groups.length, 2);
    expect(groups.first.start, DateTime(2026, 10, 1));
    expect(groups.first.end, DateTime(2026, 10, 3));
    expect(groups.last.end, DateTime(2026, 10, 6));
  });
}
