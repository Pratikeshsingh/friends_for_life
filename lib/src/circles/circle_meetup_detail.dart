import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';
import '../core/i18n.dart';
import 'circle_repository.dart';

Future<void> openCircleMeetup(BuildContext context, Json meetup) =>
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => CircleMeetupDetail(meetup: meetup)));

class CircleMeetupDetail extends StatelessWidget {
  const CircleMeetupDetail({super.key, required this.meetup});
  final Json meetup;
  @override
  Widget build(BuildContext context) {
    final location = circleVenueLabel(meetup);
    final hidden = location.startsWith('Revealed') ||
        location == 'Location to be confirmed';
    Future<void> open(Uri url) async {
      try {
        if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t('Could not open this link. Please try again.'))));
      }
    }

    final week = meetup['week'] as int?;
    final extras = {
      'meeting_point': 'Meeting point',
      'cost_notes': 'Costs',
      'accessibility_notes': 'Accessibility',
    }.entries.where((e) => '${meetup[e.key] ?? ''}'.trim().isNotEmpty);
    Widget line(IconData icon, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: const Color(0xFF138B8A)),
          const SizedBox(width: 12),
          Expanded(child: child),
        ]));
    return Scaffold(
        appBar: AppBar(title: const Text('Meetup details')),
        // A reading column, like Home and Profile, so text and buttons do
        // not stretch across a desktop screen.
        body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(week == null ? 'EXTRA PLAN' : 'WEEK $week',
                              style: const TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0D6E6D))),
                          const SizedBox(height: 6),
                          Text(circleMeetupTitle(meetup),
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          // Weeks 2–4 describe a specific activity; only show
                          // that when the plan still is that activity.
                          if (week != null &&
                              week >= 1 &&
                              week <= 6 &&
                              (week == 1 ||
                                  week >= 5 ||
                                  circleMeetupTitle(meetup) ==
                                      circleWeekTitles[week - 1])) ...[
                            const SizedBox(height: 8),
                            Text(circleWeekNotes[week - 1],
                                style: const TextStyle(
                                    color: Color(0xFF4F5D66), height: 1.45)),
                          ],
                          const SizedBox(height: 20),
                          line(
                              Icons.schedule_rounded,
                              Text(
                                  '${circleDate(meetup['date'])} · ${meetup['time']} · Netherlands time')),
                          line(
                              Icons.place_outlined,
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText(location),
                                    if (!hidden &&
                                        '${meetup['venue_address'] ?? ''}'
                                            .isNotEmpty)
                                      SelectableText(
                                          '${meetup['venue_address']}',
                                          style: const TextStyle(
                                              color: Color(0xFF4F5D66))),
                                  ])),
                          if ('${meetup['booking_name'] ?? ''}'
                              .trim()
                              .isNotEmpty)
                            line(
                                Icons.table_restaurant_outlined,
                                Text(t('Table booked under “{1}”').replaceAll(
                                    '{1}',
                                    '${meetup['booking_name']}'.trim()))),
                          for (final field in extras)
                            line(
                                switch (field.key) {
                                  'meeting_point' => Icons.flag_outlined,
                                  'cost_notes' => Icons.euro_rounded,
                                  _ => Icons.accessible_rounded,
                                },
                                Text(
                                    '${t(field.value)}: ${meetup[field.key]}')),
                          if (meetup['updated_by_name'] != null)
                            Text('Last updated by ${meetup['updated_by_name']}',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF66727C))),
                          const SizedBox(height: 20),
                          if (circleMeetupStart(meetup) != null) ...[
                            Text(
                                location == 'Location to be confirmed'
                                    ? 'The place isn’t final yet. Calendar copies don’t update, so check the app before you leave.'
                                    : 'Calendar copies don’t update, so check the app before you leave.',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF66727C))),
                            const SizedBox(height: 10),
                          ],
                          Wrap(spacing: 10, runSpacing: 10, children: [
                            if (!hidden)
                              OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48)),
                                  icon: const Icon(Icons.directions_outlined),
                                  label: const Text('Directions'),
                                  onPressed: () => open(Uri.https(
                                          'www.google.com', '/maps/search/', {
                                        'api': '1',
                                        'query':
                                            '${meetup['venue_address'] ?? location}, Alkmaar'
                                      }))),
                            if (circleMeetupStart(meetup) != null)
                              OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48)),
                                  icon: const Icon(Icons.calendar_month),
                                  label: const Text('Google Calendar'),
                                  onPressed: () =>
                                      open(circleCalendarUri(meetup))),
                            if (circleMeetupStart(meetup) != null)
                              OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48)),
                                  icon: const Icon(Icons.event_available),
                                  label: const Text(
                                      'Download calendar file (Apple/Outlook)'),
                                  onPressed: () => FilePicker.platform.saveFile(
                                      dialogTitle: t('Add to calendar'),
                                      fileName: 'vriendtime-meetup.ics',
                                      type: FileType.custom,
                                      allowedExtensions: ['ics'],
                                      bytes: Uint8List.fromList(utf8
                                          .encode(circleCalendarIcs(meetup))))),
                          ]),
                          const SizedBox(height: 8),
                          TextButton.icon(
                              icon: const Icon(Icons.chat_outlined, size: 18),
                              onPressed: () =>
                                  open(Uri.parse('https://wa.me/31685660139')),
                              label: const Text('Help & contact')),
                        ])))));
  }
}

Uri circleCalendarUri(Json meetup) {
  String stamp(DateTime date) =>
      '${date.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z';
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': 'VriendTime · ${circleMeetupTitle(meetup)}',
    'dates':
        '${stamp(circleMeetupStart(meetup)!)}/${stamp(circleMeetupEnd(meetup)!)}',
    'location': _calendarLocation(meetup),
    'ctz': 'Europe/Amsterdam',
    'details':
        '${t('Open VriendTime for the latest plan:')} ${_meetupLink(meetup)}',
  });
}

/// The place, or a plain "Alkmaar" while it is still hidden.
String _calendarLocation(Json meetup) {
  final label = circleVenueLabel(meetup);
  return label.startsWith('Revealed') || label == 'Location to be confirmed'
      ? 'Alkmaar'
      : label;
}

String _meetupLink(Json meetup) => Uri.https('vriendtime.com', '/', {
      if (meetup['id'] != null) 'open': 'meetup:${meetup['id']}',
      if (isDutch) 'lang': 'nl',
    }).toString();

/// The same meetup as an .ics file, for Apple Calendar and Outlook.
String circleCalendarIcs(Json meetup) {
  String stamp(DateTime date) =>
      '${date.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z';
  String esc(String v) => v
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');
  final start = circleMeetupStart(meetup)!, end = circleMeetupEnd(meetup)!;
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//VriendTime//Circles//EN',
    'BEGIN:VEVENT',
    'UID:${meetup['id'] ?? stamp(start)}@vriendtime.com',
    'DTSTAMP:${stamp(DateTime.now())}',
    'DTSTART:${stamp(start)}',
    'DTEND:${stamp(end)}',
    'SUMMARY:${esc('VriendTime · ${circleMeetupTitle(meetup)}')}',
    'LOCATION:${esc(_calendarLocation(meetup))}',
    'DESCRIPTION:${esc('${t('Open VriendTime for the latest plan:')} ${_meetupLink(meetup)}')}',
    'URL:${_meetupLink(meetup)}',
    'END:VEVENT',
    'END:VCALENDAR',
    '',
  ].join('\r\n');
}
