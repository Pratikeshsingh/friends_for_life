import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/destructive.dart';
import '../core/payment_config.dart';
import 'circle_repository.dart';
import 'circle_celebration.dart';
import 'circle_coffees.dart';
import 'circle_invite_friend.dart';
import 'circle_meetup_detail.dart';
import 'circle_widgets.dart';
import 'circle_journey.dart';
import 'circle_leave.dart';
import 'circle_preferences.dart';

typedef CircleAction = Future<void> Function(String action, [Json data]);

/// The four answers used for every "how was it?" question.
const circleFeelings = ['😊 Great', '🙂 Good', '😐 Okay', '🙁 Not for me'];

class CircleHome extends StatelessWidget {
  const CircleHome(
      {super.key,
      required this.state,
      required this.demo,
      required this.busy,
      required this.act,
      required this.onEdit,
      required this.onMessages,
      this.savePlan,
      this.outcomeKey,
      this.coffeeKey});

  /// Lets a notification scroll to the friendship check-in.
  final Key? outcomeKey;

  /// Where the one-to-ones sit, for the "answer below" line to scroll to.
  final GlobalKey? coffeeKey;
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
        const CircleHomeHeader(
            eyebrow: 'Nearly there',
            title: 'Your application is waiting for you',
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
        CircleJourney(
            compact: true,
            morning:
                circleMorningOnly(circleSlots(Map<String, dynamic>.from(app)))),
      ]);
    }
    if (stage == 'waiting') {
      final slots = circleSlots(Map<String, dynamic>.from(app));
      final wait = circleWaitEstimate(state);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleHomeHeader(
            eyebrow: 'Application received',
            title: 'You’re on the list',
            subtitle: wait.isKnown
                ? wait.progressLine
                : 'We’re finding people who share your language and a time that fits.'),
        if (state['move_credit'] == true) ...[
          const SizedBox(
              width: double.infinity,
              child: CirclePanel(tint: true, children: [
                Text('You’re moving to a new group',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: circleNavy)),
                SizedBox(height: 6),
                Text(
                    'Your €39 carries over, so your next Circle is free. We’ll invite you as soon as we find a group that fits.'),
              ])),
          const SizedBox(height: 16),
        ],
        if (state['needs_details'] == true) ...[
          SizedBox(
              width: double.infinity,
              child: CirclePanel(tint: true, children: [
                const Row(children: [
                  Icon(Icons.error_outline_rounded, color: circleCoralText),
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
        _waitCard(context, app, wait),
        // More times means a sooner match. The times themselves live in
        // Profile, so they aren't changed on a whim here.
        if (!wait.complete) ...[
          const SizedBox(height: 20),
          CirclePanel(children: [
            Row(children: [
              const Icon(Icons.more_time_rounded, color: circleTeal),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('More free time?',
                      style: Theme.of(context).textTheme.titleLarge)),
            ]),
            const SizedBox(height: 4),
            const Text('Add it, and you’ll be matched sooner.',
                style: TextStyle(color: Color(0xFF4F5D66))),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46)),
                onPressed: () => onEdit(1),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add times')),
          ]),
        ],
        const SizedBox(height: 20),
        CircleJourney(compact: true, morning: circleMorningOnly(slots)),
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
                ? 'The organiser has confirmed your €39 was returned. Contact us if it hasn’t arrived.'
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
    // Pay first: found, not started. Seats rather than people, the weeks
    // rather than dates, until the organiser books the group.
    if (state['pay_first'] is Map &&
        (state['pay_first'] as Map)['started'] != true &&
        (stage == 'invited' || stage == 'confirmed')) {
      return _payFirst(context, stage == 'confirmed');
    }
    final agreed =
        (state['payment_agreement'] as Map?)?['status'] == 'awaiting_payment';
    final invited = stage == 'invited';
    final graduated = stage == 'completed';
    // Someone who moved here already paid for their first Circle.
    final credit = state['move_credit'] == true;
    // A week before the first meetup the group is final, so the places can
    // be booked: saying yes has closed.
    final closed = invited && !agreed && _acceptClosed(state);
    final week5 = rows(state['meetups'])
        .where((m) => m['week'] == 5 && circleWeekOpen(m))
        .firstOrNull;
    final week5Soon = week5 != null &&
        (circleMeetupStart(week5)?.difference(DateTime.now()).inDays ?? 99) <=
            14;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!invited && !graduated)
        _progressHeader(context, circle, meetups)
      else if (invited)
        CircleHomeHeader(
            eyebrow: 'You’re invited',
            title: agreed ? 'Almost there' : 'Meet your Circle',
            subtitle: agreed
                ? 'Your place is held for you until the pay-by date below. Once your €39 has arrived, your Circle and its chat open.'
                : 'Look at the people and the six dates. If it works for you, say yes.')
      else
        // Finishing the six weeks deserves a moment, once.
        Stack(children: [
          CircleHeading(
              graduated
                  ? 'Six weeks together. Well done!'
                  : invited && agreed
                      ? 'Almost there.'
                      : invited
                          ? 'Meet your Circle.'
                          : 'A few familiar faces.\nA plan to look forward to.',
              eyebrow: graduated
                  ? 'Programme complete'
                  : invited
                      ? 'You’re invited'
                      : '${circle['name'] ?? 'Your Circle'} · Week ${(completed + 1).clamp(1, 6)} of 6',
              subtitle: graduated
                  ? 'The programme is done, but your Circle isn’t: the chat stays open and you can keep making plans together, at no extra cost.'
                  : invited && agreed
                      ? 'Your place is held for you until the pay-by date below. Once your €39 has arrived, your Circle and its chat open.'
                      : invited
                          ? 'Look at the people and the six dates. If it works for you, say yes.'
                          : null),
          if (graduated)
            Positioned.fill(
                child: CircleConfetti(
                    onceKey: 'graduation:${circle['id'] ?? ''}')),
        ]),
      if (invited)
        CirclePanel(tint: true, children: [
          Text(circle['name']?.toString() ?? 'Your Founding Circle',
              style: Theme.of(context).textTheme.headlineSmall),
          if (members.isNotEmpty) ...[
            const SizedBox(height: 12),
            _faces(members),
          ],
          const SizedBox(height: 16),
          _info(Icons.calendar_month_outlined,
              'Starts ${circleDate(circle['start_date']?.toString())}'),
          _info(Icons.schedule_rounded,
              circle['schedule']?.toString() ?? 'Schedule to be confirmed'),
          _info(Icons.place_outlined, circle['city']?.toString() ?? 'Alkmaar'),
          // Once closed, the old pay-by date is no use to anyone.
          if (closed)
            ...const <Widget>[]
          else if (state['pay_by'] != null && !credit)
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
          if (closed) ...[
            const SizedBox(height: 8),
            _alert('This invitation has closed',
                'Saying yes closed on ${circleDate(state['accept_until']?.toString())}, so that the places could be booked for the group. Still keen? Message us and we’ll see what we can do.'),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                    icon: const CircleWhatsAppIcon(size: 18),
                    onPressed: () => launchUrl(
                        Uri.parse('https://wa.me/31685660139'),
                        mode: LaunchMode.externalApplication),
                    label: const Text('Message us on WhatsApp'))),
          ]
          // Past the pay-by date without payment: say plainly that the
          // payment is the only thing holding the place back.
          else if (!credit && _payOverdue(state)) ...[
            const SizedBox(height: 8),
            _alert(
                agreed
                    ? 'Your €39 has not arrived yet'
                    : 'Your invitation is still open',
                agreed
                    ? 'Your place is confirmed only once your €39 arrives. Your pay-by date has passed: the place is still yours for now, but the organiser can offer it to someone on the waiting list at any time. Pay now to keep it. If you have already paid, tap “I’ve sent the payment”.'
                    : state['accept_until'] != null
                        ? 'Your pay-by date has passed. You can still say yes until ${circleDate(state['accept_until']?.toString())}, but the organiser can offer your place to someone on the waiting list at any time. Accept and pay now to keep it.'
                        : 'Your pay-by date has passed. The place is still yours for now, but the organiser can offer it to someone on the waiting list at any time. Accept and pay now to keep it.'),
          ],
          // Before deciding, people look at the group and the six dates
          // first; the answer comes after them. Once accepted, paying is the
          // next step, so it stays here at the top.
          if (agreed)
            ..._decision(context, agreed, credit)
          else if (!closed) ...[
            // Saying yes is the next step, so it is right here; the full
            // price and refund terms sit with the second button below, next
            // to the group and dates.
            const SizedBox(height: 16),
            _acceptButton(context, agreed, credit),
            const SizedBox(height: 10),
            Text(
                credit
                    ? 'Already paid from your previous Circle. The group and all six dates are below.'
                    : '€39 for all six weeks, two activities included. The group and all six dates are below.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF4F5D66))),
          ],
        ]),
      // After the six weeks: one next step first. The group and its chat
      // carry on; history, feedback and a new Circle come further down.
      if (graduated)
        CirclePanel(tint: true, children: [
          Text('Keep this Circle going.',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'Pick a day. Revisit a favourite place. It doesn’t need to be a big occasion.'),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: busy
                      ? null
                      : () => scheduleCircleMeetup(context, savePlan ?? act),
                  child: const Text('Plan our next meetup'))),
          Center(
              child: TextButton(
                  onPressed: onMessages, child: const Text('Ask the Circle'))),
        ]),
      if (!invited &&
          week5Soon &&
          upcoming?['id'] != week5['id'] &&
          circlePlanWeek5(context, savePlan ?? act, week5) != null) ...[
        const SizedBox(height: 20),
        _week5Prompt(context, week5),
      ],
      // Whatever comes first is on top: the next group meetup or a coffee.
      if (!invited && _coffeeFirst(upcoming) && state['coffees'] is Map) ...[
        const SizedBox(height: 20),
        CircleCoffees(state: state, members: members, busy: busy, act: act),
      ],
      if (!invited && upcoming != null) ...[
        const SizedBox(height: 20),
        _meetup(context, upcoming, featured: true)
      ],
      if (!invited && !_coffeeFirst(upcoming) && state['coffees'] is Map) ...[
        if (_coffeeAsk() case final ask?) ...[
          const SizedBox(height: 10),
          _coffeeNudge(ask),
        ],
        const SizedBox(height: 26),
        KeyedSubtree(
            key: coffeeKey,
            child: CircleCoffees(
                state: state, members: members, busy: busy, act: act)),
      ],
      if (state['whatsapp'] is Map &&
          (state['whatsapp'] as Map)['answer'] == null &&
          !invited) ...[
        const SizedBox(height: 26),
        _whatsApp(context),
      ],
      // After graduation: meeting a new group comes before looking back.
      if (graduated) ...[
        const SizedBox(height: 24),
        _anotherCircle(context),
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                icon: const Icon(Icons.favorite_border_rounded, size: 18),
                onPressed: () => showInviteFriend(context),
                label: const Text(
                    'Know someone who’d enjoy this? Invite a friend'))),
      ],
      const SizedBox(height: 26),
      Text('The people in your Circle',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      _peopleCard(context, members, invited),
      if (graduated) ...[
        const SizedBox(height: 24),
        KeyedSubtree(key: outcomeKey, child: _outcome(context)),
        const SizedBox(height: 16),
        // The six weeks, kept but folded: looking back, not the next step.
        Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFDDE7E3))),
            clipBehavior: Clip.antiAlias,
            child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                    leading:
                        const Icon(Icons.history_rounded, color: circleTeal),
                    title: const Text('Your six weeks',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: circleNavy)),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: [
                      _recap(meetups),
                      const SizedBox(height: 12),
                      _weekList(context, [
                        for (final m in meetups)
                          if (m['week'] != null) m
                      ]),
                    ]))),
      ],
      if (!graduated) ...[
        const SizedBox(height: 28),
        Text('Six weeks, a little closer',
            style: Theme.of(context).textTheme.headlineSmall),
        Row(children: [
          const Expanded(
              child: Text('The dates are fixed. Netherlands time.',
                  style: TextStyle(color: Color(0xFF4F5D66)))),
          TextButton.icon(
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              onPressed: () => showCircleHowItWorks(context),
              label: const Text('How it works')),
        ]),
        const SizedBox(height: 10),
        _weekList(
            context,
            [
              for (final m in meetups)
                if (m['week'] != null) m
            ],
            nextId: upcoming?['id']),
      ],
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
        if (!graduated)
          OutlinedButton(
              onPressed: busy
                  ? null
                  : () => scheduleCircleMeetup(context, savePlan ?? act),
              child: const Text('Suggest an extra meetup')),
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
        // Only in the two days after the first meetup, when people decide
        // whether the group feels right; leaving stays under Profile always.
        else if (((state['switch'] as Map?)?['available'] == true ||
                (state['move'] as Map?)?['available'] == true) &&
            _justAfterFirstMeetup(state))
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

  /// True when this member's next coffee comes before the next group meetup.
  /// A one-to-one waiting for this person's answer, if any: the other
  /// person's name and whether it's an evening (a drink) or a coffee.
  (String, bool)? _coffeeAsk() {
    final c = (state['coffees'] as Map?)?['current'];
    if (c is! Map || c['status'] == 'confirmed' || c['mine'] != null) {
      return null;
    }
    final starts = DateTime.tryParse('${c['starts_at'] ?? ''}');
    if (starts == null || starts.isBefore(DateTime.now())) return null;
    return (
      '${(c['other'] as Map?)?['name'] ?? t('Someone')}',
      circleAmsterdam(starts).hour >= 17
    );
  }

  /// One quiet line under the next meetup: a one-to-one is waiting for an
  /// answer further down. Optional, so no big card.
  Widget _coffeeNudge((String, bool) ask) => Material(
      color: const Color(0xFFFFF4E8),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            final c = coffeeKey?.currentContext;
            if (c != null) {
              Scrollable.ensureVisible(c,
                  duration: const Duration(milliseconds: 300));
            }
          },
          child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(children: [
                Icon(
                    ask.$2 ? Icons.local_drink_outlined : Icons.coffee_outlined,
                    size: 20,
                    color: circleCoralText),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        t(ask.$2
                                ? 'A drink with {1} this week? Optional: answer below.'
                                : 'A coffee with {1} this week? Optional: answer below.')
                            .replaceAll('{1}', ask.$1),
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: circleNavy))),
                const Icon(Icons.expand_more_rounded, color: Color(0xFF66727C)),
              ]))));

  bool _coffeeFirst(Json? upcoming) {
    final current = (state['coffees'] as Map?)?['current'];
    if (current is! Map) return false;
    final coffee = DateTime.tryParse('${current['starts_at'] ?? ''}');
    if (coffee == null) return false;
    final meetup = upcoming == null ? null : circleMeetupStart(upcoming);
    return meetup == null || coffee.isBefore(meetup);
  }

  static bool _justAfterFirstMeetup(Json state, {DateTime? now}) {
    final first =
        rows(state['meetups']).where((m) => m['week'] == 1).firstOrNull;
    final end = first == null ? null : circleMeetupEnd(first);
    if (end == null) return false;
    final at = (now ?? DateTime.now()).toUtc();
    return at.isAfter(end) && at.isBefore(end.add(const Duration(hours: 48)));
  }

  /// Today in the Netherlands, where the server counts its deadlines.
  static DateTime _today(DateTime? now) {
    final nl = circleAmsterdam(now ?? DateTime.now());
    return DateTime(nl.year, nl.month, nl.day);
  }

  /// After week 2: a WhatsApp group, if they'd like one. Only those who
  /// say yes are added; a yes needs a number.
  Widget _whatsApp(BuildContext context) {
    final hasPhone = (state['whatsapp'] as Map)['has_phone'] == true;
    return CirclePanel(tint: true, children: [
      Row(children: [
        const CircleWhatsAppIcon(size: 26),
        const SizedBox(width: 10),
        Expanded(
            child: Text('A WhatsApp group for your Circle?',
                style: Theme.of(context).textTheme.titleLarge)),
      ]),
      const SizedBox(height: 6),
      const Text(
          'If you like, we’ll make one next to the app. Only people who say yes are added, so your number goes only to them.',
          style: TextStyle(color: Color(0xFF4F5D66), height: 1.4)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
            child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46)),
                onPressed:
                    busy ? null : () => act('whatsapp', {'answer': 'no'}),
                child: const FittedBox(
                    fit: BoxFit.scaleDown, child: Text('No thanks')))),
        const SizedBox(width: 10),
        Expanded(
            child: FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46)),
                onPressed: busy
                    ? null
                    : hasPhone
                        ? () => act('whatsapp', {'answer': 'yes'})
                        : () => _whatsAppNumber(context),
                child: const FittedBox(
                    fit: BoxFit.scaleDown, child: Text('Yes, add me')))),
      ]),
      Center(
          child: TextButton(
              onPressed:
                  busy ? null : () => act('whatsapp', {'answer': 'have'}),
              child: const Text('We already have a group'))),
    ]);
  }

  /// A yes without a number on file: ask for it once, here.
  Future<void> _whatsAppNumber(BuildContext context) async {
    final number = TextEditingController();
    final phone = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
                scrollable: true,
                title: const Text('Your WhatsApp number'),
                content: TextField(
                    controller: number,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration:
                        InputDecoration(hintText: t('e.g. 06 12345678'))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Back')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, number.text.trim()),
                      child: const Text('Add me')),
                ]));
    // After the dialog has finished closing, not while it animates out.
    Future.delayed(const Duration(milliseconds: 500), number.dispose);
    if (phone == null || phone.isEmpty) return;
    await act('whatsapp', {'answer': 'yes', 'phone': phone});
  }

  /// A group still being found: how many seats are confirmed, the six
  /// weeks and what they cost, and (until paid) the way to pay.
  Widget _payFirst(BuildContext context, bool confirmed) {
    final pf = state['pay_first'] as Map;
    final circle = state['circle'] as Map? ?? {};
    // "Thursday evenings" (older Circles add " · English").
    final slot = '${circle['schedule'] ?? ''}'.split(' · ').first.trim();
    final agreed =
        (state['payment_agreement'] as Map?)?['status'] == 'awaiting_payment';
    final credit = state['move_credit'] == true;
    final expired = pf['expired'] == true && !confirmed;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleHomeHeader(
          eyebrow: confirmed ? 'Place confirmed' : 'We found your people',
          title: confirmed ? 'You’re in' : 'Your seat is waiting',
          subtitle: confirmed
              ? 'We’ll tell you the dates and introduce your group as soon as it’s booked.'
              : slot.isEmpty
                  ? 'Pay your €39 within 7 days to confirm your place.'
                  : t('We’ve found people for {1}. Pay your €39 within 7 days to confirm your place.')
                      .replaceAll(
                          '{1}', isDutch ? t(slot).toLowerCase() : t(slot))),
      if (expired) ...[
        _alert('Your 7 days have passed',
            'Your seat may have gone to someone else. You can still pay: if a seat is free, you’re in; if not, your €39 holds your place in the next group for your times.'),
        const SizedBox(height: 16),
      ],
      _seats(context, pf, confirmed, slot),
      if (!confirmed) ...[
        const SizedBox(height: 20),
        CirclePanel(tint: true, children: [
          const Text('€39 for all six weeks',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: circleNavy)),
          const SizedBox(height: 4),
          const Text(
              'Two activities included. Food and drinks you pay at the venue.',
              style: TextStyle(color: Color(0xFF4F5D66))),
          if (state['pay_by'] != null && !credit) ...[
            const SizedBox(height: 12),
            _info(
                Icons.hourglass_bottom_rounded,
                expired
                    ? 'You can still pay until the group starts'
                    : 'Pay by ${circleDate(state['pay_by']?.toString())}'),
          ],
          ..._decision(context, agreed, credit),
        ]),
      ],
      const SizedBox(height: 26),
      Text('Your six weeks', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      const Text(
          'The plan is the same for every group. Dates and places follow when your group is booked.',
          style: TextStyle(color: Color(0xFF4F5D66))),
      const SizedBox(height: 12),
      _programme(context),
    ]);
  }

  /// Six seats: confirmed ones filled, found ones outlined, open ones
  /// dashed. Nobody's name or face until the group is booked.
  Widget _seats(BuildContext context, Map pf, bool confirmed, String slot) {
    final total = (pf['seats'] as num?)?.toInt() ?? 6;
    final done = ((pf['confirmed'] as num?)?.toInt() ?? 0).clamp(0, total);
    final found = ((pf['found'] as num?)?.toInt() ?? done).clamp(done, total);
    Widget seat(int i) {
      final paid = i < done;
      final taken = i < found;
      return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: paid ? circleTeal : Colors.white,
              border: Border.all(
                  color: taken ? circleTeal : const Color(0xFFBFD8D2),
                  width: taken ? 2 : 1.5)),
          child: Icon(
              paid
                  ? Icons.check_rounded
                  : taken
                      ? Icons.person_rounded
                      : Icons.person_add_alt_1_outlined,
              size: 22,
              color: paid
                  ? Colors.white
                  : taken
                      ? circleTeal
                      : const Color(0xFF8FB3AB)));
    }

    return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
            color: const Color(0xFFE6F2EE),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFCFE5DE))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                    'assets/generated/meetups/meetup-hello-day.webp',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Your group',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (slot.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    CirclePill(t(slot)),
                  ],
                ])),
          ]),
          const SizedBox(height: 16),
          Semantics(
              label: t('{1} of {2} places confirmed')
                  .replaceAll('{1}', '$done')
                  .replaceAll('{2}', '$total'),
              child: ExcludeSemantics(
                  child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (var i = 0; i < total; i++) seat(i)]))),
          const SizedBox(height: 14),
          Text(
              t('{1} of {2} places confirmed')
                  .replaceAll('{1}', '$done')
                  .replaceAll('{2}', '$total'),
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: circleNavy)),
          const SizedBox(height: 4),
          Text(
              confirmed
                  ? 'Yours is one of them. Names and faces appear once your group is booked.'
                  : 'Who’s in stays private until the group is booked, for everyone.',
              style: const TextStyle(color: Color(0xFF4F5D66), height: 1.4)),
        ]));
  }

  /// The six weeks without dates: what each is, what's included, and what
  /// it usually costs, so nobody pays without knowing.
  Widget _programme(BuildContext context) {
    final weeks = rows(state['meetups'])
        .where((m) => m['week'] != null)
        .toList()
      ..sort((a, b) => (a['week'] as num).compareTo(b['week'] as num));
    return CirclePanel(children: [
      for (var i = 0; i < weeks.length; i++) ...[
        if (i > 0) const Divider(height: 22, color: Color(0xFFE3ECE9)),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleMeetupTile(weeks[i], size: 44),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${t('WEEK')} ${weeks[i]['week']}',
                    style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: circleTealText)),
                const SizedBox(height: 2),
                Text(circleMeetupTitle(weeks[i]),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: circleNavy)),
                if (weeks[i]['included'] == true) ...[
                  const SizedBox(height: 6),
                  const CircleBadge('Included in your fee',
                      icon: Icons.redeem_outlined),
                ],
                if ('${weeks[i]['cost_notes'] ?? ''}'.trim().isNotEmpty &&
                    weeks[i]['included'] != true) ...[
                  const SizedBox(height: 4),
                  Text(t('${weeks[i]['cost_notes']}'.trim()),
                      style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: Color(0xFF4F5D66))),
                ],
              ])),
        ]),
      ],
    ]);
  }

  /// The pay-by date (end of that day) has passed and the place is not paid.
  static bool _payOverdue(Json state, {DateTime? now}) {
    final due = DateTime.tryParse('${state['pay_by'] ?? ''}');
    if (due == null || state['payment'] == 'paid') return false;
    return _today(now).isAfter(due);
  }

  /// Saying yes has closed: past the last day to accept (the later of the
  /// pay-by date and a week before the first meetup). Someone who already
  /// said yes can still pay.
  static bool _acceptClosed(Json state, {DateTime? now}) {
    final until = DateTime.tryParse('${state['accept_until'] ?? ''}');
    if (until == null) return false;
    return _today(now).isAfter(until);
  }

  /// Older servers send no pay-by date: answers are due a week ahead.
  static String? _replyBy(Map circle) {
    final start = DateTime.tryParse('${circle['start_date']}');
    if (start == null) return null;
    return circleDate(
        start.subtract(const Duration(days: 7)).toIso8601String());
  }

  /// A coral box for what needs doing now.
  static Widget _alert(String title, String body) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFFEDE7),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: circleCoralText)),
        const SizedBox(height: 4),
        Text(body),
      ]));

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

  /// Pay first: the group is still being found, so there is no group or
  /// chat to promise yet, only the place.
  bool get _filling =>
      state['pay_first'] is Map &&
      (state['pay_first'] as Map)['started'] != true;

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
                  : 'Accept invitation'));

  /// Accepting, paying and declining an invitation.
  List<Widget> _decision(BuildContext context, bool agreed, bool credit) {
    final agreement = state['payment_agreement'] as Map?;
    final reported = agreement?['payment_reported_at'] != null;
    final closed = !agreed && _acceptClosed(state);
    return [
      const SizedBox(height: 20),
      if (closed)
        const Text('This invitation has closed.',
            style: TextStyle(fontWeight: FontWeight.w700))
      else if (!agreed)
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
          Text(
              _filling
                  ? 'The organiser will send you the payment link. Your place is confirmed once your €39 has arrived.'
                  : 'The organiser will send you the payment link. Your place and group chat open once your €39 has arrived.',
              style: const TextStyle(fontWeight: FontWeight.w700))
        else if (!reported) ...[
          FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: busy ? null : () => _pay(context),
              icon: const Icon(Icons.account_balance_outlined),
              label: const Text('Pay €39 with iDEAL')),
          const SizedBox(height: 8),
          Text(
              _filling
                  ? 'Pay from an account in your own name, so the organiser can match it. Your place is confirmed once it has arrived.'
                  : 'Pay from an account in your own name, so the organiser can match it. Your place and group chat open once it has arrived.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF4F5D66))),
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
              ? 'Your €39 from your previous Circle covers this one. Food and drinks are paid at the venue.'
              : 'One payment for all six weeks. Food and drinks are paid at the venue. If your Circle doesn’t feel right, we’ll help you find a way forward.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF4F5D66))),
      if (!agreed && !demo && !credit && !closed) ...[
        const SizedBox(height: 8),
        Text(
            _payLink != null
                ? 'Accept first, then pay the €39 with iDEAL.'
                : 'After you accept, the organiser sends you a payment link.',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
      TextButton(
          // Saying no is fine, but not a highlighted action: neutral grey.
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF5E6B74)),
          onPressed: busy ? null : () => _decline(context),
          child: Text(_filling
              ? 'This time doesn’t work for me'
              : 'This schedule doesn’t work for me'))
    ];
  }

  /// Everyone in the Circle at a glance, wrapping onto a second row rather
  /// than hiding the last person off-screen. You are marked as "You".
  Widget _peopleCard(BuildContext context, List<Json> members, bool invited) =>
      CirclePanel(children: [
        // Balanced rows (six people: three and three, five: three and two),
        // aligned left, so everyone looks equally part of the group.
        LayoutBuilder(builder: (context, box) {
          // A compact block on wide screens; the full width on a phone.
          final room = math.min(box.maxWidth, 420.0);
          final min = 64 *
              (MediaQuery.textScalerOf(context).scale(13) / 13).clamp(1.0, 1.6);
          final n = members.length;
          var cols = n > 4 ? (n + 1) ~/ 2 : n;
          if (cols > 0 && (room - 6 * (cols - 1)) / cols < min) {
            cols = ((room + 6) / (min + 6)).floor().clamp(1, 6);
          }
          // Each tile takes exactly its share of the row, so a row holds
          // [cols] people on any screen width, left-aligned: 3 + 3, 3 + 2.
          final width = cols == 0
              ? min
              : ((room - 6 * (cols - 1)) / cols).floorToDouble();
          return Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                  width: room,
                  child: Wrap(spacing: 6, runSpacing: 10, children: [
                    for (var i = 0; i < members.length; i++)
                      InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _member(context, members[i]),
                          child: SizedBox(
                              width: math.min(width.toDouble(), box.maxWidth),
                              child: Column(children: [
                                const SizedBox(height: 4),
                                CircleMemberAvatar(members[i]['name'] as String,
                                    index: i,
                                    radius: 24,
                                    photoUrl:
                                        members[i]['photo_url'] as String?,
                                    photoPath:
                                        members[i]['photo_path'] as String?),
                                const SizedBox(height: 6),
                                Text(
                                    '${members[i]['id']}' ==
                                            '${state['profile_id']}'
                                        ? t('You')
                                        : members[i]['name'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                              ]))),
                  ])));
        }),
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
      // Week 5 is the group's own; we plan and book the rest.
      final groupPlans = !done && week == 5;
      final open = '${m['venue'] ?? ''}'.trim().isEmpty;
      final checked = checks.any((c) => c['id'] == m['id']);
      // Each week's picture: faded with a tick once done, ringed when next.
      final tile = SizedBox(
          width: 44,
          height: 44,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
                padding: EdgeInsets.all(next ? 2 : 0),
                decoration: next
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: circleCoral, width: 2))
                    : null,
                child: Opacity(
                    opacity: done ? .55 : 1,
                    child: CircleMeetupTile(m, size: next ? 36 : 44))),
            if (done)
              Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                          color: circleTeal,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.check_rounded,
                          size: 12, color: Colors.white))),
          ]));
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
            child: Text(open ? 'Plan it' : 'Change'));
      }
      return InkWell(
          onTap: () => openCircleMeetup(context, m,
              onPlan: circlePlanWeek5(context, savePlan ?? act, m,
                  invited: invited)),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                tile,
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          [
                            t('Week $week'),
                            if (next) t('Next'),
                          ].join(' · ').toUpperCase(),
                          style: TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 1.3,
                              fontWeight: FontWeight.w800,
                              color: next ? circleCoralText : circleTealText)),
                      const SizedBox(height: 2),
                      Text(circleMeetupTitle(m),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color:
                                  done ? const Color(0xFF66727C) : circleNavy)),
                      const SizedBox(height: 2),
                      Text(
                          [
                            circleMeetupWhen(m),
                            // The "Plan it" button says it already.
                            if (groupPlans && invited) 'Your group plans this',
                            // Unless the cost line already says so.
                            if (!done &&
                                m['included'] == true &&
                                !'${m['cost_notes'] ?? ''}'
                                    .toLowerCase()
                                    .contains('included'))
                              'Included in your fee',
                          ].join(' · '),
                          style: TextStyle(
                              fontSize: 13,
                              color: next
                                  ? circleCoralText
                                  : const Color(0xFF66727C),
                              fontWeight:
                                  next ? FontWeight.w700 : FontWeight.w500)),
                      // What it costs, in full, before anyone says yes: this
                      // is what people decide on, so never cut short.
                      if (invited &&
                          !done &&
                          '${m['cost_notes'] ?? ''}'.trim().isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                      padding:
                                          EdgeInsets.only(top: 1, right: 4),
                                      child: Icon(Icons.euro_rounded,
                                          size: 13, color: Color(0xFF4F5D66))),
                                  Expanded(
                                      child: Text(
                                          t('${m['cost_notes']}'.trim()),
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              height: 1.35,
                                              color: Color(0xFF4F5D66)))),
                                ])),
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
            if (i > 0) const Divider(height: 1, indent: 74),
            row(weeks[i]),
            // Round n of one-to-ones follows group meetup n + 1, in the days
            // before the next one. Only for members: the invitation says it
            // once, above the list.
            if (!invited && (weeks[i]['week'] as int? ?? 0) >= 2)
              _coffeeRow((weeks[i]['week'] as int) - 1,
                  from: _dayAfter(weeks[i]['date'], 1),
                  to: i + 1 < weeks.length
                      ? _dayAfter(weeks[i + 1]['date'], -1)
                      : _dayAfter(weeks[i]['date'], 7)),
          ],
        ]));
  }

  /// A slim line between the weeks: the one-to-one coffee of that round.
  static String? _dayAfter(Object? date, int days) {
    final d = DateTime.tryParse('${date ?? ''}');
    return d == null
        ? null
        : DateTime(d.year, d.month, d.day + days).toIso8601String();
  }

  /// One round of one-to-ones, between two group meetups: set apart from
  /// the weeks, with the days it falls in, or who and when once suggested.
  Widget _coffeeRow(int round, {String? from, String? to}) {
    final coffees = state['coffees'] is Map
        ? Map<String, dynamic>.from(state['coffees'] as Map)
        : const <String, dynamic>{};
    final info =
        rows(coffees['rounds']).where((r) => r['round'] == round).firstOrNull;
    final coffee = info?['coffee'] is Map
        ? Map<String, dynamic>.from(info!['coffee'] as Map)
        : null;
    final start = DateTime.tryParse('${coffee?['starts_at'] ?? ''}');
    final met = coffee?['status'] == 'confirmed' &&
        start != null &&
        start.isBefore(DateTime.now());
    final evening = circleOneToOneEvening(coffee?['starts_at']);
    // Its window is over (always, after graduation): it happened or it
    // didn't; "optional" no longer applies.
    final over = state['stage'] == 'completed' ||
        (DateTime.tryParse(to ?? '')
                ?.add(const Duration(days: 1))
                .isBefore(DateTime.now()) ??
            false);
    final String text;
    if (coffee != null && (met || !over)) {
      text = '${circleOneToOneWith(coffee['starts_at'], '${coffee['name']}')}'
          '${start == null ? '' : ' · ${circleCoffeeWhen(coffee['starts_at'])}'}'
          '${coffee['status'] == 'asked' ? ' · ${t('waiting for answers')}' : ''}';
    } else if (info?['decided'] == true || over) {
      text = t('No one-to-one this time');
    } else if (info != null) {
      text = t('Optional one-to-one · being planned');
    } else if (from != null && to != null) {
      final a = circleDate(from), b = circleDate(to);
      final sameMonth = a.split(' ').last == b.split(' ').last;
      text = t('Optional one-to-one · {1} – {2}')
          .replaceAll('{1}', sameMonth ? a.substring(0, a.lastIndexOf(' ')) : a)
          .replaceAll('{2}', b);
    } else {
      text = t('Optional one-to-one');
    }
    // A light line between two weeks, indented under the week markers.
    return Padding(
        padding: const EdgeInsets.fromLTRB(74, 0, 16, 12),
        child: Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
                border: Border(
                    left: BorderSide(color: Color(0xFFE6D9C6), width: 2))),
            child: Row(children: [
              Icon(
                  met
                      ? Icons.check_circle_rounded
                      : coffee == null
                          ? Icons.people_outline_rounded
                          : evening
                              ? Icons.local_drink_outlined
                              : Icons.coffee_outlined,
                  size: 17,
                  color: met ? circleTeal : const Color(0xFF8A6A45)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(text,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF5E5348)))),
            ])));
  }

  /// The group in one glance: their faces, slightly overlapping, and how
  /// many there are beside them (or below, when there's no room).
  Widget _faces(List<Json> members) {
    const r = 19.0, step = 28.0;
    final shown = members.take(6).toList();
    return Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
              height: r * 2 + 4,
              width: step * (shown.length - 1) + r * 2 + 4,
              child: Stack(children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                      left: step * i,
                      child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: CircleMemberAvatar('${shown[i]['name'] ?? ''}',
                              index: i,
                              radius: r,
                              photoUrl: shown[i]['photo_url'] as String?,
                              photoPath: shown[i]['photo_path'] as String?))),
              ])),
          Text(
              t('{1} people, including you')
                  .replaceAll('{1}', '${members.length}'),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: circleNavy)),
        ]);
  }

  /// The wait at a glance: a picture of the table, the seats around it
  /// filling up (you are the first), and where the application stands.
  Widget _waitCard(BuildContext context, Map app, CircleWaitEstimate wait) {
    const seats = CircleWaitEstimate.groupSize;
    final filled = wait.isKnown ? wait.ready : 1;
    final step = wait.complete ? 2 : 1;
    return Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: const Color(0xFFE6F2EE),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFCFE5DE))),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The first coffee, in the same style as the six weeks.
                    Row(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                              'assets/generated/meetups/meetup-hello-day.webp',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Your group',
                                style: Theme.of(context).textTheme.titleLarge),
                            if (wait.isKnown) ...[
                              const SizedBox(height: 6),
                              CirclePill(t(wait.slotPhrase)),
                            ],
                          ])),
                    ]),
                    const SizedBox(height: 14),
                    // Five seats: you in the first, the rest filling up.
                    // Without a count from the server, no seats: empty ones
                    // would claim a number we don't know.
                    if (wait.isKnown)
                      Semantics(
                          label: wait.isKnown
                              ? t('{1} of {2} people found')
                                  .replaceAll('{1}', '$filled')
                                  .replaceAll('{2}', '$seats')
                              : null,
                          child: ExcludeSemantics(
                              child: Row(children: [
                            for (var i = 0; i < seats; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                  child: AspectRatio(
                                      aspectRatio: 1,
                                      child: i == 0
                                          ? CircleMemberAvatar(
                                              app['name']?.toString() ?? 'You',
                                              photoUrl:
                                                  app['photo_url'] as String?,
                                              photoPath:
                                                  app['photo_path'] as String?,
                                              radius: 26)
                                          : i < filled
                                              ? Container(
                                                  decoration: const BoxDecoration(
                                                      color: circleTeal,
                                                      shape: BoxShape.circle),
                                                  child: const Icon(
                                                      Icons.person_rounded,
                                                      color: Colors.white))
                                              : Container(
                                                  decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: .7),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: const Color(
                                                              0xFFB9D8CF),
                                                          width: 1.5)),
                                                  child: const Icon(
                                                      Icons.person_add_alt_1_outlined,
                                                      size: 20,
                                                      color: Color(0xFF8BB5AA))))),
                            ],
                          ]))),
                    if (wait.isKnown) ...[
                      const SizedBox(height: 14),
                      Text(wait.headline,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: circleNavy)),
                      const SizedBox(height: 2),
                    ],
                    Text(wait.estimate,
                        style: const TextStyle(color: Color(0xFF4F5D66))),
                    const SizedBox(height: 18),
                    // Where the application stands, left to right: three
                    // equal steps whose labels may wrap on small screens.
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (i, label) in [
                            'Applied',
                            'Finding people',
                            'Invitation'
                          ].indexed)
                            Expanded(
                                child: Column(children: [
                              Row(children: [
                                Expanded(
                                    child: Container(
                                        height: 2,
                                        color: i == 0
                                            ? Colors.transparent
                                            : i <= step
                                                ? circleTeal
                                                : const Color(0xFFB9D8CF))),
                                Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                        color: i < step
                                            ? circleTeal
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: i <= step
                                                ? circleTeal
                                                : const Color(0xFFB9D8CF),
                                            width: 2)),
                                    child: i < step
                                        ? const Icon(Icons.check_rounded,
                                            size: 14, color: Colors.white)
                                        : i == step
                                            ? const Center(
                                                child: CircleAvatar(
                                                    radius: 4,
                                                    backgroundColor:
                                                        circleCoral))
                                            : null),
                                Expanded(
                                    child: Container(
                                        height: 2,
                                        color: i == 2
                                            ? Colors.transparent
                                            : i < step
                                                ? circleTeal
                                                : const Color(0xFFB9D8CF))),
                              ]),
                              const SizedBox(height: 6),
                              Text(label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      height: 1.25,
                                      fontWeight: i == step
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: i <= step
                                          ? circleNavy
                                          : const Color(0xFF66727C))),
                            ])),
                        ]),
                    const SizedBox(height: 16),
                    Text(
                        '${wait.daysWaiting == null ? '' : '${_waitedFor(wait.daysWaiting!)} '}No payment is due yet.',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF66727C))),
                  ])),
        ]));
  }

  /// The six weeks in one line: each week's picture, ticked, and what
  /// you did together.
  Widget _recap(List<Json> meetups) {
    final weeks = [
      for (var w = 1; w <= 6; w++)
        meetups.where((m) => m['week'] == w).firstOrNull ??
            {'week': w, 'time': '20:00'}
    ];
    final met = strings((state['coffees'] as Map?)?['met']).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ExcludeSemantics(
          child: Row(children: [
        for (var i = 0; i < 6; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
              child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                      builder: (context, box) =>
                          Stack(clipBehavior: Clip.none, children: [
                            CircleMeetupTile(weeks[i], size: box.maxWidth),
                            Positioned(
                                right: -3,
                                bottom: -3,
                                child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                        color: circleTeal,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2)),
                                    child: const Icon(Icons.check_rounded,
                                        size: 11, color: Colors.white))),
                          ])))),
        ],
      ])),
      const SizedBox(height: 10),
      Text(
          met == 0
              ? t('Six meetups together')
              : t('Six meetups together · {1} one-to-ones')
                  .replaceAll('{1}', '$met'),
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: Color(0xFF4F5D66))),
    ]);
  }

  /// Where the six weeks stand: the Circle, the week, six small steps.
  /// Members come back for what's next, so this stays short.
  Widget _progressHeader(BuildContext context, Map circle, List<Json> meetups) {
    final past = meetups
        .where((m) => m['week'] is int && circleMeetupPast(m))
        .length
        .clamp(0, 6);
    final current = (past + 1).clamp(1, 6);
    return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${circle['name'] ?? t('Your Circle')}'.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  color: circleTealText)),
          const SizedBox(height: 8),
          Text('Week $current of 6',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          // The done weeks fill in one after another; the current one follows.
          ExcludeSemantics(
              child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Row(children: [
                        for (var i = 1; i <= 6; i++) ...[
                          if (i > 1) const SizedBox(width: 6),
                          Expanded(
                              child: Container(
                                  height: 6,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                      // Weeks to come: a visible neutral, not
                                      // white on cream.
                                      color: const Color(0xFFE3DDD3),
                                      borderRadius: BorderRadius.circular(3)),
                                  child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                          widthFactor: i <= past
                                              ? (v * (past + 1) - (i - 1))
                                                  .clamp(0.0, 1.0)
                                              : i == current
                                                  ? (v * (past + 1) - past)
                                                      .clamp(0.0, 1.0)
                                                  : 0,
                                          heightFactor: 1,
                                          child: ColoredBox(
                                              // Done in teal, this week
                                              // in navy: coral reads as
                                              // a warning.
                                              color: i <= past
                                                  ? circleTeal
                                                  : circleNavy))))),
                        ],
                      ]))),
          const SizedBox(height: 8),
        ]));
  }

  /// Week 5 isn't planned yet: a nudge on top of Home, like the coffees.
  Widget _week5Prompt(BuildContext context, Json m) {
    final (from, to) = circleWeek5Window(m);
    return CirclePanel(tint: true, children: [
      Row(children: [
        CircleMeetupTile(m, size: 48),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Week 5 is your group’s call',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: circleNavy)),
          const SizedBox(height: 2),
          Text(circleMeetupWhen(m),
              style: const TextStyle(color: Color(0xFF66727C))),
        ])),
      ]),
      const SizedBox(height: 12),
      Text(
          t('Nothing is planned yet. Talk it over in the chat, then choose what to do, where, and a start between {1} and {2}.')
              .replaceAll('{1}', from)
              .replaceAll('{2}', to)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
            child: CircleQuickAction(
                primary: true,
                icon: Icons.edit_calendar_outlined,
                label: 'Plan it together',
                onPressed: busy
                    ? null
                    : circlePlanWeek5(context, savePlan ?? act, m))),
        const SizedBox(width: 8),
        CircleQuickAction(
            icon: Icons.chat_outlined, label: 'Chat', onPressed: onMessages),
      ]),
    ]);
  }

  Widget _meetup(BuildContext context, Json m, {bool featured = false}) {
    final week = m['week'] as int?;
    final done = circleMeetupPast(m);
    final checks = rows(state['check_ins']);
    final checked = checks.any((c) => c['id'] == m['id']);
    final invited = state['stage'] == 'invited';
    final toPlan = circleWeekOpen(m);
    final plan = circlePlanWeek5(context, savePlan ?? act, m, invited: invited);
    final location = circleVenueLabel(m);
    final placeKnown = !(location.startsWith('Revealed') ||
        location == 'Location to be confirmed' ||
        location == 'Your group picks the place');
    final address = '${m['venue_address'] ?? ''}'.trim();
    void details() => openCircleMeetup(context, m, onPlan: plan);
    Future<void> directions() async {
      final uri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${address.isNotEmpty ? address : location}, Alkmaar'
      });
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    final running = !done &&
        !invited &&
        week != null &&
        circleRunningLateWindow(
            m['starts_at'] ?? circleMeetupStart(m)?.toIso8601String());
    final (from, to) = circleWeek5Window(m);
    return CirclePanel(tint: featured, children: [
      Row(children: [
        Expanded(
            child: Text(
                [
                  if (featured) t('Next meetup'),
                  if (week != null) t('Week $week') else t('Another plan'),
                ].join(' · ').toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w800,
                    color: circleTealText))),
        if (done)
          const Icon(Icons.check_circle_rounded, color: circleTeal, size: 21)
      ]),
      const SizedBox(height: 12),
      // The kind of meetup, its name and when, at a glance.
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleMeetupTile(m, size: featured ? 56 : 46),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(circleMeetupTitle(m),
              style: featured
                  ? Theme.of(context).textTheme.headlineSmall
                  : Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(circleMeetupWhen(m),
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF4F5D66))),
        ])),
      ]),
      if (!done && (toPlan || m['included'] == true)) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (toPlan)
            const CircleBadge('Your call: plan it together',
                icon: Icons.groups_rounded,
                background: Color(0xFFE2EEF8),
                foreground: circleNavy),
          if (m['included'] == true)
            const CircleBadge('Included in your fee',
                icon: Icons.redeem_rounded),
        ]),
      ],
      if (featured || week == null) ...[
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.place_outlined, size: 20, color: circleTeal),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(t(location),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: circleNavy)),
                if (placeKnown && address.isNotEmpty)
                  Text(address,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF66727C))),
              ])),
        ]),
        if (!done && '${m['booking_name'] ?? ''}'.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _info(
              Icons.table_restaurant_outlined,
              t('Table booked under “{1}”')
                  .replaceAll('{1}', '${m['booking_name']}'.trim())),
        ],
        if (toPlan) ...[
          const SizedBox(height: 10),
          Text(
              t('Talk it over in the chat, then choose what to do, where, and a start between {1} and {2}.')
                  .replaceAll('{1}', from)
                  .replaceAll('{2}', to)),
        ],
        const SizedBox(height: 14),
        // The one thing to do now, then everything else side by side.
        if (running || (plan != null && !done)) ...[
          SizedBox(
              width: double.infinity,
              child: running
                  ? CircleQuickAction(
                      primary: true,
                      icon: Icons.directions_run_rounded,
                      label: 'Running late',
                      onPressed: busy
                          ? null
                          : () => showRunningLate(context, act,
                              kind: 'meetup', id: m['id'] as Object))
                  : CircleQuickAction(
                      primary: true,
                      icon: Icons.edit_calendar_outlined,
                      label: toPlan ? 'Plan it together' : 'Change the plan',
                      onPressed: busy ? null : plan)),
          const SizedBox(height: 8),
        ],
        CircleActionRow([
          if (toPlan && !invited)
            (icon: Icons.chat_outlined, label: 'Chat', onTap: onMessages),
          if (placeKnown && !done)
            (
              icon: Icons.directions_outlined,
              label: 'Directions',
              onTap: directions
            ),
          if (!done && !toPlan && circleMeetupStart(m) != null)
            (
              icon: Icons.event_rounded,
              label: 'Calendar',
              onTap: () => showCircleCalendarSheet(context,
                  event: m,
                  appleLink: m['id'] == null
                      ? null
                      : circleCalendarLink(meetupId: '${m['id']}'),
                  fileName: 'vriendtime-meetup.ics')
            ),
          (icon: Icons.arrow_forward_rounded, label: 'Details', onTap: details),
        ]),
        // Programme weeks need no sign-up; week 5 first needs a plan.
        if (week != null && !toPlan && !done) ...[
          const SizedBox(height: 12),
          Text(
              week == 1
                  ? 'Everyone is new at the first meetup. No need to sign up. Can’t make it? Tell your Circle in the chat.'
                  : 'No need to sign up. Can’t make it? Tell your Circle in the chat.',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF66727C), height: 1.4)),
        ],
        if (week == null) ...[
          const SizedBox(height: 14),
          CirclePill(
              '${m['confirmed'] ?? 0}/${rows(state['members']).length} confirmed',
              icon: Icons.people_outline),
          const SizedBox(height: 14),
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
      ] else
        TextButton(
            onPressed: details, child: const Text('View meetup details')),
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
                                scrollable: true,
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
      if (circleWeekNote(m) case final note? when !featured) ...[
        const SizedBox(height: 8),
        Text(note)
      ],
      if (done && !invited) ...[
        const SizedBox(height: 10),
        TextButton(
            onPressed: busy ? null : () => _checkIn(context, m),
            child: Text(checked
                ? 'Your private check-in is saved ✓'
                : 'How did this meetup feel?'))
      ],
    ]);
  }

  Future<void> _checkout(BuildContext context) async {
    bool agreed = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, update) => AlertDialog(
                scrollable: true,
                title: Text(demo
                    ? 'Try joining your Circle'
                    : 'Accept your invitation'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (demo)
                    const Text(
                        'Preview checkout · €39 one-off. No money is collected in this preview.')
                  else ...[
                    // Short points, the fee first, instead of one paragraph.
                    const Text('€39 once, for all six weeks',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: circleNavy)),
                    const SizedBox(height: 4),
                    const Text(
                        'Two activities included. Food and drinks you pay at the venue.',
                        style: TextStyle(color: Color(0xFF4F5D66))),
                    const SizedBox(height: 14),
                    for (final (icon, line) in [
                      (
                        Icons.account_balance_outlined,
                        _payLink != null
                            ? 'After you accept, you can pay straight away with iDEAL.'
                            : 'The organiser will send you a payment link. During this pilot the link comes from the organiser’s own bunq or Tikkie, so you’ll see their name when you pay.'
                      ),
                      (
                        Icons.verified_outlined,
                        'Your place is confirmed when payment is received.'
                      ),
                      (
                        Icons.undo_rounded,
                        _filling
                            ? 'Until your group is booked, you can still cancel for a full refund.'
                            : 'You can leave and ask for a refund up to 48 hours before your first meetup.'
                      ),
                      (
                        Icons.swap_horiz_rounded,
                        'Not the right group or time? You can switch to another group once, free of charge, until your second meetup.'
                      ),
                    ])
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, size: 18, color: circleTeal),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(line,
                                        style: const TextStyle(height: 1.4))),
                              ])),
                  ],
                  // Saying yes isn't the last step: the money has to arrive
                  // in time for the places to be booked.
                  if (!demo && state['pay_by'] != null) ...[
                    const SizedBox(height: 10),
                    Text(
                        _filling
                            ? t('Please pay by {1} to keep your seat.')
                                .replaceAll('{1}',
                                    circleDate(state['pay_by']?.toString()))
                            : 'Please pay by ${circleDate(state['pay_by']?.toString())}, so the places can be booked for your group.',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                  if (!demo)
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: agreed,
                        onChanged: (value) =>
                            update(() => agreed = value == true),
                        title: const Text(
                            'I agree to pay the one-off €39 programme fee.')),
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
                scrollable: true,
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
              scrollable: true,
              title: const Text('Look for another Circle?'),
              content: const Text(
                  'You go back on the waiting list, keeping your place from the day you applied. More times means a sooner match.'),
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
          : 'Join another Circle with new people: six weekly meetups, €39. This Circle and its chat stay yours, and we won’t put you with the same people again.'),
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
              scrollable: true,
              title: const Text('Join a new Circle?'),
              content: const Text(
                  'We’ll put you back on the waiting list with your saved answers. When a group fits, you’ll get an invitation and pay €39 for the new six weeks. You keep this Circle and its chat. Check that your days and times are still right.'),
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

  Future<void> _checkIn(BuildContext context, Json m) =>
      showCircleCheckIn(context, m, state, act);

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
                '${demo ? 'Preview · ' : ''}90 days on: do you still meet anyone from your Circle?'
        }.entries) ...[
          Text(entry.value,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            for (final answer in ['Yes', 'Not yet', 'No'])
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

/// The rules of the six weeks in one place, behind "How it works", so Home
/// itself stays short.
Future<void> showCircleHowItWorks(BuildContext context) => showModalBottomSheet<
        void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('How the six weeks work',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              for (final (icon, title, body) in [
                (
                  Icons.event_available_rounded,
                  'Fixed dates',
                  'One meetup a week on your Circle’s day, six weeks in a row. Times are Netherlands time.'
                ),
                (
                  Icons.bookmark_added_outlined,
                  'We plan and book',
                  'Every week except week 5: we choose the place and reserve it.'
                ),
                (
                  Icons.redeem_rounded,
                  'Two activities included',
                  'Paid from your fee. Food and drinks are always on you.'
                ),
                (
                  Icons.groups_rounded,
                  'Week 5 is your group’s',
                  'Together you choose what to do, where, and the start time.'
                ),
                (
                  Icons.people_outline_rounded,
                  'Optional one-to-ones',
                  'Between meetups we suggest meeting one person from your Circle: a coffee by day, a drink in the evening. Saying no is always fine.'
                ),
              ])
                Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFE4F1EE),
                                  borderRadius: BorderRadius.circular(12)),
                              child:
                                  Icon(icon, size: 20, color: circleTealText)),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: circleNavy)),
                                const SizedBox(height: 2),
                                Text(body,
                                    style: const TextStyle(
                                        color: Color(0xFF4F5D66), height: 1.4)),
                              ])),
                        ])),
            ]))));

