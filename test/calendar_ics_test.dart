import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/circles/circle_meetup_detail.dart';

void main() {
  test('the .ics file is valid and links back to the meetup', () {
    final ics = circleCalendarIcs({
      'id': 'abc',
      'week': 1,
      'title': 'Dinner, together',
      'date': '2026-10-15',
      'time': '19:00',
      'venue': 'Café de Ster',
    });
    expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(ics, contains('DTSTART:20261015T170000Z'));
    expect(ics, contains('SUMMARY:VriendTime · Dinner\\, together'));
    expect(ics, contains('URL:https://vriendtime.com/?open=meetup%3Aabc'));
    expect(ics, contains('END:VCALENDAR'));
  });
}
