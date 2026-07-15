import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'event_catalog.dart';

Future<bool> addMeetupToCalendar(MeetupEvent event) async {
  final url = buildGoogleCalendarUri(event);

  return launchUrl(
    url,
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
  );
}

Uri buildGoogleCalendarUri(MeetupEvent event) {
  final start = _formatCalendarDate(event.startsAt.toUtc());
  final end = _formatCalendarDate(event.endsAt.toUtc());

  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': 'VriendTime · ${event.title}',
    'dates': '$start/$end',
    'details': buildMeetupCalendarDescription(event),
    'location': event.hasExactAddress
        ? event.locationDetailLabel
        : '${event.areaLabel}, ${event.city}',
  });
}

String buildMeetupCalendarDescription(MeetupEvent event) {
  final sections = <String>[
    'Hosted by VriendTime',
    event.subtitle.trim(),
  ];

  if (event.hasExactAddress) {
    sections.add('Venue: ${event.locationDetailLabel}');
  } else {
    sections.add(
      'Area: ${event.areaLabel}, ${event.city}\n${event.addressReleaseSentence}',
    );
  }

  sections.add('Phone-free, so conversation comes easier.');
  return sections.where((section) => section.isNotEmpty).join('\n\n');
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
