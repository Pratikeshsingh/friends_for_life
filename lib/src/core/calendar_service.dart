import 'package:url_launcher/url_launcher.dart';

import 'event_catalog.dart';

Future<bool> addMeetupToCalendar(MeetupEvent event) async {
  final start = _formatCalendarDate(event.startsAt.toUtc());
  final end = _formatCalendarDate(event.endsAt.toUtc());
  final details =
      'VriendTime meetup. You see the area now. The exact address is shared 24 hours before the meetup. ${event.subtitle}';

  final url = Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': event.title,
    'dates': '$start/$end',
    'details': details,
    'location': '${event.areaLabel}, ${event.city}',
  });

  return launchUrl(url, mode: LaunchMode.platformDefault);
}

String _formatCalendarDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return [year, month, day, 'T', hour, minute, second, 'Z'].join();
}