/// The week 5 plan for members (not invitees), from the week list, the
/// meetup card and the meetup's details.
VoidCallback? circlePlanWeek5(BuildContext context, CircleAction act, Json m,
        {bool invited = false}) =>
    !invited && m['week'] == 5 && !circleMeetupPast(m)
        ? () => scheduleCircleMeetup(context, act, meetup: m)
        : null;

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
  late final TextEditingController address, meeting, costs, access, booking;
  bool saving = false;

  /// The four optional fields stay folded until someone wants them, so a
  /// simple plan looks like a small task. Open when one already has text.
  late bool details = widget.organiser ||
      [address, meeting, costs, access].any((c) => c.text.trim().isNotEmpty);
  final requestId = circleRequestId();
  DateTime? date;
  TimeOfDay time = const TimeOfDay(hour: 19, minute: 30);
  String? error;

  /// Organisers decide whether a change is worth an email to everyone.
  bool notify = true;
  bool get fixedSchedule => !widget.organiser && widget.meetup?['week'] != null;

  String _clock(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Week 5's possible starts, every half hour within its part of the day
  /// (the server checks the same): evenings 18:00–21:00, afternoons
  /// 12:00–16:00, mornings 09:00–11:30.
  List<String> get _starts {
    int minutes(String clock) =>
        int.parse(clock.split(':').first) * 60 +
        int.parse(clock.split(':').last);
    final window = circleWeek5Window(widget.meetup ?? const {'time': '19:30'});
    final (from, to) = (minutes(window.$1), minutes(window.$2));
    return [
      for (var m = from; m <= to; m += 30)
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}'
    ];
  }

  /// Week 5 the group hasn't planned yet: nothing to change, only to plan.
  bool get firstPlan =>
      !widget.organiser &&
      widget.meetup != null &&
      circleWeekOpen(widget.meetup!);

  @override
  void initState() {
    super.initState();
    // A first plan starts empty: "Your call" and "Up to your group." are
    // placeholders, not a plan anyone would want saved.
    title = TextEditingController(
        text: firstPlan ? '' : widget.meetup?['title'] as String?);
    venue = TextEditingController(text: widget.meetup?['venue'] as String?);
    address = TextEditingController(text: widget.meetup?['venue_address']);
    meeting = TextEditingController(text: widget.meetup?['meeting_point']);
    costs = TextEditingController(
        text: firstPlan ? '' : widget.meetup?['cost_notes'] as String?);
    access = TextEditingController(text: widget.meetup?['accessibility_notes']);
    booking = TextEditingController(text: widget.meetup?['booking_name']);
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
    booking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = Text(widget.organiser && widget.meetup != null
        ? 'Edit the plan'
        : firstPlan
            ? 'Plan it together'
            : fixedSchedule
                ? 'Change the plan together'
                : 'Suggest an extra meetup');
    final body = Column(mainAxisSize: MainAxisSize.min, children: [
      // Long enough limits; a counter under every field only adds noise.
      TextField(
          controller: title,
          enabled: !saving,
          maxLength: 120,
          decoration: InputDecoration(
              labelText: t('What shall we do?'),
              hintText: t('e.g. bowling or a pub quiz'),
              counterText: '')),
      const SizedBox(height: 12),
      TextField(
          controller: venue,
          enabled: !saving,
          maxLength: 180,
          decoration: InputDecoration(
              labelText: t('Where?'),
              hintText: t('The name of the place'),
              counterText: '')),
      if (!widget.organiser) ...[
        const SizedBox(height: 12),
        const Text(
            'Talk it over in the chat first. Saving updates the plan for everyone. Does the place take reservations? Then one of you books it.'),
      ],
      const SizedBox(height: 14),
      if (fixedSchedule) ...[
        Text(
            '${circleDate(widget.meetup?["date"] as String?)} · Netherlands time'),
        const SizedBox(height: 8),
        Text(t('The day stays the same. Choose a start between {1} and {2}.')
            .replaceAll('{1}', _starts.first)
            .replaceAll('{2}', _starts.last)),
        const SizedBox(height: 8),
        // Equal, fixed-size times without a checkmark: choosing one
        // changes only its colour, so nothing reflows or jumps.
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final start in _starts)
            ChoiceChip(
                showCheckmark: false,
                labelPadding: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? circleNavy
                        : Colors.white),
                labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _clock(time) == start ? Colors.white : circleNavy),
                label: SizedBox(
                    width: 64,
                    child: Text(start,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false)),
                selected: _clock(time) == start,
                onSelected: saving
                    ? null
                    : (_) => setState(() => time = TimeOfDay(
                        hour: int.parse(start.split(':').first),
                        minute: int.parse(start.split(':').last)))),
        ]),
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
                        context: context,
                        initialTime: time,
                        builder: (c, child) => MediaQuery(
                            data: MediaQuery.of(c)
                                .copyWith(alwaysUse24HourFormat: true),
                            child: child!));
                    if (picked != null && mounted) {
                      setState(() => time = picked);
                    }
                  },
            child: Text(
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} · ${t('Netherlands time')}')),
        if (widget.organiser && widget.meetup?['week'] != null) ...[
          const SizedBox(height: 6),
          const Text(
              'Keep the start within the Circle’s part of the day: morning 09:00–11:30, afternoon 12:00–16:00, evening 18:00–21:00.',
              style: TextStyle(fontSize: 12, color: Color(0xFF66727C))),
        ],
      ],
      const SizedBox(height: 16),
      if (!details)
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4)),
                onPressed: saving ? null : () => setState(() => details = true),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add details: address, costs and more')))
      else
        const Align(
            alignment: Alignment.centerLeft,
            child: Text('Optional details',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF66727C)))),
      if (details)
        for (final field in {
          address: 'Address (optional)',
          meeting: 'Meeting point (optional)',
          costs: 'Costs (optional)',
          access: 'Accessibility (optional)'
        }.entries)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                  controller: field.key,
                  enabled: !saving,
                  maxLength: 300,
                  decoration: InputDecoration(
                      labelText: t(field.value), counterText: ''))),
      if (widget.organiser && widget.meetup?['week'] != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
                controller: booking,
                enabled: !saving,
                maxLength: 120,
                decoration: InputDecoration(
                    labelText: t('Table booked under (optional)'),
                    counterText: ''))),
      if (widget.organiser && widget.meetup != null)
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: notify,
            onChanged:
                saving ? null : (v) => setState(() => notify = v ?? true),
            title: const Text('Let members know by email'),
            subtitle:
                const Text('Leave this off for small fixes, like a typo.')),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red))
    ]);
    final cancel = TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'));
    final save = FilledButton(
        onPressed: saving
            ? null
            : () async {
                if (title.text.trim().isEmpty ||
                    venue.text.trim().isEmpty ||
                    date == null) {
                  setState(() => error = 'Add an activity, place, and date.');
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
                    if (widget.meetup != null) 'id': widget.meetup!['id'],
                    if (widget.organiser && !notify) 'notify': false,
                    if (widget.organiser && widget.meetup?['week'] != null)
                      'booking': booking.text.trim(),
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
        child: Text(saving ? 'Saving…' : 'Save plan'));
    // A long form gets a whole page on a phone, with Save always in reach;
    // a dialog only where there's room for one.
    if (MediaQuery.sizeOf(context).width >= 600) {
      return PopScope(
          canPop: !saving,
          child: AlertDialog(
              scrollable: true,
              title: heading,
              content: SingleChildScrollView(child: body),
              actions: [cancel, save]));
    }
    return PopScope(
        canPop: !saving,
        child: Dialog.fullscreen(
            child: Scaffold(
                appBar:
                    AppBar(automaticallyImplyLeading: false, title: heading),
                body: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: body),
                bottomNavigationBar: SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(children: [
                          Expanded(child: cancel),
                          const SizedBox(width: 10),
                          Expanded(child: save),
                        ]))))));
  }
}

