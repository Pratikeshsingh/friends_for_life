import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';
import '../core/destructive.dart';
import '../core/i18n.dart';
import 'circle_home.dart' show CircleAction, circleFeelings;
import 'circle_meetup_detail.dart' show circleCalendarIcs, circleCalendarUri;
import 'circle_repository.dart';
import 'circle_widgets.dart';

const _muted = Color(0xFF66727C);

/// "Thu 22 Oct at 19:00", in local time.
String circleCoffeeWhen(Object? raw) {
  final d = DateTime.tryParse('${raw ?? ''}')?.toLocal();
  if (d == null) return '';
  return '${circleDate(d.toIso8601String())} ${t('at')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// One-to-one coffees: this week's suggestion, and whom you've already met.
class CircleCoffees extends StatelessWidget {
  const CircleCoffees(
      {super.key,
      required this.state,
      required this.members,
      required this.busy,
      required this.act});
  final Json state;
  final List<Json> members;
  final bool busy;
  final CircleAction act;

  Json get _coffees => Map<String, dynamic>.from(state['coffees'] as Map);

  @override
  Widget build(BuildContext context) {
    final coffees = _coffees;
    final current = coffees['current'] is Map
        ? Map<String, dynamic>.from(coffees['current'] as Map)
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('One-to-one coffees',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      const Text(
          'Between group meetups, we suggest a coffee with one person from your Circle. Say yes if it works; no is fine too.',
          style: TextStyle(color: Color(0xFF4F5D66), height: 1.45)),
      const SizedBox(height: 14),
      if (coffees['feedback_due'] is Map) ...[
        _feedback(
            context, Map<String, dynamic>.from(coffees['feedback_due'] as Map)),
        const SizedBox(height: 14),
      ],
      if (current != null)
        _current(context, current)
      else if (coffees['free_week'] == true)
        const CirclePanel(tint: true, children: [
          Row(children: [
            Icon(Icons.wb_sunny_outlined, color: circleTeal),
            SizedBox(width: 10),
            Expanded(
                child: Text('Enjoy your free week',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: circleNavy))),
          ]),
          SizedBox(height: 8),
          Text(
              'No one-to-one coffee for you this time. See you with the whole group!'),
        ])
      else if (coffees['started'] != true)
        const CirclePanel(tint: true, children: [
          Text('They start after your second group meetup.'),
        ]),
      const SizedBox(height: 14),
      CoffeeTracker(members: [
        for (final m in members)
          if ('${m['id']}' != '${state['profile_id']}' && m['id'] != 'you') m
      ], met: strings(coffees['met']).toSet()),
    ]);
  }

  Widget _current(BuildContext context, Json c) {
    final other = Map<String, dynamic>.from(c['other'] as Map? ?? const {});
    // The member list already carries a loaded photo; use it when we can.
    final known = members.where((m) => '${m['id']}' == '${other['id']}');
    if (known.isNotEmpty && known.first['photo_url'] != null) {
      other['photo_url'] = known.first['photo_url'];
    }
    final name = '${other['name'] ?? 'Someone'}';
    final mine = c['mine'] as String?;
    final theirs = c['theirs'] as String?;
    final confirmed = c['status'] == 'confirmed';
    final started = DateTime.tryParse('${c['starts_at'] ?? ''}')
            ?.isBefore(DateTime.now()) ??
        false;
    void answer(String a) => act('coffee_answer', {'id': c['id'], 'answer': a});

    final String heading;
    final String? note;
    if (confirmed) {
      heading = t('You’re meeting {1}').replaceAll('{1}', name);
      note = null;
    } else if (mine == 'yes') {
      heading = t('You said yes to {1}').replaceAll('{1}', name);
      note = theirs == 'no'
          ? t('{1} can’t make it this time. We’ll try to find you someone else.')
              .replaceAll('{1}', name)
          : t('Waiting for {1} to answer.').replaceAll('{1}', name);
    } else if (mine == 'no') {
      heading = 'You can’t make it this time';
      note = theirs == 'yes'
          ? t('{1} said yes. If your plans changed, you can still join.')
              .replaceAll('{1}', name)
          : null;
    } else {
      heading = c['swap'] == true
          ? t('{1} is free this week').replaceAll('{1}', name)
          : t('This week you could meet {1}').replaceAll('{1}', name);
      note = 'A coffee, just the two of you. Can you make it?';
    }

    return CirclePanel(tint: true, children: [
      Row(children: [
        CircleMemberAvatar(name,
            radius: 24,
            photoUrl: other['photo_url'] as String?,
            photoPath: other['photo_path'] as String?),
        const SizedBox(width: 12),
        Expanded(
            child: Text(heading,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: circleNavy))),
      ]),
      const SizedBox(height: 12),
      _info(Icons.schedule_rounded, circleCoffeeWhen(c['starts_at'])),
      _info(Icons.place_outlined, '${c['place'] ?? ''}'),
      if ('${c['address'] ?? ''}'.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 6),
            child: Text('${c['address']}',
                style: const TextStyle(fontSize: 13, color: _muted))),
      if (note != null) ...[
        const SizedBox(height: 4),
        Text(note, style: const TextStyle(color: Color(0xFF4F5D66))),
      ],
      const SizedBox(height: 10),
      Text('Around an hour. You pay for yourself.',
          style: const TextStyle(fontSize: 13, color: _muted)),
      const SizedBox(height: 4),
      const Text(
          'Good to know: tables aren’t reserved. If it’s full, you can move to another public place nearby that you’re both comfortable with.',
          style: TextStyle(fontSize: 13, color: _muted)),
      const SizedBox(height: 12),
      if (confirmed && circleRunningLateWindow(c['starts_at'])) ...[
        OutlinedButton.icon(
            icon: const Icon(Icons.directions_run_rounded, size: 18),
            label: const Text('Running late'),
            onPressed: busy
                ? null
                : () => showRunningLate(context, act,
                    kind: 'coffee', id: c['id'] as Object)),
        const SizedBox(height: 4),
      ],
      if (confirmed && !started) ...[
        const Text(
            'Calendar copies don’t update, so check the app before you leave.',
            style: TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month, size: 18),
              label: const Text('Google Calendar'),
              onPressed: () => launchUrl(circleCalendarUri(_asMeetup(c, name)),
                  mode: LaunchMode.externalApplication)),
          OutlinedButton.icon(
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text('Download calendar file (Apple/Outlook)'),
              onPressed: () => FilePicker.platform.saveFile(
                  dialogTitle: t('Add to calendar'),
                  fileName: 'vriendtime-coffee.ics',
                  type: FileType.custom,
                  allowedExtensions: ['ics'],
                  bytes: Uint8List.fromList(
                      utf8.encode(circleCalendarIcs(_asMeetup(c, name)))))),
        ]),
        // Cancelling sits apart, so it never looks like a calendar option.
        const Divider(height: 28),
      ],
      if (started)
        const SizedBox.shrink()
      else if (!confirmed && mine == null)
        Wrap(spacing: 10, runSpacing: 8, children: [
          FilledButton(
              onPressed: busy ? null : () => answer('yes'),
              child: const Text('Yes, I’ll be there')),
          OutlinedButton(
              onPressed: busy ? null : () => answer('no'),
              child: const Text('Can’t make it')),
        ])
      else if (mine == 'no')
        TextButton(
            onPressed: busy ? null : () => answer('yes'),
            child: const Text('I can make it after all'))
      else
        TextButton(
            style: destructiveTextStyle,
            onPressed: busy
                ? null
                : () async {
                    final sure = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                                title: const Text('Can’t make it after all?'),
                                content: Text(t('We’ll let {1} know it’s off.')
                                    .replaceAll('{1}', name)),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(d, false),
                                      child: const Text('Keep it')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(d, true),
                                      child: const Text('Cancel the coffee')),
                                ]));
                    if (sure == true) answer('no');
                  },
            child: const Text('Can’t make it after all')),
    ]);
  }

  /// After a coffee, once: how was it? Optional, and gone after a few days.
  Widget _feedback(BuildContext context, Json due) {
    final name = '${due['name'] ?? 'your match'}';
    Future<void> send(String rating) async {
      String? note;
      if (rating == 'not' || rating == 'no_show') {
        final text = TextEditingController();
        note = await showDialog<String>(
            context: context,
            builder: (d) => AlertDialog(
                    title: Text(rating == 'no_show'
                        ? 'Sorry it didn’t happen'
                        : 'Sorry it wasn’t great'),
                    content: TextField(
                        controller: text,
                        maxLength: 1000,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                            labelText: t('What happened? (optional)'),
                            helperText: t('Only the organiser reads this.'),
                            helperMaxLines: 2)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(d, ''),
                          child: const Text('Skip')),
                      FilledButton(
                          onPressed: () => Navigator.pop(d, text.text.trim()),
                          child: const Text('Send')),
                    ]));
        if (note == null) return;
      }
      await act('coffee_feedback', {
        'id': due['id'],
        'rating': rating,
        if (note != null && note.isNotEmpty) 'note': note
      });
    }

    return CirclePanel(tint: true, children: [
      Text(t('How was your coffee with {1}?').replaceAll('{1}', name),
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: circleNavy)),
      const SizedBox(height: 4),
      const Text('Optional, and private.',
          style: TextStyle(fontSize: 13, color: _muted)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (label, rating) in [
          (circleFeelings[0], 'great'),
          (circleFeelings[1], 'good'),
          (circleFeelings[2], 'okay'),
          (circleFeelings[3], 'not'),
        ])
          OutlinedButton(
              onPressed: busy ? null : () => send(rating), child: Text(label)),
        TextButton(
            onPressed: busy ? null : () => send('no_show'),
            child: const Text('We didn’t meet after all')),
      ]),
    ]);
  }

  /// The coffee in the shape the calendar helpers use: one hour, at the place.
  static Json _asMeetup(Json c, String name) {
    final start = DateTime.tryParse('${c['starts_at'] ?? ''}');
    final address = '${c['address'] ?? ''}'.trim();
    return {
      'title': t('Coffee with {1}').replaceAll('{1}', name),
      'starts_at': c['starts_at'],
      'ends_at': start?.add(const Duration(hours: 1)).toIso8601String(),
      'venue':
          address.isEmpty ? '${c['place'] ?? ''}' : '${c['place']}, $address',
    };
  }

  Widget _info(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: circleTeal),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]));
}

