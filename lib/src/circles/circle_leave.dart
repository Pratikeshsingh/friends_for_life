import 'package:flutter/material.dart' hide Text;

import '../core/destructive.dart';
import '../core/i18n.dart';
import 'circle_repository.dart';
import 'circle_widgets.dart';

/// Reasons someone gives for wanting out. Most have a better answer than
/// leaving, so the reason decides what we suggest first.
const circleLeaveReasons = [
  'The day or time doesn’t work',
  'The group doesn’t feel right',
  'Something came up',
  'Something else',
];

/// Leaving a Circle, one careful step at a time: first why, then the option
/// that fixes it (another group, keeping the €19), and only then a refund
/// request or simply leaving. Nothing is paid out automatically: a refund is
/// a request the organiser reviews.
///
/// [onChangeTimes] opens the availability editor after a switch, for people
/// whose day or time didn't work.
Future<void> showCircleLeaveFlow(BuildContext context,
    {required Json state,
    required Future<void> Function(String action, [Json data]) act,
    VoidCallback? onChangeTimes}) async {
  final answer = await showDialog<_LeaveAnswer>(
      context: context, builder: (c) => const _ReasonDialog());
  if (answer == null || !context.mounted) return;

  final paid = state['payment'] == 'paid';
  final agreement = state['payment_agreement'] as Map?;
  final canSwitch = (state['switch'] as Map?)?['available'] == true ||
      (state['move'] as Map?)?['available'] == true;
  final canCancel = agreement?['can_cancel'] == true && state['refund'] == null;
  final timeIssue = answer.reason == circleLeaveReasons.first;
  final payload = {
    'reason': answer.reason,
    if (answer.note.isNotEmpty) 'note': answer.note,
  };

  final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
            title: Text(
                canSwitch ? 'We can find you another group' : 'Before you go'),
            content: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  if (canSwitch) ...[
                    Text(timeIssue
                        ? 'Switch to a group at a time that suits you. Your €19 carries over, and you can update your days and times straight after.'
                        : 'Switch to another group and keep your €19. You can do this once, free of charge, until your second meetup.'),
                    const SizedBox(height: 16),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        onPressed: () => Navigator.pop(c, 'switch'),
                        child: const Text('Switch to another group')),
                  ] else
                    Text(paid
                        ? 'A free switch isn’t possible any more and the refund window has closed. You can still leave; your reason helps us make better groups.'
                        : 'We’re sorry it isn’t working out. Your reason helps us make better groups.'),
                  const SizedBox(height: 8),
                  if (canCancel && paid)
                    TextButton(
                        onPressed: () => Navigator.pop(c, 'refund'),
                        child: const Text('I’d rather ask for my €19 back'))
                  else if (canCancel)
                    TextButton(
                        onPressed: () => Navigator.pop(c, 'cancel'),
                        child: const Text('Give up my place'))
                  else if (!canSwitch || paid)
                    TextButton(
                        onPressed: () => Navigator.pop(c, 'leave'),
                        child: const Text('Leave the Circle')),
                ])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Stay in my Circle')),
            ],
          ));
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case 'switch':
      await act('switch_group', payload);
      if (timeIssue) onChangeTimes?.call();
    case 'refund':
      final sure = await _confirm(context,
          title: 'Request a refund?',
          body:
              'Your place will be released and your request goes to the organiser, who reviews it and gets back to you. If it’s approved, the €19 goes back to the account you paid from.',
          action: 'Request refund');
      if (sure) await act('cancel_agreement', payload);
    case 'cancel':
      final sure = await _confirm(context,
          title: 'Give up your place?',
          body:
              'Your place goes to someone on the waiting list. Nothing has been paid, so there is nothing to refund.',
          action: 'Give up my place');
      if (sure) await act('cancel_agreement', payload);
    case 'leave':
      final sure = await _confirm(context,
          title: 'Leave your Circle?',
          body:
              'Your place is released and your remaining meetups are removed from your plans. At this point the €19 isn’t refunded. Your reason stays private.',
          action: 'Leave the Circle');
      if (sure) {
        await act('leave_circle', {
          'reason': [answer.reason, answer.note]
              .where((x) => x.isNotEmpty)
              .join(' — ')
        });
      }
  }
}

Future<bool> _confirm(BuildContext context,
        {required String title,
        required String body,
        required String action}) async =>
    await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Keep my place')),
                FilledButton(
                    style: destructiveFilledStyle,
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(action)),
              ],
            )) ==
    true;

class _LeaveAnswer {
  const _LeaveAnswer(this.reason, this.note);
  final String reason, note;
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  String? reason;
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('What isn’t working?'),
        content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text(
                  'Tell us, and we’ll see what we can do. It stays between you and us.'),
              const SizedBox(height: 8),
              RadioGroup<String>(
                  groupValue: reason,
                  onChanged: (v) => setState(() => reason = v),
                  child: Column(children: [
                    for (final r in circleLeaveReasons)
                      RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: r,
                          title: Text(r)),
                  ])),
              TextField(
                  controller: note,
                  maxLength: 300,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                      labelText: t('A note (optional)'),
                      hintText: t('Anything you’d like us to know'),
                      alignLabelWithHint: true)),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Stay in my Circle')),
          FilledButton(
              onPressed: reason == null
                  ? null
                  : () => Navigator.pop(
                      context, _LeaveAnswer(reason!, note.text.trim())),
              child: const Text('Continue')),
        ],
      );
}

/// After leaving a Circle: what happened, and the way back.
class CircleLeftCard extends StatelessWidget {
  const CircleLeftCard(
      {super.key,
      required this.left,
      required this.busy,
      required this.onRejoin,
      required this.onEdit});
  final Map left;
  final bool busy;
  final VoidCallback onRejoin, onEdit;

  @override
  Widget build(BuildContext context) {
    final refund = left['refund'];
    if (left['removed'] == true) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleHeading('You’re no longer in ${left['name'] ?? 'your Circle'}.',
            eyebrow: 'Your Circle',
            subtitle:
                'The organiser has removed you from this Circle. If you think this is a mistake, email support@vriendtime.com.'),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleHeading('You’ve left ${left['name'] ?? 'your Circle'}.',
          eyebrow: 'Your Circle',
          subtitle: refund == 'requested'
              ? 'Your refund request is with the organiser. We’ll be in touch about it.'
              : refund == 'completed'
                  ? 'Your refund is complete. Contact us if it hasn’t arrived.'
                  : 'Thanks for giving it a go.'),
      CirclePanel(tint: true, children: [
        Text('Try another Circle?',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
            'Your answers are saved. Join the waiting list again and we’ll invite you when a new group fits your times.'),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: busy ? null : onRejoin,
            child: const Text('Join the waiting list')),
        TextButton(
            onPressed: busy ? null : onEdit,
            child: const Text('Update my answers first')),
      ]),
    ]);
  }
}
