import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/destructive.dart';
import '../core/payment_config.dart';
import 'circle_repository.dart';
import 'circle_meetup_detail.dart';
import 'circle_widgets.dart';
import 'circle_journey.dart';
import 'circle_leave.dart';
import 'circle_preferences.dart';

typedef CircleAction = Future<void> Function(String action, [Json data]);

class CircleHome extends StatelessWidget {
  const CircleHome(
      {super.key,
      required this.state,
      required this.demo,
      required this.busy,
      required this.act,
      required this.onEdit,
      required this.onMessages,
      this.savePlan});
  final Json state;
  final bool demo, busy;
  final CircleAction act;
  final CircleAction? savePlan;

  /// Opens the application at a specific step, so "update my availability"
  /// lands on availability rather than on name and date of birth.
  final ValueChanged<int> onEdit;
  final VoidCallback onMessages;
  @override
  Widget build(BuildContext context) {
    final stage = state['stage'];
    final app = state['application'] as Map? ?? {};
    final circle = state['circle'] as Map? ?? {};
    final members = rows(state['members']);
    final meetups = rows(state['meetups']);
    final completed = meetups
        .where((m) => m['week'] != null && m['completed'] == true)
        .length;
    final pending = meetups.where((m) => !circleMeetupPast(m)).toList()
      ..sort(circleMeetupCompare);
    final upcoming = pending.firstOrNull;
    if (stage == 'apply' && state['left_circle'] is Map) {
      return CircleLeftCard(
          left: state['left_circle'] as Map,
          busy: busy,
          onRejoin: () => act('rejoin'),
          onEdit: () => onEdit(0));
    }
    if (stage == 'apply') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleHeading('Your application\nis waiting for you.',
            eyebrow: 'Nearly there',
            subtitle: 'Your answers are saved. Pick up where you left off.'),
        CirclePanel(children: [
          Row(children: [
            const Icon(Icons.edit_note_rounded, color: circleTeal),
            const SizedBox(width: 10),
            Expanded(
                child: Text('Application in progress',
                    style: Theme.of(context).textTheme.headlineSmall))
          ]),
          const SizedBox(height: 12),
          const Text(
              'Finish your answers and we’ll start looking for your Circle.'),
          const SizedBox(height: 18),
          ElevatedButton(
              onPressed: busy ? null : () => onEdit(0),
              child: const Text('Continue my application')),
        ]),
        const SizedBox(height: 20),
        const CircleJourney(compact: true),
      ]);
    }
    if (stage == 'waiting') {
      final slots = circleSlots(Map<String, dynamic>.from(app));
      final wait = circleWaitEstimate(state);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleHeading('You’re on the list.',
            eyebrow: 'Application received',
            subtitle:
                'We’re finding five or six people who fit you. Your invitation will appear here, and we’ll let you know.'),
        if (state['move_credit'] == true) ...[
          const SizedBox(
              width: double.infinity,
              child: CirclePanel(tint: true, children: [
                Text('You’re moving to a new group',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: circleNavy)),
                SizedBox(height: 6),
                Text(
                    'Your €19 carries over, so your next Circle is free. We’ll invite you as soon as we find a group that fits.'),
              ])),
          const SizedBox(height: 16),
        ],
        if (state['needs_details'] == true) ...[
          SizedBox(
              width: double.infinity,
              child: CirclePanel(tint: true, children: [
                const Row(children: [
                  Icon(Icons.error_outline_rounded, color: circleCoral),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text('Finish your profile to be matched',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, color: circleNavy))),
                ]),
                const SizedBox(height: 8),
                const Text(
                    'We can’t put you in a group until we have your birthday, photo and times.'),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: () => onEdit(0),
                    child: const Text('Finish my profile')),
              ])),
          const SizedBox(height: 16),
        ],
        Container(
            decoration: BoxDecoration(
                color: const Color(0xFFE0EEE8),
                borderRadius: BorderRadius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: Image.asset('assets/generated/home-hero-coffee.webp',
                      fit: BoxFit.cover, excludeFromSemantics: true)),
              Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleMemberAvatar(app['name']?.toString() ?? '',
                              photoUrl: app['photo_url'] as String?,
                              photoPath: app['photo_path'] as String?,
                              radius: 26),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Text('Your progress',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall))
                        ]),
                        const SizedBox(height: 18),
                        Text(wait.progressLine),
                        const SizedBox(height: 20),
                        for (final item in [
                          (Icons.check_circle, 'Application received', true),
                          wait.complete
                              ? (Icons.check_circle, 'Group found', true)
                              : (
                                  Icons.people_outline,
                                  'Finding your people',
                                  false
                                ),
                          (Icons.mail_outline, 'Your invitation', false)
                        ])
                          Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(children: [
                                Icon(item.$1,
                                    color: item.$3 ? circleTeal : circleNavy,
                                    size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(item.$2,
                                        style: TextStyle(
                                            fontWeight: item.$3
                                                ? FontWeight.w700
                                                : FontWeight.w500))),
                                if (item.$2 == 'Finding your people')
                                  const CirclePill('In progress')
                                else if (item.$2 == 'Your invitation' &&
                                    wait.complete)
                                  const CirclePill('Being prepared')
                              ])),
                        if (wait.isKnown) ...[
                          Semantics(
                              label: t(
                                  '${wait.progressLine}. ${wait.headline}. ${wait.estimate}.'),
                              child: ExcludeSemantics(
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                          value: wait.progress,
                                          minHeight: 8,
                                          backgroundColor: Colors.white,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                  circleTeal))))),
                          const SizedBox(height: 10),
                          Text(wait.headline,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(wait.estimate),
                          const SizedBox(height: 10),
                        ],
                        Text(
                            '${wait.daysWaiting == null ? '' : '${_waitedFor(wait.daysWaiting!)} '}No payment is due yet.',
                            style: const TextStyle(fontSize: 13)),
                      ])),
            ])),
        // A reminder, not a fixture: only when the times have not been
        // confirmed for a while, and never once the group is complete.
        // Changing times lives in the profile.
        if (!wait.complete && !_confirmedRecently(state)) ...[
          const SizedBox(height: 20),
          CirclePanel(children: [
            Row(children: [
              const Icon(Icons.event_available_outlined, color: circleTeal),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Still free at these times?',
                      style: Theme.of(context).textTheme.headlineSmall))
            ]),
            const SizedBox(height: 12),
            const Text(
                'A quick check every few weeks, so we only match you when you can come.'),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in slots.entries)
                CirclePill(
                    '${circleDays[circleDayKeys.indexOf(e.key)].substring(0, 3)} · ${e.value.join(' / ')}')
            ]),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    onPressed: busy || state['needs_details'] == true
                        ? null
                        : () => act('refresh_commitment'),
                    child: const Text('Yes, these times still work'))),
            const SizedBox(height: 8),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    onPressed: () => onEdit(1),
                    child: const Text('Change my times'))),
          ]),
        ],
        const SizedBox(height: 20),
        const CircleJourney(compact: true),
      ]);
    }
    if (stage == 'cancelled' || stage == 'refunded') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleHeading(
            stage == 'refunded'
                ? 'Your refund is complete.'
                : 'A change of plans.',
            eyebrow: 'Your Circle',
            subtitle: stage == 'refunded'
                ? 'The organiser has confirmed your €19 was returned. Contact us if it hasn’t arrived.'
                : 'We’re sorry, this Circle cannot go ahead. Any received programme fee will be returned.'),
        CirclePanel(children: [
          Text(circle['name']?.toString() ?? 'Your Circle'),
          const SizedBox(height: 16),
          if (state['payment'] != 'paid')
            FilledButton(
                onPressed: busy ? null : () => act('leave_closed_circle'),
                child: const Text('Find another Circle'))
          else
            const Text(
                'Your refund is being arranged. You’ll receive an update here.'),
        ]),
      ]);
    }
    final agreed =
        (state['payment_agreement'] as Map?)?['status'] == 'awaiting_payment';
    final invited = stage == 'invited';
    final graduated = stage == 'completed';
    // Someone who moved here already paid for their first Circle.
    final credit = state['move_credit'] == true;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleHeading(
          graduated
              ? 'Your Circle is now yours.'
              : invited && agreed
                  ? 'Almost there.'
                  : invited
                      ? 'Meet your Circle.'
                      : 'A few familiar faces.\nA plan to look forward to.',
          eyebrow: graduated
              ? 'Six weeks. A new beginning.'
              : invited
                  ? 'You’re invited'
                  : '${circle['name'] ?? 'Your Circle'} · Week ${(completed + 1).clamp(1, 6)} of 6',
          subtitle: graduated
              ? 'Keep meeting. Keep making plans. There’s no further programme payment.'
              : invited && agreed
                  ? 'Your place is held for you. Once your €19 has arrived, your Circle and its chat open.'
                  : invited
                      ? 'Look at the people and the six dates. If it works for you, say yes.'
                      : null),
      if (invited)
        CirclePanel(tint: true, children: [
          Text(circle['name']?.toString() ?? 'Your Founding Circle',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          _info(Icons.calendar_month_outlined,
              'Starts ${circleDate(circle['start_date']?.toString())}'),
          _info(Icons.schedule_rounded,
              circle['schedule']?.toString() ?? 'Schedule to be confirmed'),
          _info(Icons.place_outlined, circle['city']?.toString() ?? 'Alkmaar'),
          if (state['pay_by'] != null && !credit)
            _info(
                Icons.hourglass_bottom_rounded,
                agreed
                    ? 'Pay by ${circleDate(state['pay_by']?.toString())}'
                    : 'Accept and pay by ${circleDate(state['pay_by']?.toString())}')
          else if (state['pay_by'] != null)
            _info(Icons.hourglass_bottom_rounded,
                'Please reply by ${circleDate(state['pay_by']?.toString())}')
          else if (_replyBy(circle) != null)
            _info(Icons.hourglass_bottom_rounded,
                'Please reply by ${_replyBy(circle)}'),
          // Past the pay-by date without payment: say plainly that the
          // payment is the only thing holding the place back.
          if (!credit && _payOverdue(state)) ...[
            const SizedBox(height: 8),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFEDE7),
                    borderRadius: BorderRadius.circular(14)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          agreed
                              ? 'Your €19 has not arrived yet'
                              : 'Your invitation is still open',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: circleCoralText)),
                      const SizedBox(height: 4),
                      Text(agreed
                          ? 'Your place is confirmed only once your €19 arrives, nothing else. The pay-by date has passed, so the organiser may now offer your place to someone on the waiting list. Pay now to keep it. If you have already paid, tap “I’ve sent the payment”.'
                          : 'The pay-by date has passed, so the organiser may now offer your place to someone on the waiting list. Accept and pay now to keep it.'),
                    ])),
          ],
          // Before deciding, people look at the group and the six dates
          // first; the answer comes after them. Once accepted, paying is the
          // next step, so it stays here at the top.
          if (agreed)
            ..._decision(context, agreed, credit)
          else ...[
            // Saying yes is the next step, so it is right here; the full
            // price and refund terms sit with the second button below, next
            // to the group and dates.
            const SizedBox(height: 16),
            _acceptButton(context, agreed, credit),
            const SizedBox(height: 10),
            Text(
                credit
                    ? 'Already paid from your previous Circle. The group and all six dates are below.'
                    : '€19 for all six weeks. The group, all six dates and the refund terms are below.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF4F5D66))),
          ],
        ]),
      if (graduated) ...[
        CirclePanel(tint: true, children: [
          const Icon(Icons.favorite_rounded, color: circleCoral, size: 36),
          const SizedBox(height: 14),
          Text('Make room for week seven.',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          const Text(
              'Pick a day. Revisit a favourite place. It doesn’t need to be a big occasion.'),
          const SizedBox(height: 18),
          ElevatedButton(
              onPressed: busy
                  ? null
                  : () => scheduleCircleMeetup(context, savePlan ?? act),
              child: const Text('Plan our next meetup')),
          TextButton(onPressed: onMessages, child: const Text('Ask the Circle'))
        ]),
        const SizedBox(height: 20),
        _anotherCircle(context),
        const SizedBox(height: 20),
        _outcome(context)
      ],
      if (!invited && upcoming != null) ...[
        const SizedBox(height: 20),
        _meetup(context, upcoming, featured: true)
      ],
      const SizedBox(height: 26),
      Text('The people in your Circle',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      _peopleCard(context, members, invited),
      const SizedBox(height: 28),
      Text('Six weeks, a little closer',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      const Text(
          'Dates and times are fixed. We plan weeks 1 to 3; from week 4 your group picks the activity and place. Netherlands time.',
          style: TextStyle(color: Color(0xFF4F5D66), height: 1.45)),
      const SizedBox(height: 14),
      _weekList(
          context,
          [
            for (final m in meetups)
              if (m['week'] != null) m
          ],
          nextId: upcoming?['id']),
      if (invited && !agreed) ...[
        const SizedBox(height: 20),
        CirclePanel(tint: true, children: [
          Text('Does this group work for you?',
              style: Theme.of(context).textTheme.headlineSmall),
          ..._decision(context, agreed, credit),
        ]),
      ],
      if (meetups.any((m) => m['week'] == null && !circleMeetupPast(m))) ...[
        const SizedBox(height: 20),
        Text('Extra plans', style: Theme.of(context).textTheme.headlineSmall),
        const Text(
            'Optional plans from your Circle. RSVP to let everyone know you’re coming.'),
        for (final m
            in meetups.where((m) => m['week'] == null && !circleMeetupPast(m)))
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _meetup(context, m)),
      ],
      if (!invited) ...[
        const SizedBox(height: 16),
        OutlinedButton(
            onPressed: busy
                ? null
                : () => scheduleCircleMeetup(context, savePlan ?? act),
            child: Text(
                graduated ? 'Add another plan' : 'Suggest an extra meetup')),
        const SizedBox(height: 16),
        if (state['refund'] != null)
          CirclePanel(children: [
            Text(
                state['refund'] == 'refunded'
                    ? 'Refund confirmed'
                    : 'Refund request received',
                style: Theme.of(context).textTheme.titleMedium),
            const Text(
                'Your request is private. Our team will follow up with you.')
          ])
        else if ((state['switch'] as Map?)?['available'] == true ||
            (state['move'] as Map?)?['available'] == true)
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4F5D66)),
              onPressed: busy
                  ? null
                  : () => showCircleLeaveFlow(context, state: state, act: act),
              child: const Text('Circle not feeling right?')),
      ],
    ]);
  }

  /// Whether the member confirmed these times in the last three weeks.
  /// Confirming again inside that window changes nothing on the server, so
  /// offering the button again is a control that does not do anything.
  /// The last day a "yes" is accepted: the database takes replies until the
  /// day before the Circle starts.
  /// The pay-by date (end of that day) has passed and the place is not paid.
  static bool _payOverdue(Json state, {DateTime? now}) {
    final due = DateTime.tryParse('${state['pay_by'] ?? ''}');
    if (due == null || state['payment'] == 'paid') return false;
    final today = now ?? DateTime.now();
    return DateTime(today.year, today.month, today.day).isAfter(due);
  }

  static String? _replyBy(Map circle) {
    final start = DateTime.tryParse('${circle['start_date']}');
    if (start == null) return null;
    return circleDate(
        start.subtract(const Duration(days: 1)).toIso8601String());
  }

  static bool _confirmedRecently(Json state, {DateTime? now}) {
    final at = DateTime.tryParse('${state['application_updated_at']}');
    if (at == null) return false;
    return (now ?? DateTime.now()).difference(at) < const Duration(days: 21);
  }

  /// Days are reassuring for the first fortnight and discouraging after it, so
  /// a longer wait is rounded to whole weeks.
  static String _waitedFor(int days) => switch (days) {
        0 => 'You applied today.',
        1 => 'You’ve been on the list since yesterday.',
        < 14 => 'You’ve been on the list $days days.',
        _ => 'You’ve been on the list ${days ~/ 7} weeks.',
      };

  Widget _info(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: circleTeal),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text.isEmpty ? 'Not specified' : text,
                style: const TextStyle(color: circleNavy)))
      ]));

  Widget _acceptButton(BuildContext context, bool agreed, bool credit) =>
      ElevatedButton(
          onPressed: busy || agreed
              ? null
              : credit
                  ? () => act('join')
                  : () => _checkout(context),
          child: Text(agreed
              ? 'Invitation accepted'
              : credit
                  ? 'Accept invitation — already paid'
                  : 'Accept invitation — €19'));

  /// Accepting, paying and declining an invitation.
  List<Widget> _decision(BuildContext context, bool agreed, bool credit) {
    final agreement = state['payment_agreement'] as Map?;
    final reported = agreement?['payment_reported_at'] != null;
    return [
      const SizedBox(height: 20),
      if (!agreed)
        _acceptButton(context, agreed, credit)
      else
        const Row(children: [
          Icon(Icons.check_circle_rounded, color: circleTeal, size: 20),
          SizedBox(width: 8),
          Expanded(
              child: Text('Invitation accepted',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: circleTealText))),
        ]),
      // Once accepted, paying is the one thing left: it comes first.
      if (agreed && !demo && !credit) ...[
        const SizedBox(height: 14),
        if (_payLink == null)
          const Text(
              'The organiser will send you the payment link. Your place and group chat open once your €19 has arrived.',
              style: TextStyle(fontWeight: FontWeight.w700))
        else if (!reported) ...[
          FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: busy ? null : () => _pay(context),
              icon: const Icon(Icons.account_balance_outlined),
              label: const Text('Pay €19 with iDEAL')),
          const SizedBox(height: 8),
          const Text(
              'Pay from an account in your own name, so the organiser can match it. Your place and group chat open once it has arrived.',
              style: TextStyle(fontSize: 13, color: Color(0xFF4F5D66))),
          TextButton(
              onPressed: busy ? null : () => act('payment_sent'),
              child: const Text('I’ve already paid')),
        ] else
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFE4F0EB),
                  borderRadius: BorderRadius.circular(14)),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment sent ✓',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: circleTealText)),
                    SizedBox(height: 4),
                    Text(
                        'The organiser will confirm it soon. You don’t need to pay again.'),
                  ])),
      ],
      const SizedBox(height: 14),
      Text(
          credit
              ? 'Your €19 from your previous Circle covers this one. Food and drinks are paid at the venue.'
              : 'One payment for all six weeks. Food and drinks are paid at the venue. Not the right group or time? You can switch to another group once, free of charge, until your second meetup.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF4F5D66))),
      if (!agreed && !demo && !credit) ...[
        const SizedBox(height: 8),
        Text(
            _payLink != null
                ? 'Accept first, then pay the €19 with iDEAL.'
                : 'No online checkout. If you accept, the organiser will send you the payment link.',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
      TextButton(
          onPressed: busy ? null : () => _decline(context),
          child: const Text('This schedule doesn’t work for me'))
    ];
  }

  /// Everyone in the Circle at a glance, wrapping onto a second row rather
  /// than hiding the last person off-screen. You are marked as "You".
  Widget _peopleCard(BuildContext context, List<Json> members, bool invited) =>
      CirclePanel(children: [
        Wrap(spacing: 6, runSpacing: 10, children: [
          for (var i = 0; i < members.length; i++)
            InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _member(context, members[i]),
                child: SizedBox(
                    width: 64 *
                        (MediaQuery.textScalerOf(context).scale(13) / 13)
                            .clamp(1.0, 1.6),
                    child: Column(children: [
                      const SizedBox(height: 4),
                      CircleMemberAvatar(members[i]['name'] as String,
                          index: i,
                          radius: 24,
                          photoUrl: members[i]['photo_url'] as String?,
                          photoPath: members[i]['photo_path'] as String?),
                      const SizedBox(height: 6),
                      Text(
                          '${members[i]['id']}' == '${state['profile_id']}'
                              ? t('You')
                              : members[i]['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                    ]))),
        ]),
        const Divider(height: 24),
        // Side by side when there is room; stacked on narrow phones or with
        // large text, so the tip reads as sentences instead of a sliver.
        LayoutBuilder(builder: (context, box) {
          final tip = Text(
              invited
                  ? 'The same faces every week.'
                  : 'You don’t need a perfect opener. A simple “how’s your week?” works.',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF4F5D66), height: 1.4));
          if (invited) return tip;
          final hello = FilledButton.tonalIcon(
              onPressed: onMessages,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Say hello'));
          final stacked = box.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(14) > 18;
          return stacked
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  tip,
                  const SizedBox(height: 10),
                  hello,
                ])
              : Row(children: [
                  Expanded(child: tip),
                  const SizedBox(width: 8),
                  hello,
                ]);
        }),
      ]);

  /// The six programme weeks as one compact list: a row per week that opens
  /// its details. Finished weeks are ticked, the next one is highlighted.
  Widget _weekList(BuildContext context, List<Json> weeks, {Object? nextId}) {
    final invited = state['stage'] == 'invited';
    final checks = rows(state['check_ins']);
    Widget row(Json m) {
      final week = m['week'] as int;
      final done = circleMeetupPast(m);
      final next = m['id'] == nextId && !done;
      final groupPlans = !done && week >= 4;
      final checked = checks.any((c) => c['id'] == m['id']);
      final circle = Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? circleTeal
                  : next
                      ? circleCoral
                      : const Color(0xFFEAF2EF)),
          child: done
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
              : Text('$week',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: next ? Colors.white : circleNavy)));
      Widget? action;
      if (!invited && done) {
        action = TextButton(
            onPressed: busy ? null : () => _checkIn(context, m),
            child: Text(checked ? 'Checked in ✓' : 'Check in'));
      } else if (!invited && groupPlans) {
        action = TextButton(
            onPressed: busy
                ? null
                : () =>
                    scheduleCircleMeetup(context, savePlan ?? act, meetup: m),
            child: const Text('Plan it'));
      }
      return InkWell(
          onTap: () => openCircleMeetup(context, m),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                circle,
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(circleMeetupTitle(m),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color:
                                  done ? const Color(0xFF66727C) : circleNavy)),
                      const SizedBox(height: 2),
                      Text(
                          [
                            '${circleDate(m['date'] as String?)} · ${m['time'] ?? '19:30'}',
                            if (next) 'Next',
                            // The "Plan it" button says it already.
                            if (groupPlans && invited) 'Your group plans this',
                          ].join(' · '),
                          style: TextStyle(
                              fontSize: 13,
                              color: next
                                  ? circleCoralText
                                  : const Color(0xFF66727C),
                              fontWeight:
                                  next ? FontWeight.w700 : FontWeight.w500)),
                    ])),
                action ??
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF66727C)),
              ])));
    }

    return Material(
        color: Colors.white.withValues(alpha: .94),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFDDE7E3))),
        child: Column(children: [
          for (var i = 0; i < weeks.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 66),
            row(weeks[i]),
          ],
        ]));
  }

  Widget _meetup(BuildContext context, Json m, {bool featured = false}) {
    final week = m['week'] as int?;
    final done = circleMeetupPast(m);
    final checks = rows(state['check_ins']);
    final checked = checks.any((c) => c['id'] == m['id']);
    final invited = state['stage'] == 'invited';
    return CirclePanel(tint: featured, children: [
      Row(children: [
        Expanded(
            child: Text(
                featured
                    ? 'YOUR NEXT MEETUP'
                    : week == null
                        ? 'ANOTHER PLAN'
                        : 'WEEK $week',
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                    color: circleTealText))),
        if (done)
          const Icon(Icons.check_circle_rounded, color: circleTeal, size: 21)
      ]),
      const SizedBox(height: 10),
      Text(circleMeetupTitle(m),
          style: featured
              ? Theme.of(context).textTheme.headlineMedium
              : Theme.of(context).textTheme.titleMedium),
      if (!done && week != null && week >= 4) ...[
        const SizedBox(height: 8),
        const CirclePill('Your group plans this', icon: Icons.groups_outlined),
      ],
      const SizedBox(height: 8),
      Text('${circleDate(m['date'] as String?)} · ${m['time'] ?? '19:30'}'),
      if (featured || week == null) ...[
        const SizedBox(height: 12),
        _info(Icons.place_outlined, circleVenueLabel(m)),
        if (week != null)
          const Text(
              'Your place is included in the programme. Can’t make it? Let your Circle know in the chat.'),
        if (week == null) ...[
          CirclePill(
              '${m['confirmed'] ?? 0}/${rows(state['members']).length} confirmed',
              icon: Icons.people_outline),
          const SizedBox(height: 18),
          ElevatedButton(
              onPressed: busy
                  ? null
                  : () =>
                      act('rsvp', {'id': m['id'], 'going': m['rsvp'] != true}),
              child: Text(m['rsvp'] == true
                  ? 'You’re going ✓ · Change RSVP'
                  : 'I’ll be there')),
        ],
        if (demo)
          TextButton(
              onPressed:
                  busy ? null : () => act('complete_meetup', {'id': m['id']}),
              child: const Text('Preview: finish this meetup'))
      ],
      TextButton(
          onPressed: () => openCircleMeetup(context, m),
          child: const Text('View meetup details')),
      if (!done &&
          !invited &&
          week == null &&
          (m['created_by'] == state['profile_id'] ||
              demo ||
              state['is_admin'] == true)) ...[
        TextButton(
            onPressed: busy
                ? null
                : () =>
                    scheduleCircleMeetup(context, savePlan ?? act, meetup: m),
            child: const Text('Edit extra plan')),
        TextButton(
            onPressed: busy
                ? null
                : () async {
                    final yes = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                                title: const Text('Cancel this extra plan?'),
                                content:
                                    const Text('Your Circle will be notified.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Keep plan')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Cancel plan'))
                                ]));
                    if (yes == true) {
                      await act('cancel_extra',
                          {'id': m['id'], 'version': m['plan_version']});
                    }
                  },
            child: const Text('Cancel extra plan')),
      ],
      if (!featured && week != null) ...[
        const SizedBox(height: 8),
        Text(circleWeekNotes[week - 1])
      ],
      if (done && !invited) ...[
        const SizedBox(height: 10),
        TextButton(
            onPressed: busy ? null : () => _checkIn(context, m),
            child: Text(checked
                ? 'Your private check-in is saved ✓'
                : 'How did this meetup feel?'))
      ],
      if (!done && !invited && week != null && week >= 4)
        TextButton(
            onPressed: busy
                ? null
                : () =>
                    scheduleCircleMeetup(context, savePlan ?? act, meetup: m),
            child: const Text('Make a plan together')),
    ]);
  }

  Future<void> _checkout(BuildContext context) async {
    bool agreed = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, update) => AlertDialog(
                title: Text(demo
                    ? 'Try joining your Circle'
                    : 'Accept your invitation'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(demo
                      ? 'Preview checkout · €19 one-off. No money is collected in this preview.'
                      : 'The full six-week programme costs €19 once. Food, drinks and activities are separate and paid at the venue. ${_payLink != null ? 'After you accept, you can pay straight away with iDEAL.' : 'The organiser will send you a payment link. During this pilot the link comes from the organiser’s own bunq or Tikkie, so you’ll see their name when you pay.'} Your place is confirmed when payment is received. You can leave and ask for a refund up to 48 hours before your first meetup. Not the right group or time? You can switch to another group once, free of charge, until your second meetup.'),
                  if (!demo)
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: agreed,
                        onChanged: (value) =>
                            update(() => agreed = value == true),
                        title: const Text(
                            'I agree to pay the one-off €19 programme fee.')),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Back')),
                  FilledButton(
                      onPressed:
                          demo || agreed ? () => Navigator.pop(c, true) : null,
                      child: Text(
                          demo ? 'Confirm demo payment' : 'Agree & accept')),
                ],
              )),
    );
    if (confirmed == true) await act('join', {'agree_to_pay': true});
  }

  /// A person's card: who they are and what you have in common, nothing
  /// else. Choosing not to be matched again lives in Profile, and only after
  /// the Circle has actually met.
  Future<void> _member(BuildContext context, Json member) async {
    final id = '${member['id']}';
    final name = member['name'] as String;
    final isSelf = id == '${state['profile_id']}' || id == 'you';
    final bio = (member['bio'] as String? ?? '').trim();
    // The server used to fill an empty introduction with this sentence, which
    // made everyone who had not written one sound the same.
    final hasBio =
        bio.isNotEmpty && bio != 'Looking forward to meeting the Circle.';
    final interests = strings(member['interests']);
    final mine = isSelf
        ? const <String>{}
        : strings((state['application'] as Map?)?['interests']).toSet();
    final shared = interests.where(mine.contains).toList();
    await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
                content: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        CircleMemberAvatar(name,
                            radius: 30,
                            photoUrl: member['photo_url'] as String?,
                            photoPath: member['photo_path'] as String?),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Text(name,
                                style: Theme.of(c).textTheme.headlineSmall)),
                      ]),
                      const SizedBox(height: 16),
                      if (hasBio)
                        Text('“$bio”',
                            style: const TextStyle(
                                fontStyle: FontStyle.italic, height: 1.45))
                      else
                        Text(
                            isSelf
                                ? 'You haven’t written an introduction yet.'
                                : '$name hasn’t written an introduction yet.',
                            style: const TextStyle(color: Color(0xFF66727C))),
                      if (interests.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(t('Interests').toUpperCase(),
                            style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w800,
                                color: circleTealText)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final interest in interests)
                            CirclePill(interest,
                                icon: shared.contains(interest)
                                    ? Icons.favorite_rounded
                                    : null),
                        ]),
                        if (shared.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                              'You both like ${_list(shared.map(t).toList())}.',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: circleNavy)),
                        ],
                      ],
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Close'))
                ]));
  }

  static String _list(List<String> items) => items.length == 1
      ? items.first
      : '${items.sublist(0, items.length - 1).join(', ')} ${t('and')} ${items.last}';

  /// Opens the organiser's payment request. Receipt is still confirmed by
  /// hand, so nothing about the member's state changes here — this only saves
  /// them waiting for an email with the link in it.
  /// This Circle's payment link, or the general one if it has none.
  String? get _payLink => PaymentConfig.linkFor(state['circle'] as Map?);

  /// Opens the payment link. The tap is recorded first so the organiser can
  /// match the incoming payment by name and time; a failure to record never
  /// stops someone paying.
  Future<void> _pay(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final link = _payLink;
    if (link == null) return;
    if (!demo) {
      unawaited(Future(() => act('payment_opened')).catchError((_) {}));
    }
    var launched = false;
    try {
      launched = await launchUrl(Uri.parse(link),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched) {
      showCircleToastOn(messenger,
          'We could not open the payment page. The organiser can send you the link.',
          icon: Icons.error_outline_rounded);
    }
  }

  Future<void> _decline(BuildContext context) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Look for another Circle?'),
              content: const SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        'We’ll release this invitation and put you back on the waiting list. You keep your place from the day you first applied, so you go back to the front, not the back.'),
                    SizedBox(height: 12),
                    Text(
                        'The next Circle that matches your times usually takes one to three weeks. Widening your availability is the fastest way to shorten that.',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 12),
                    Text(
                        'Nothing is charged for a declined invitation. If you have already sent payment, contact the organiser first.',
                        style: TextStyle(fontSize: 12)),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Keep invitation')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Find another Circle'))
              ],
            ));
    if (confirmed == true) await act('decline');
  }

  /// After six weeks: look for a new group as well, keeping this one.
  Widget _anotherCircle(BuildContext context) {
    final looking = state['looking_again'] == true;
    return CirclePanel(children: [
      Text(
          looking
              ? 'You’re on the list for a new Circle'
              : 'Meet a new group too?',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(looking
          ? 'We’ll invite you when a group fits your times. This Circle and its chat stay yours.'
          : 'Join another Circle with new people: six weekly meetups, €19. This Circle and its chat stay yours, and we won’t put you with the same people again.'),
      const SizedBox(height: 14),
      if (looking) ...[
        OutlinedButton(
            onPressed: busy ? null : () => onEdit(1),
            child: const Text('Check my times')),
        TextButton(
            onPressed: busy ? null : () => act('stop_looking'),
            child: const Text('Stop looking')),
      ] else
        OutlinedButton(
            onPressed: busy ? null : () => _joinAgain(context),
            child: const Text('Join a new Circle')),
    ]);
  }

  Future<void> _joinAgain(BuildContext context) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Join a new Circle?'),
              content: const Text(
                  'We’ll put you back on the waiting list with your saved answers. When a group fits, you’ll get an invitation and pay €19 for the new six weeks. You keep this Circle and its chat. Check that your days and times are still right.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Not now')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Join the waiting list')),
              ],
            ));
    if (yes == true) await act('join_again');
  }

  Future<void> _checkIn(BuildContext context, Json m) async {
    String? feeling;
    final connections = <String>{};
    final result = await showDialog<Json>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, set) => AlertDialog(
                    title: const Text('How did tonight feel?'),
                    content: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text(
                              'Just for you and the VriendTime team. Never shown to your Circle.'),
                          const SizedBox(height: 16),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final f in [
                              '😊 Great',
                              '🙂 Good',
                              '😐 Okay',
                              '🙁 Not for me'
                            ])
                              ChoiceChip(
                                  label: Text(f),
                                  selected: feeling == f,
                                  onSelected: (_) => set(() => feeling = f))
                          ]),
                          const SizedBox(height: 20),
                          const Text(
                              'Anyone you’d like to spend more time with? (Optional)'),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, children: [
                            for (final p in rows(state['members']).where((p) =>
                                p['id'] != 'you' &&
                                p['id'] != state['profile_id']))
                              FilterChip(
                                  label: Text(p['name'] as String),
                                  selected: connections.contains(p['id']),
                                  onSelected: (v) => set(() => v
                                      ? connections.add(p['id'] as String)
                                      : connections.remove(p['id'])))
                          ])
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Later')),
                      FilledButton(
                          onPressed: feeling == null
                              ? null
                              : () => Navigator.pop(c, {
                                    'id': m['id'],
                                    'feeling': feeling,
                                    'connections': connections.toList()
                                  }),
                          child: const Text('Save privately'))
                    ])));
    if (result != null) await act('check_in', result);
  }

  Widget _outcome(BuildContext context) => CirclePanel(children: [
        Text('Is this the start of a friendship?',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        const Text(
            'Tell us how things are going. You can update your answer later.'),
        const SizedBox(height: 14),
        for (final entry in {
          'plans': 'Are you planning to meet again?',
          'friend': 'Is there someone you now consider a friend?',
          'outside': 'Have you met outside the scheduled meetups?',
          if (demo || state['day90_due'] == true)
            'still_meeting':
                '${demo ? 'Preview · ' : ''}90 days on: are you still voluntarily seeing at least one Circle member?'
        }.entries) ...[
          Text(entry.value,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            for (final answer in ['Yes', 'Not yet'])
              ChoiceChip(
                  label: Text(answer),
                  selected: (state['outcome'] as Map?)?[entry.key] == answer,
                  onSelected: busy
                      ? null
                      : (_) => act('outcome', {
                            ...?state['outcome'] as Map<String, dynamic>?,
                            entry.key: answer
                          }))
          ]),
          const SizedBox(height: 12)
        ]
      ]);
}