/// Whom you've had a coffee with: a bar and a row of faces, ticked once met.
/// Progress, not an obligation.
class CoffeeTracker extends StatelessWidget {
  const CoffeeTracker({super.key, required this.members, required this.met});
  final List<Json> members;
  final Set<String> met;

  @override
  Widget build(BuildContext context) {
    final done = members.where((m) => met.contains('${m['id']}')).length;
    final total = members.length;
    return CirclePanel(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your coffees so far',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: circleNavy)),
          SizedBox(height: 2),
          Text('One-to-ones with your Circle',
              style: TextStyle(fontSize: 13, color: _muted)),
        ])),
        Semantics(
            label: t('{1} of {2} met')
                .replaceAll('{1}', '$done')
                .replaceAll('{2}', '$total'),
            child: ExcludeSemantics(
                child: Text('$done/$total',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: circleNavy)))),
      ]),
      const SizedBox(height: 12),
      ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              color: circleTeal,
              backgroundColor: const Color(0xFFEAF2EF))),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 10, children: [
        for (var i = 0; i < members.length; i++)
          _person(members[i], i, met.contains('${members[i]['id']}')),
      ]),
    ]);
  }

  Widget _person(Json m, int index, bool done) {
    final name = '${m['name'] ?? 'Member'}';
    return Semantics(
        container: true,
        label: done
            ? t('{1}: met').replaceAll('{1}', name)
            : t('{1}: not yet').replaceAll('{1}', name),
        child: ExcludeSemantics(
            child: SizedBox(
                width: 64,
                child: Column(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Opacity(
                        opacity: done ? 1 : .55,
                        child: CircleMemberAvatar(name,
                            index: index,
                            radius: 22,
                            photoUrl: m['photo_url'] as String?,
                            photoPath: m['photo_path'] as String?)),
                    Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: done ? circleTeal : Colors.white,
                                border: Border.all(
                                    color: done
                                        ? circleTeal
                                        : const Color(0xFFDDE7E3))),
                            child: Icon(
                                done
                                    ? Icons.check_rounded
                                    : Icons.coffee_outlined,
                                size: 14,
                                color: done ? Colors.white : _muted))),
                  ]),
                  const SizedBox(height: 6),
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ]))));
  }
}

