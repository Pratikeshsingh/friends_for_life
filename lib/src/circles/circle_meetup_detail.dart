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
                          if (week != null && week >= 1 && week <= 6) ...[
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
                                  label: const Text('Add to calendar'),
                                  onPressed: () =>
                                      open(circleCalendarUri(meetup))),
                          ]),
                          const SizedBox(height: 10),
                          const Text(
                              'Check this plan again before leaving. Calendar copies do not update automatically.',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF66727C))),
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
    'location': circleVenueLabel(meetup),
    'ctz': 'Europe/Amsterdam',
    'details': 'Open VriendTime for the latest plan: https://vriendtime.com/',
  });
}
