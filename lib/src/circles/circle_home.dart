import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/destructive.dart';
import '../core/payment_config.dart';
import 'circle_repository.dart';
import 'circle_widgets.dart';
import 'circle_journey.dart';
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
      required this.onMessages});
  final Json state;
  final bool demo, busy;
  final CircleAction act;

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
    final pending = meetups.where((m) => m['completed'] != true).toList()
      ..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    final upcoming = pending.firstOrNull;
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
                    'We can’t put you in a group until we have your WhatsApp number, birthday, photo and times.'),
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
                          (Icons.people_outline, 'Finding your people', false),
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
                          Text('${wait.headline} · ${wait.estimate}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                        ],
                        Text(
                            '${wait.daysWaiting == null ? '' : '${_waitedFor(wait.daysWaiting!)} '}No payment is due yet.',
                            style: const TextStyle(fontSize: 13)),
                      ])),
            ])),
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
              'We only match you with people free at the same time. Let us know every few weeks that these still work, so your invitation is one you can say yes to.'),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in slots.entries)
              CirclePill(
                  '${circleDays[circleDayKeys.indexOf(e.key)].substring(0, 3)} · ${e.value.join(' / ')}')
          ]),
          const SizedBox(height: 12),
          // Confirming twice in a week does nothing, so once it is fresh
          // this stops being a button and becomes what it was really
          // saying: these times are confirmed.
          if (_confirmedRecently(state))
            const CirclePill('Confirmed this week',
                icon: Icons.check_circle_outline)
          else
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
          if (state['application_updated_at'] != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Last confirmed ${circleDate(state['application_updated_at'].toString())}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF4F5D66)))),
        ]),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleHeading(
          graduated
              ? 'Your Circle is now yours.'
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
          if (_replyBy(circle) != null)
            _info(Icons.hourglass_bottom_rounded,
                'Please reply by ${_replyBy(circle)}'),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: busy || agreed ? null : () => _checkout(context),
              child: Text(
                  agreed ? 'Invitation accepted' : 'Accept invitation — €19')),
          const SizedBox(height: 12),
          const Text(
              'One payment for all six weeks. Food and drinks are paid at the venue. If the first meetup doesn’t feel right, you can ask for a refund within 48 hours.'),
          if (!demo) ...[
            const SizedBox(height: 10),
            Text(
                agreed
                    ? PaymentConfig.hasCircleFeeLink
                        ? 'Pay the one-off €19 with iDEAL. Use the name on your account so we can match your payment. Your place and group chat open once it arrives.'
                        : 'You’ve agreed to the one-off €19 fee. The organiser will send your payment link on WhatsApp. Your place and group chat open once payment is received.'
                    : PaymentConfig.hasCircleFeeLink
                        ? 'Accept first, then pay the €19 with iDEAL.'
                        : 'No online checkout. If you accept, the organiser will send your payment link on WhatsApp.',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (agreed && PaymentConfig.hasCircleFeeLink) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed: busy ? null : () => _pay(context),
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const Text('Pay €19 with iDEAL'))
            ],
          ],
          TextButton(
              onPressed: busy ? null : () => _decline(context),
              child: const Text('This schedule doesn’t work for me'))
        ]),
      if ((state['payment_agreement'] as Map?)?['can_cancel'] == true &&
          state['refund'] == null)
        TextButton(
            style: destructiveTextStyle,
            onPressed: busy ? null : () => _cancelAgreement(context),
            child: const Text('Cancel my programme agreement')),
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
              onPressed: busy ? null : () => scheduleCircleMeetup(context, act),
              child: const Text('Plan our next meetup')),
          TextButton(onPressed: onMessages, child: const Text('Ask the Circle'))
        ]),
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
      const SizedBox(height: 16),
      CirclePanel(children: [
        Wrap(spacing: 18, runSpacing: 18, children: [
          for (var i = 0; i < members.length; i++)
            SizedBox(
                width: 76,
                child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _member(context, members[i]),
                    child: Column(children: [
                      CircleMemberAvatar(members[i]['name'] as String,
                          index: i,
                          radius: 28,
                          photoUrl: members[i]['photo_url'] as String?,
                          photoPath: members[i]['photo_path'] as String?),
                      const SizedBox(height: 8),
                      Text(members[i]['name'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700))
                    ])))
        ]),
        const SizedBox(height: 18),
        Text(
            invited
                ? 'The same faces every week.'
                : 'You don’t need a perfect opener. A simple “how’s your week?” works.',
            style: const TextStyle(fontSize: 13)),
        if (!invited)
          TextButton(
              onPressed: onMessages,
              child: const Text('Say hello to your Circle →'))
      ]),
      const SizedBox(height: 28),
      Text('Six weeks, a little closer',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
          'We plan weeks 1 to 3. From week 4, your group plans together. All times are Netherlands time.'),
      const SizedBox(height: 18),
      for (final m in meetups.where((m) => m['week'] != null))
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _meetup(context, m)),
      if (!invited) ...[
        const SizedBox(height: 16),
        OutlinedButton(
            onPressed: busy ? null : () => scheduleCircleMeetup(context, act),
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
        else if (demo || state['refund_eligible'] == true)
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4F5D66)),
              onPressed: busy ? null : () => _refund(context),
              child: const Text('Circle not feeling right? Request a refund')),
        // Cancelling inside 14 days is offered above. Once the programme is
        // under way there was no way out of the app at all, which is not a
        // position to leave someone in for six weeks.
        if (!graduated)
          TextButton(
              style: destructiveTextStyle,
              onPressed: busy ? null : () => _leave(context),
              child: const Text('I need to leave this Circle')),
      ],
    ]);
  }

  /// Whether the member already told us these times still work this week.
  /// Confirming again inside that window changes nothing on the server, so
  /// offering the button again is a control that does not do anything.
  /// The last day a "yes" is accepted: the database takes replies until the
  /// day before the Circle starts.
  static String? _replyBy(Map circle) {
    final start = DateTime.tryParse('${circle['start_date']}');
    if (start == null) return null;
    return circleDate(
        start.subtract(const Duration(days: 1)).toIso8601String());
  }

  static bool _confirmedRecently(Json state, {DateTime? now}) {
    final at = DateTime.tryParse('${state['application_updated_at']}');
    if (at == null) return false;
    return (now ?? DateTime.now()).difference(at) < const Duration(days: 7);
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
  Widget _meetup(BuildContext context, Json m, {bool featured = false}) {
    final week = m['week'] as int?;
    final done = m['completed'] == true;
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
                    color: circleTeal))),
        if (done)
          const Icon(Icons.check_circle_rounded, color: circleTeal, size: 21)
      ]),
      const SizedBox(height: 10),
      Text(m['title'] as String,
          style: featured
              ? Theme.of(context).textTheme.headlineMedium
              : Theme.of(context).textTheme.titleMedium),
      if (!done && week != null && week >= 4) ...[
        const SizedBox(height: 8),
        const CirclePill('Your group plans this', icon: Icons.groups_outlined),
      ],
      const SizedBox(height: 8),
      Text('${circleDate(m['date'] as String?)} · ${m['time'] ?? '19:30'}'),
      if (featured) ...[
        const SizedBox(height: 12),
        _info(Icons.place_outlined, circleVenueLabel(m)),
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
        if (demo)
          TextButton(
              onPressed:
                  busy ? null : () => act('complete_meetup', {'id': m['id']}),
              child: const Text('Preview: finish this meetup'))
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
                : () => scheduleCircleMeetup(context, act, meetup: m),
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
                      : 'The full six-week programme costs €19 once. Food, drinks and activities are separate and paid at the venue. ${PaymentConfig.hasCircleFeeLink ? 'After you accept, you can pay straight away with iDEAL.' : 'The organiser will send a payment link to your WhatsApp number. During this pilot the link comes from the organiser’s own bunq or Tikkie, so you’ll see their name when you pay.'} Your place is confirmed when payment is received.'),
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

  /// A member's card, and the one place to say "not this person again".
  /// Excluding is private: the other member is never told, and it only takes
  /// effect on future matching, never on the Circle they are both in now.
  Future<void> _member(BuildContext context, Json member) async {
    final id = '${member['id']}';
    final name = member['name'] as String;
    final isSelf = id == '${state['profile_id']}' || id == 'you';
    final excluded = strings(state['exclusions']).contains(id);
    final exclude = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(name),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member['bio'] as String? ??
                          'Looking forward to getting to know the Circle.'),
                      const SizedBox(height: 12),
                      Text(strings(member['interests']).join(' · ')),
                      if (!isSelf) ...[
                        const SizedBox(height: 18),
                        const Divider(),
                        Text(
                            excluded
                                ? 'You’ve asked not to be matched with $name again.'
                                : 'Not a good fit? We can keep you out of the same Circle in future.',
                            style: const TextStyle(fontSize: 12)),
                      ]
                    ]),
                actions: [
                  if (!isSelf)
                    TextButton(
                        onPressed: () => Navigator.pop(c, !excluded),
                        child: Text(excluded
                            ? 'Allow matching again'
                            : 'Don’t match us again')),
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Close'))
                ]));
    if (exclude != null) {
      await act('exclude', {'target': id, 'active': exclude});
    }
  }

  /// Leaving after the programme has started. Cancelling inside 14 days is a
  /// payment decision and lives elsewhere; this is the later case, where the
  /// honest thing is to say plainly that the fee does not come back
  /// automatically.
  Future<void> _leave(BuildContext context) async {
    final reason = await showDialog<String>(
        context: context, builder: (c) => const _LeaveDialog());
    if (reason != null) await act('leave_circle', {'reason': reason});
  }

  /// Opens the organiser's payment request. Receipt is still confirmed by
  /// hand, so nothing about the member's state changes here — this only saves
  /// them waiting for an email with the link in it.
  Future<void> _pay(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var launched = false;
    try {
      launched = await launchUrl(Uri.parse(PaymentConfig.circleFeeLink),
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

  Future<void> _cancelAgreement(BuildContext context) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Cancel your programme agreement?'),
              content: const Text(
                  'You can cancel within 14 days of accepting. If you have paid, the organiser will arrange a full €19 refund. Otherwise your payment agreement will be cancelled.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Keep my place')),
                FilledButton(
                    style: destructiveFilledStyle,
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Confirm cancellation'))
              ],
            ));
    if (confirmed == true) await act('cancel_agreement');
  }

  Future<void> _refund(BuildContext context) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Request a refund?'),
                content: Text(demo
                    ? 'This is a demo request. No money will move.'
                    : 'If your first meetup ended within the last 48 hours, we’ll review your refund request. Your feedback stays private.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Back')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Send request'))
                ]));
    if (ok == true) await act('refund');
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
    {Json? meetup}) async {
  final result = await showDialog<Json>(
      context: context, builder: (c) => _ScheduleDialog(meetup: meetup));
  if (result != null) await act('schedule', result);
}