/// "Running late" shows from three hours before until an hour after the start.
bool circleRunningLateWindow(Object? startsAt, {DateTime? now}) {
  final start = DateTime.tryParse('${startsAt ?? ''}');
  if (start == null) return false;
  final at = now ?? DateTime.now();
  return at.isAfter(start.subtract(const Duration(hours: 3))) &&
      at.isBefore(start.add(const Duration(hours: 1)));
}

/// One tap instead of typing while you hurry: posts "Running about 10
/// minutes late" in the group chat, and tells a coffee partner directly.
Future<void> showRunningLate(BuildContext context, CircleAction act,
    {required String kind, required Object id}) async {
  final minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How late will you be?',
                        style: Theme.of(sheet).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(kind == 'coffee'
                        ? 'We post it in your group chat and let them know.'
                        : 'We post it in your group chat.'),
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final m in const [5, 10, 15, 30])
                        OutlinedButton(
                            onPressed: () => Navigator.pop(sheet, m),
                            child: Text(
                                t('About {1} min').replaceAll('{1}', '$m'))),
                    ]),
                  ]))));
  if (minutes == null || !context.mounted) return;
  try {
    await act('running_late', {'kind': kind, 'id': id, 'minutes': minutes});
    if (context.mounted) {
      showCircleToast(context, t('Your Circle knows. See you soon!'),
          icon: Icons.check_circle_outline_rounded);
    }
  } catch (_) {}
}
