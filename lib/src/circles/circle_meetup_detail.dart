import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';
import '../core/i18n.dart';
import '../core/supabase_config.dart';
import 'circle_repository.dart';
import 'circle_widgets.dart';

/// [onPlan] opens the week 5 plan: reminders bring members here, so the
/// button has to be here too.
Future<void> openCircleMeetup(BuildContext context, Json meetup,
        {VoidCallback? onPlan}) =>
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) =>
                CircleMeetupDetail(meetup: meetup, onPlan: onPlan)));

class CircleMeetupDetail extends StatelessWidget {
  const CircleMeetupDetail({super.key, required this.meetup, this.onPlan});
  final Json meetup;
  final VoidCallback? onPlan;
  @override
  Widget build(BuildContext context) {
    final location = circleVenueLabel(meetup);
    final hidden = location.startsWith('Revealed') ||
        location == 'Location to be confirmed' ||
        location == 'Your group picks the place';
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
    final toPlan = circleWeekOpen(meetup);
    // The plan's cost line may already say it's included.
    final includedSaid =
        '${meetup['cost_notes'] ?? ''}'.toLowerCase().contains('included');
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
    final directions = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${meetup['venue_address'] ?? location}, Alkmaar'
    });
    // On a wide screen the back button and title sit in the reading column,
    // aligned with the content, instead of at the far left.
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
        appBar: wide ? null : AppBar(title: const Text('Meetup details')),
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
                          if (wide)
                            SafeArea(
                                bottom: false,
                                child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 16, bottom: 20),
                                    child: Row(children: [
                                      const BackButton(),
                                      const SizedBox(width: 8),
                                      Text('Meetup details',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                    ]))),
                          Row(children: [
                            CircleMeetupTile(meetup, size: 60),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      week == null
                                          ? 'EXTRA PLAN'
                                          : 'WEEK $week',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          letterSpacing: 1.4,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0D6E6D))),
                                  const SizedBox(height: 4),
                                  Text(circleMeetupTitle(meetup),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall),
                                ])),
                          ]),
                          const SizedBox(height: 20),
                          // The facts together, in one calm card.
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .9),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: const Color(0xFFDDE7E3))),
                              child: DefaultTextStyle.merge(
                                  style: const TextStyle(
                                      color: circleNavy, height: 1.4),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        line(
                                            Icons.schedule_rounded,
                                            Text(toPlan
                                                ? circleMeetupWhen(meetup)
                                                : '${circleMeetupWhen(meetup)} · Netherlands time')),
                                        if (meetup['included'] == true &&
                                            !includedSaid)
                                          line(
                                              Icons.redeem_outlined,
                                              const Text(
                                                  'Included in your fee')),
                                        line(
                                            Icons.place_outlined,
                                            Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  SelectableText(t(location),
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                  if (!hidden &&
                                                      '${meetup['venue_address'] ?? ''}'
                                                          .isNotEmpty)
                                                    SelectableText(
                                                        '${meetup['venue_address']}',
                                                        style: const TextStyle(
                                                            color: Color(
                                                                0xFF4F5D66))),
                                                ])),
                                        if ('${meetup['booking_name'] ?? ''}'
                                            .trim()
                                            .isNotEmpty)
                                          line(
                                              Icons.table_restaurant_outlined,
                                              Text(t('Table booked under “{1}”')
                                                  .replaceAll(
                                                      '{1}',
                                                      '${meetup['booking_name']}'
                                                          .trim()))),
                                        for (final field in extras)
                                          line(
                                              switch (field.key) {
                                                'meeting_point' =>
                                                  Icons.flag_outlined,
                                                'cost_notes' =>
                                                  Icons.euro_rounded,
                                                _ => Icons.accessible_rounded,
                                              },
                                              // Known texts (like the plan's cost
                                              // lines) in the member's language;
                                              // others as written.
                                              Text(
                                                  '${t(field.value)}: ${t('${meetup[field.key]}'.trim())}')),
                                      ]))),
                          if (meetup['updated_by_name'] != null) ...[
                            const SizedBox(height: 8),
                            Text('Last updated by ${meetup['updated_by_name']}',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF66727C))),
                          ],
                          const SizedBox(height: 16),
                          if (onPlan != null) ...[
                            SizedBox(
                                width: double.infinity,
                                child: CircleQuickAction(
                                    primary: true,
                                    icon: Icons.edit_calendar_outlined,
                                    label: toPlan
                                        ? 'Plan it together'
                                        : 'Change the plan together',
                                    onPressed: () {
                                      Navigator.pop(context);
                                      onPlan!();
                                    })),
                            const SizedBox(height: 8),
                          ],
                          CircleActionRow([
                            if (!hidden)
                              (
                                icon: Icons.directions_outlined,
                                label: 'Directions',
                                onTap: () => open(directions)
                              ),
                            if (circleMeetupStart(meetup) != null)
                              (
                                icon: Icons.event_rounded,
                                label: 'Calendar',
                                onTap: () => showCircleCalendarSheet(context,
                                    event: meetup,
                                    appleLink: meetup['id'] == null
                                        ? null
                                        : circleCalendarLink(
                                            meetupId: '${meetup['id']}'),
                                    fileName: 'vriendtime-meetup.ics')
                              ),
                            (
                              icon: circleWhatsAppIcon,
                              label: 'Help',
                              onTap: () =>
                                  open(Uri.parse('https://wa.me/31685660139'))
                            ),
                          ]),
                          if (toPlan || hidden) ...[
                            const SizedBox(height: 10),
                            Text(
                                toPlan
                                    ? 'Your group hasn’t planned this yet. Calendar copies don’t update, so check the app before you go.'
                                    : 'The place isn’t final yet. Calendar copies don’t update, so check the app before you leave.',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF66727C))),
                          ],
                          // The when, where and what-to-do come first; the
                          // story of the week after, for whoever wants it.
                          if (circleWeekNote(meetup) case final note?) ...[
                            const SizedBox(height: 26),
                            const Text('About this week',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: circleNavy)),
                            const SizedBox(height: 6),
                            Text(note,
                                style: const TextStyle(
                                    color: Color(0xFF4F5D66), height: 1.45)),
                          ],
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

