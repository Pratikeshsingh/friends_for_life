import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';
import '../core/i18n.dart';
import 'circle_repository.dart';

Future<void> openCircleMeetup(BuildContext context, Json meetup) => Navigator.push(context,
  MaterialPageRoute<void>(builder: (_) => CircleMeetupDetail(meetup: meetup)));
class CircleMeetupDetail extends StatelessWidget {
  const CircleMeetupDetail({super.key, required this.meetup});
  final Json meetup;
  @override
  Widget build(BuildContext context) {
    final location = circleVenueLabel(meetup);
    final hidden = location.startsWith('Revealed') || location == 'Location to be confirmed';
    Future<void> open(Uri url) async {
      try {
        if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Could not open this link. Please try again.'))));
    }
    return Scaffold(appBar: AppBar(title: const Text('Meetup details')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(circleMeetupTitle(meetup), style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text('${circleDate(meetup['date'])} · ${meetup['time']} · Netherlands time'),
          const SizedBox(height: 16), SelectableText(location),
          if (!hidden && '${meetup['venue_address'] ?? ''}'.isNotEmpty) SelectableText('${meetup['venue_address']}'),
          for (final field in {'meeting_point':'Meeting point', 'cost_notes':'Costs', 'accessibility_notes':'Accessibility'}.entries) ...[
            const SizedBox(height: 12),
            Text('${t(field.value)}: ${meetup[field.key] ?? t('Details to be confirmed')}'),
          ],
          if (meetup['updated_by_name'] != null) ...[
            const SizedBox(height: 12), Text('Last updated by ${meetup['updated_by_name']}'),
          ],
          const SizedBox(height: 20),
          if (!hidden) OutlinedButton.icon(icon: const Icon(Icons.directions_outlined), label: const Text('Directions'),
            onPressed: () => open(Uri.https('www.google.com','/maps/search/', {'api':'1','query':'${meetup['venue_address'] ?? location}, Alkmaar'}))),
          if (circleMeetupStart(meetup) != null) OutlinedButton.icon(icon: const Icon(Icons.calendar_month), label: const Text('Add to calendar'),
            onPressed: () => open(circleCalendarUri(meetup))),
          const Text('Check this plan again before leaving. Calendar copies do not update automatically.'),
          TextButton(onPressed: () => open(Uri.parse('https://wa.me/31685660139')), child: const Text('Help & contact')),
        ])));
  }
}
Uri circleCalendarUri(Json meetup) {
  String stamp(DateTime date) => '${date.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':','').split('.').first}Z';
  return Uri.https('calendar.google.com','/calendar/render', {
    'action':'TEMPLATE', 'text':'VriendTime · ${circleMeetupTitle(meetup)}',
    'dates':'${stamp(circleMeetupStart(meetup)!)}/${stamp(circleMeetupEnd(meetup)!)}',
    'location': circleVenueLabel(meetup), 'ctz':'Europe/Amsterdam',
    'details':'Open VriendTime for the latest plan: https://vriendtime.com/',
  });
}