/// Owns its text controller so the controller outlives the dialog's closing
/// animation: disposing it the moment the dialog is popped tears it away from
/// a TextField that is still on screen.
class _LeaveDialog extends StatefulWidget {
  const _LeaveDialog();
  @override
  State<_LeaveDialog> createState() => _LeaveDialogState();
}

class _LeaveDialogState extends State<_LeaveDialog> {
  final reason = TextEditingController();

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Leave your Circle?'),
          content: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text(
                    'Your place is released and your remaining meetups are removed from your plans. The others are told that someone stepped away — never who, or why.'),
                const SizedBox(height: 12),
                const Text(
                    'The €19 programme fee is not refunded automatically at this point. If something has gone wrong, tell us below and we’ll come back to you.',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(
                    controller: reason,
                    maxLength: 300,
                    maxLines: 3,
                    decoration: InputDecoration(
                        labelText:
                            t('Anything you want us to know? (Optional)'),
                        alignLabelWithHint: true)),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Stay')),
            FilledButton(
                style: destructiveFilledStyle,
                onPressed: () => Navigator.pop(context, reason.text.trim()),
                child: const Text('Leave the Circle'))
          ]);
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({this.meetup});
  final Json? meetup;
  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late final TextEditingController title, venue;
  DateTime? date;
  TimeOfDay time = const TimeOfDay(hour: 19, minute: 30);
  String? error;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.meetup?['title'] as String?);
    venue = TextEditingController(text: widget.meetup?['venue'] as String?);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Make a plan together'),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: title,
                maxLength: 120,
                decoration: InputDecoration(labelText: t('What shall we do?'))),
            const SizedBox(height: 12),
            TextField(
                controller: venue,
                maxLength: 180,
                decoration: InputDecoration(labelText: t('Where?'))),
            const SizedBox(height: 14),
            OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: date != null && date!.isAfter(now)
                          ? date
                          : now.add(const Duration(days: 1)),
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: now.add(const Duration(days: 730)));
                  if (picked != null && mounted) setState(() => date = picked);
                },
                child: Text(date == null
                    ? 'Choose a date'
                    : circleDate(date!.toIso8601String()))),
            const SizedBox(height: 10),
            OutlinedButton(
                onPressed: () async {
                  final picked =
                      await showTimePicker(context: context, initialTime: time);
                  if (picked != null && mounted) setState(() => time = picked);
                },
                child: Text('${time.format(context)} · Netherlands time')),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red))
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (title.text.trim().isEmpty ||
                      venue.text.trim().isEmpty ||
                      date == null) {
                    setState(() => error = 'Add an activity, place, and date.');
                    return;
                  }
                  Navigator.pop(context, {
                    'title': title.text.trim(),
                    'venue': venue.text.trim(),
                    'date': date!.toIso8601String().split('T').first,
                    'time':
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    if (widget.meetup != null) 'id': widget.meetup!['id']
                  });
                },
                child: const Text('Save plan'))
          ]);
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