/// The invitation link Apple Calendar opens directly (see the `calendar`
/// function): one meetup or one coffee.
String circleCalendarLink({String? meetupId, String? coffeeId}) =>
    Uri.parse('${SupabaseConfig.url}/functions/v1/calendar')
        .replace(queryParameters: {
      if (meetupId != null) 'meetup': meetupId,
      if (coffeeId != null) 'coffee': coffeeId,
    }).toString();

/// Outlook on the web opens its "new event" screen, filled in.
Uri circleOutlookUri(Json meetup) =>
    Uri.https('outlook.live.com', '/calendar/0/deeplink/compose', {
      'path': '/calendar/action/compose',
      'rru': 'addevent',
      'subject': 'VriendTime · ${circleMeetupTitle(meetup)}',
      'startdt': circleMeetupStart(meetup)!.toUtc().toIso8601String(),
      'enddt': circleMeetupEnd(meetup)!.toUtc().toIso8601String(),
      'location': _calendarLocation(meetup),
      'body':
          '${t('Open VriendTime for the latest plan:')} ${_meetupLink(meetup)}',
    });

/// iPhone, iPad and Mac: Apple Calendar can take the invitation directly.
bool get circleOnApple =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// The same calendar buttons everywhere: Apple Calendar on Apple devices,
/// Google and Outlook always, and a calendar file elsewhere.
class CircleCalendarButtons extends StatelessWidget {
  const CircleCalendarButtons(
      {super.key,
      required this.event,
      this.appleLink,
      this.fileName = 'vriendtime.ics'});
  final Json event;
  final String? appleLink;
  final String fileName;

  @override
  Widget build(BuildContext context) => CircleQuickAction(
      icon: Icons.event_rounded,
      label: 'Add to calendar',
      onPressed: () => showCircleCalendarSheet(context,
          event: event, appleLink: appleLink, fileName: fileName));
}

/// The calendar choices in a short sheet, so they don't fill the screen.
Future<void> showCircleCalendarSheet(BuildContext context,
    {required Json event,
    String? appleLink,
    String fileName = 'vriendtime.ics'}) {
  final apple = circleOnApple && appleLink != null;
  Future<void> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
  return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        Widget option(IconData icon, String label, Future<void> Function() go,
                {String? hint}) =>
            ListTile(
                leading: Icon(icon, color: circleTeal),
                title: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: hint == null
                    ? null
                    : Text(hint, style: const TextStyle(fontSize: 12.5)),
                onTap: () {
                  Navigator.pop(sheet);
                  go();
                });
        return SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Add to calendar',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 4),
                            const Text(
                                'Calendar copies don’t update, so check the app before you leave.',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF66727C))),
                          ])),
                  if (apple)
                    option(Icons.event_available, 'Apple Calendar',
                        () => open(Uri.parse(appleLink))),
                  option(Icons.calendar_month, 'Google Calendar',
                      () => open(circleCalendarUri(event))),
                  option(Icons.calendar_today_outlined, 'Outlook',
                      () => open(circleOutlookUri(event))),
                  if (!apple)
                    option(
                        Icons.download_rounded,
                        'Download calendar file',
                        hint:
                            'For any other calendar: open the file and it asks to add the meetup.',
                        () => FilePicker.platform.saveFile(
                            dialogTitle: t('Add to calendar'),
                            fileName: fileName,
                            type: FileType.custom,
                            allowedExtensions: ['ics'],
                            bytes: Uint8List.fromList(
                                utf8.encode(circleCalendarIcs(event))))),
                ])));
      });
}
