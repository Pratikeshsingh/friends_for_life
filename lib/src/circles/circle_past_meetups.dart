import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import 'circle_repository.dart';
import 'circle_widgets.dart';

/// The evenings a member has already had with their Circle.
///
/// This used to open the whole legacy meetups app, which gates on its own
/// onboarding — city, date of birth, gender, phone — none of which a Circles
/// member has ever been asked for. So "Previous meetups" reliably landed on
/// "A little about you" and asked for details the programme does not use.
/// A member's previous meetups are simply their Circle's completed ones, and
/// the snapshot already carries them.
class CirclePastMeetups extends StatelessWidget {
  const CirclePastMeetups({super.key, required this.state});
  final Json state;

  @override
  Widget build(BuildContext context) {
    final past = rows(state['meetups']).where(circleMeetupPast).toList()
      // Most recent first: the evening you are most likely to be looking for.
      ..sort((a, b) => circleMeetupCompare(b, a));
    final circle = state['circle'] as Map? ?? {};
    final checkedIn = {
      for (final c in rows(state['check_ins'])) '${c['id']}': c['feeling']
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Previous meetups')),
      body: SafeArea(
        child: past.isEmpty
            ? _empty(context)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                itemCount: past.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                            past.length == 1
                                ? 'One evening so far with ${circle['name'] ?? 'your Circle'}.'
                                : '${past.length} evenings so far with ${circle['name'] ?? 'your Circle'}.',
                            style: Theme.of(context).textTheme.titleMedium));
                  }
                  final m = past[i - 1];
                  final feeling = checkedIn['${m['id']}'];
                  return CirclePanel(children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              m['week'] == null
                                  ? 'YOUR OWN PLAN'
                                  : 'WEEK ${m['week']}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.6,
                                  fontWeight: FontWeight.w800,
                                  color: circleTeal))),
                      const Icon(Icons.check_circle_rounded,
                          color: circleTeal, size: 20),
                    ]),
                    const SizedBox(height: 10),
                    Text('${m['title'] ?? 'A meetup'}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                        '${circleDate(m['date'] as String?)} · ${m['time'] ?? '19:30'}'),
                    const SizedBox(height: 6),
                    // A venue is no longer a secret once the evening has
                    // happened, but an old payload may still be missing it.
                    Text(circleVenueLabel({...m, 'week': null}),
                        style: const TextStyle(fontSize: 13)),
                    if (feeling != null) ...[
                      const SizedBox(height: 12),
                      CirclePill('You said: $feeling'),
                    ],
                  ]);
                }),
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.event_note_outlined, size: 44, color: circleTeal),
            const SizedBox(height: 18),
            Text('Nothing behind you yet.',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text(
                'Once you have met your Circle, every evening you have shared shows up here.',
                textAlign: TextAlign.center),
          ]),
        ),
      );
}
