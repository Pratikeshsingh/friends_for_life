import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/circles/circle_preferences.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';

void main() {
  test('each part of the day is a window', () {
    expect(circleSlotHours('morning'), '10:30–12:00');
    expect(circleSlotHours('afternoon'), '14:00–16:00');
    expect(circleSlotHours('evening'), '19:00–22:00');
    expect(
        circleSlotChips({
          'tue': {'morning'},
          'sat': {'afternoon', 'evening'}
        }),
        ['Tue 10:30–12:00', 'Sat 14:00–16:00', 'Sat 19:00–22:00']);
  });

  test('a meetup shows its start and end in Netherlands time', () {
    // 22:00 in Alkmaar is 20:00 UTC in summer and 21:00 UTC in winter.
    expect(
        circleMeetupHours(
            {'time': '19:00', 'ends_at': '2026-07-01T20:00:00+00:00'}),
        '19:00–22:00');
    expect(
        circleMeetupHours(
            {'time': '19:00', 'ends_at': '2026-12-02T21:00:00+00:00'}),
        '19:00–22:00');
    // Without an end, the end of its part of the day.
    expect(circleMeetupHours({'time': '10:30'}), '10:30–12:00');
    expect(circleMeetupHours({'time': '14:00'}), '14:00–16:00');
    expect(circleMeetupHours({'time': '19:30'}), '19:30–22:00');
  });

  test('summer time switches on the last Sundays of March and October', () {
    // 25 October 2026: clocks go back at 01:00 UTC.
    expect(circleAmsterdam(DateTime.utc(2026, 10, 25, 0, 30)).hour, 2);
    expect(circleAmsterdam(DateTime.utc(2026, 10, 25, 1, 30)).hour, 2);
    // 29 March 2026: clocks go forward at 01:00 UTC.
    expect(circleAmsterdam(DateTime.utc(2026, 3, 29, 0, 30)).hour, 1);
    expect(circleAmsterdam(DateTime.utc(2026, 3, 29, 1, 30)).hour, 3);
  });
}