Future<void> scheduleCircleMeetup(BuildContext context, CircleAction act,
    {Json? meetup, bool organiser = false}) async {
  await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) =>
          _ScheduleDialog(meetup: meetup, act: act, organiser: organiser));
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog(
      {this.meetup, required this.act, this.organiser = false});
  final bool organiser;
  final CircleAction act;
  final Json? meetup;
  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late final TextEditingController title, venue;
  late final TextEditingController address, meeting, costs, access;
  bool saving = false;
  final requestId = circleRequestId();
  DateTime? date;
  TimeOfDay time = const TimeOfDay(hour: 19, minute: 30);
  String? error;
  bool get fixedSchedule => !widget.organiser && widget.meetup?['week'] != null;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.meetup?['title'] as String?);
    venue = TextEditingController(text: widget.meetup?['venue'] as String?);
    address = TextEditingController(text: widget.meetup?['venue_address']);
    meeting = TextEditingController(text: widget.meetup?['meeting_point']);
    costs = TextEditingController(text: widget.meetup?['cost_notes']);
    access = TextEditingController(text: widget.meetup?['accessibility_notes']);
    date = DateTime.tryParse(widget.meetup?['date'] as String? ?? '');
    final parts = (widget.meetup?['time'] as String? ?? '19:30').split(':');
    time = TimeOfDay(
        hour: int.tryParse(parts.first) ?? 19,
        minute: int.tryParse(parts.last) ?? 30);
  }

  @override
  void dispose() {
    title.dispose();
    venue.dispose();
    address.dispose();
    meeting.dispose();
    costs.dispose();
    access.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !saving,
      child: AlertDialog(
          title: Text(fixedSchedule
              ? 'Make a plan together'
              : 'Suggest an extra meetup'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: title,
                enabled: !saving,
                maxLength: 120,
                decoration: InputDecoration(labelText: t('What shall we do?'))),
            const SizedBox(height: 12),
            TextField(
                controller: venue,
                enabled: !saving,
                maxLength: 180,
                decoration: InputDecoration(labelText: t('Where?'))),
            for (final field in {
              address: 'Address (optional)',
              meeting: 'Meeting point (optional)',
              costs: 'Costs (optional)',
              access: 'Accessibility (optional)'
            }.entries)
              TextField(
                  controller: field.key,
                  enabled: !saving,
                  maxLength: 300,
                  decoration: InputDecoration(labelText: t(field.value))),
            const Text(
                'Discuss the idea in your Circle chat first. Saving shares this plan with everyone.'),
            const SizedBox(height: 14),
            if (fixedSchedule) ...[
              Text(
                  '${circleDate(widget.meetup?["date"] as String?)} · ${widget.meetup?["time"]} · Netherlands time'),
              const SizedBox(height: 8),
              const Text(
                  'The weekly date and time are fixed. Choose the activity and place together.'),
            ] else ...[
              OutlinedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: date != null && date!.isAfter(now)
                                  ? date
                                  : now.add(const Duration(days: 1)),
                              firstDate: DateTime(now.year, now.month, now.day),
                              lastDate: now.add(const Duration(days: 730)));
                          if (picked != null && mounted) {
                            setState(() => date = picked);
                          }
                        },
                  child: Text(date == null
                      ? 'Choose a date'
                      : circleDate(date!.toIso8601String()))),
              const SizedBox(height: 10),
              OutlinedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final picked = await showTimePicker(
                              context: context, initialTime: time);
                          if (picked != null && mounted) {
                            setState(() => time = picked);
                          }
                        },
                  child: Text('${time.format(context)} · Netherlands time')),
            ],
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red))
          ])),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (title.text.trim().isEmpty ||
                            venue.text.trim().isEmpty ||
                            date == null) {
                          setState(() =>
                              error = 'Add an activity, place, and date.');
                          return;
                        }
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await widget.act('schedule', {
                            'request_id': requestId,
                            'version': widget.meetup?['plan_version'],
                            'venue_address': address.text.trim(),
                            'meeting_point': meeting.text.trim(),
                            'cost_notes': costs.text.trim(),
                            'accessibility_notes': access.text.trim(),
                            'title': title.text.trim(),
                            'venue': venue.text.trim(),
                            'date': date!.toIso8601String().split('T').first,
                            'time':
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                            if (widget.meetup != null)
                              'id': widget.meetup!['id']
                          });
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (mounted) {
                            setState(() => error = e is StateError
                                ? e.message
                                : 'Could not save. Your plan is still here. Please retry.');
                          }
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save plan'))
          ]));
}

/// Asks before withdrawing an application; true when the person confirms.
/// Lives in the profile, next to the answers it throws away.
Future<bool> confirmWithdraw(BuildContext context) async {
  final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
              title: const Text('Withdraw your application?'),
              content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'You’ll lose your place on the waiting list, and this can’t be undone.',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 12),
                    Text(
                        'We’ll stop looking for a Circle for you. If you apply again later, you’ll join at the back of the line.'),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Keep my place')),
                FilledButton(
                    style: destructiveFilledStyle,
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Withdraw'))
              ]));
  return ok == true;
}