/// Asks before withdrawing an application; true when the person confirms.
/// Lives in the profile, next to the answers it throws away.
Future<bool> confirmWithdraw(BuildContext context) async {
  final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
              scrollable: true,
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

/// The private check-in after a meetup. Also opened from a notification or
/// an email link.
Future<void> showCircleCheckIn(
    BuildContext context, Json m, Json state, CircleAction act) async {
  String? feeling;
  String? place;
  final venue = '${m['venue'] ?? ''}'.trim();
  final connections = <String>{};
  final result = await showDialog<Json>(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, set) => AlertDialog(
                  scrollable: true,
                  title: const Text('How was your meetup?'),
                  content: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text(
                            'Just for you and the VriendTime team. Never shown to your Circle.',
                            style: TextStyle(color: Color(0xFF4F5D66))),
                        const SizedBox(height: 18),
                        const Text('How did it feel?',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: circleNavy)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final f in circleFeelings)
                            ChoiceChip(
                                label: Text(f),
                                selected: feeling == f,
                                onSelected: (_) => set(() => feeling = f))
                        ]),
                        const Divider(height: 36),
                        const Text(
                            'Anyone you’d like to spend more time with? (Optional)',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: circleNavy)),
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
                        ]),
                        // Helps us keep good places on the list. Optional.
                        if (venue.isNotEmpty) ...[
                          const Divider(height: 36),
                          Text(
                              t('How was {1}? (Optional)')
                                  .replaceAll('{1}', venue),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: circleNavy)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final f in circleFeelings)
                              ChoiceChip(
                                  label: Text(f),
                                  selected: place == f,
                                  onSelected: (on) =>
                                      set(() => place = on ? f : null)),
                          ]),
                        ],
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
                                  'connections': connections.toList(),
                                  if (place != null) 'place_feeling': place,
                                }),
                        child: const Text('Save privately'))
                  ])));
  if (result != null) await act('check_in', result);
}
