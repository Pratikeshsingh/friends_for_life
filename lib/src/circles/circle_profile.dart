import 'package:flutter/material.dart' hide Text;
import '../core/destructive.dart';
import '../core/i18n.dart';
import '../core/app_diagnostics.dart';
import 'circle_preferences.dart';
import 'circle_home.dart' show CircleAction;
import 'circle_repository.dart';
import 'circle_widgets.dart';

const _muted = Color(0xFF4F5D66);
const _line = Color(0xFFDDE7E3);

class CircleProfile extends StatelessWidget {
  const CircleProfile(
      {super.key,
      required this.state,
      required this.onEdit,
      required this.onPhoto,
      required this.onAccount,
      required this.onReport,
      required this.onExport,
      required this.onBookings,
      required this.onSignOut,
      this.act,
      this.busy = false,
      this.onAdmin,
      this.onEditPublic,
      this.onHelp,
      this.onTerms,
      this.onPrivacy,
      this.onWithdraw,
      this.onEmailNotifications});
  final Json state;
  final CircleAction? act;
  final bool busy;
  final VoidCallback? onEditPublic;

  /// Turns the notification emails on or off. Null hides the row entirely,
  /// which is what the preview does: it has nowhere to send mail.
  final ValueChanged<bool>? onEmailNotifications;

  /// Opens the application at a given step so each card edits its own
  /// answers instead of starting at name and date of birth.
  final ValueChanged<int>? onEdit;

  /// Only while someone is on the waiting list. It sits with the answers it
  /// throws away, not on the home screen where it would add doubt.
  final VoidCallback? onWithdraw;
  final VoidCallback? onPhoto,
      onAccount,
      onReport,
      onExport,
      onBookings,
      onSignOut,
      onAdmin,
      onHelp,
      onTerms,
      onPrivacy;

  /// Leaving after the programme has started. Cancelling inside 14 days is a
  /// payment decision and lives elsewhere; this is the later case, where the
  /// honest thing is to say plainly that the fee does not come back
  /// automatically.
  Future<void> _leave(BuildContext context) async {
    if ((state['payment_agreement'] as Map?)?['can_cancel'] == true && state['refund'] == null) {
      await _cancelAgreement(context); return;
    }
    final reason = await showDialog<String>(
        context: context, builder: (c) => const _LeaveDialog());
    if (reason != null) await act!('leave_circle', {'reason': reason});
  }

  Future<void> _cancelAgreement(BuildContext context, {String? paymentId}) async {
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
    if (confirmed == true) await act!('cancel_agreement', {if (paymentId != null) 'id': paymentId});
  }

  @override
  Widget build(BuildContext context) {
    final app = Map<String, dynamic>.from(state['application'] as Map? ?? {});
    final name = app['name'] as String? ?? 'Your profile';
    final stage = state['stage'];
    final applying = stage == 'apply' || stage == 'waiting';
    final inCircle = state['circle'] != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CircleHeading('A familiar face.', eyebrow: 'Your profile'),
      _publicCard(context, app, name),
      const SizedBox(height: 28),
      _sectionLabel(applying ? 'Your application' : 'Your weekly rhythm'),
      _card([
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your times',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _muted)),
              const SizedBox(height: 8),
              if (circleSlots(app).isEmpty)
                const Text('Choose the days and times that fit your life.')
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in circleSlots(app).entries)
                    CirclePill(
                        '${circleDays[circleDayKeys.indexOf(e.key)].substring(0, 3)} · ${e.value.join(' / ')}')
                ]),
              const SizedBox(height: 14),
              Row(children: [
                Icon(
                    app['commitment'] == true
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: circleTeal,
                    size: 20),
                const SizedBox(width: 10),
                const Expanded(child: Text('One meetup a week · six weeks'))
              ]),
              const SizedBox(height: 6),
            ])),
        if (onEdit != null) ...[
          const Divider(height: 1, color: _line),
          _tile(Icons.edit_calendar_outlined, 'Edit my availability',
              () => onEdit!(1)),
        ],
        const Divider(height: 1, color: _line),
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('JUST FOR MATCHING',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: circleTeal,
                      fontWeight: FontWeight.w800)),
              _row(
                  context,
                  'Looking for',
                  strings(app['goals']).isEmpty
                      ? 'Not answered yet'
                      : strings(app['goals']).join(' · ')),
              _row(
                  context,
                  'At a new table',
                  circleStyles[(((app['energy'] as num?)?.toDouble() ?? 2) / 2)
                      .round()
                      .clamp(0, 2)]),
              _row(
                  context,
                  'What brings you here',
                  strings(app['life_context']).isEmpty
                      ? 'Not answered yet'
                      : strings(app['life_context']).join(' · ')),
              const SizedBox(height: 12),
              const Text(
                  'Only the organiser sees these, with your birthday. Your Circle never does.',
                  style: TextStyle(fontSize: 13, color: _muted)),
              const SizedBox(height: 8),
            ])),
        if (onEdit != null) ...[
          const Divider(height: 1, color: _line),
          _tile(Icons.tune_outlined, 'Edit my interests and goals',
              () => onEdit!(2)),
        ],
        if (onWithdraw != null) ...[
          const Divider(height: 1, color: _line),
          _tile(Icons.logout_rounded, 'Withdraw my application', onWithdraw,
              destructive: true,
              subtitle: 'You’ll lose your place on the waiting list.'),
        ],
      ]),
      const SizedBox(height: 28),
      _sectionLabel('Settings'),
      _card([
        ListTile(
            leading: const Icon(Icons.translate_rounded, color: circleTeal),
            title: const Text('App language'),
            trailing: const LanguageToggle()),
        // The app tells people when their Circle is ready, where to go, and
        // when to turn up. None of that reaches someone who is not in the
        // app, so email is on by default, and this is the only place to stop it.
        if (onEmailNotifications != null) ...[
          const Divider(height: 1, color: _line),
          if (state['email_notifications'] == null) const ListTile(title: Text('Email preference unavailable'), subtitle: Text('Refresh to load your saved choice.'))
          else SwitchListTile(
              value: state['email_notifications'] == true,
              onChanged: onEmailNotifications,
              secondary:
                  const Icon(Icons.mail_outline_rounded, color: circleTeal),
              title: const Text('Email me about my Circle'),
              subtitle: const Text(
                  'Your invitation, the venue and a day-before reminder.')),
        ],
      ]),
      if (inCircle || onAdmin != null) ...[
        const SizedBox(height: 28),
        _sectionLabel('Your Circle'),
        _card([
          if (onBookings != null && inCircle)
            _tile(Icons.history_rounded, 'Previous meetups', onBookings),
          if (onReport != null) ...[
            const Divider(height: 1, color: _line),
            _tile(Icons.flag_outlined, 'Report a concern privately', onReport),
          ],
          if (onAdmin != null) ...[
            if (inCircle) const Divider(height: 1, color: _line),
            _tile(Icons.admin_panel_settings_outlined, 'Circle organiser',
                onAdmin),
          ],
        ]),
      ],
      if (act != null &&
          ((inCircle && ['active', 'forming'].contains(stage)) ||
              ((state['payment_agreement'] as Map?)?['can_cancel'] == true &&
                  state['refund'] == null))) ...[
        const SizedBox(height: 28),
        _card([
          ExpansionTile(
            title: const Text('Programme settings'),
            children: [
              if (inCircle && ['active', 'forming'].contains(stage))
                _tile(Icons.logout_rounded, 'I need to leave this Circle',
                    busy ? null : () => _leave(context),
                    destructive: true),
              if ((state['payment_agreement'] as Map?)?['can_cancel'] == true &&
                  state['refund'] == null)
                _tile(Icons.cancel_outlined, 'Cancel my programme agreement',
                    busy ? null : () => _cancelAgreement(context),
                    destructive: true),
            ],
          ),
        ]),
      ],
      if (rows(state['payment_history']).isNotEmpty) ...[
        const SizedBox(height: 28),
        _card([ExpansionTile(title: const Text('Payments & refunds'), children: [
          for (final payment in rows(state['payment_history'])) ListTile(
            title: Text('€19 · ${payment['refund'] ?? payment['status']}'),
            subtitle: SelectableText('${payment['reference']}'),
            trailing: payment['can_cancel'] == true && act != null
              ? TextButton(onPressed: busy ? null : () => _cancelAgreement(context, paymentId: '${payment['id']}'), child: const Text('Cancel agreement')) : null),
        ])]),
      ],
      const SizedBox(height: 12),
      Text('App version ${AppDiagnostics.build}', style: const TextStyle(fontSize: 11)),
      const SizedBox(height: 28),
      _sectionLabel('Help & account'),
      _card([
        if (onHelp != null)
          _tile(Icons.chat_outlined, 'Help & contact', onHelp,
              subtitle: 'Chat with our team on WhatsApp'),
        if (onAccount != null) ...[
          const Divider(height: 1, color: _line),
          _tile(Icons.manage_accounts_outlined, 'Account details', onAccount),
        ],
        if (onExport != null) ...[
          const Divider(height: 1, color: _line),
          _tile(Icons.download_outlined, 'Download my data', onExport),
        ],
      ]),
      if (onSignOut != null) ...[
        const SizedBox(height: 20),
        SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: circleNavy,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: _line)),
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Sign out'))),
      ],
      if (onTerms != null || onPrivacy != null) ...[
        const SizedBox(height: 24),
        Center(
            child: Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
              if (onTerms != null)
                TextButton(onPressed: onTerms, child: const Text('Terms')),
              if (onPrivacy != null)
                TextButton(onPressed: onPrivacy, child: const Text('Privacy')),
            ])),
        const Center(
            child: Text('VriendTime · Friendship Circles · Alkmaar',
                style: TextStyle(fontSize: 12, color: _muted))),
        const SizedBox(height: 8),
      ],
    ]);
  }

  /// What the Circle sees: photo, name, intro and interests, with the two
  /// ways to change it right underneath.
  Widget _publicCard(BuildContext context, Json app, String name) => ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
          color: const Color(0xFFE0EEE8),
          child: Column(children: [
            SizedBox(
                height: 120,
                width: double.infinity,
                child: Image.asset(
                    'assets/generated/profile-header-illustration.webp',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    excludeFromSemantics: true)),
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(children: [
                  CircleMemberAvatar(name,
                      photoUrl: app['photo_url'] as String?,
                      photoPath: app['photo_path'] as String?,
                      radius: 48),
                  const SizedBox(height: 14),
                  Text(name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(['Alkmaar', ...strings(app['languages'])].join(' · ')),
                  if ((app['intro'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('“${app['intro']}”',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontStyle: FontStyle.italic, height: 1.4)),
                  ],
                  if (strings(app['interests']).isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final value in strings(app['interests']))
                            CirclePill(value)
                        ]),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        if (onPhoto != null)
                          TextButton.icon(
                              onPressed: onPhoto,
                              icon: const Icon(Icons.add_a_photo_outlined,
                                  size: 18),
                              label: Text(app['photo_path'] == null
                                  ? 'Add your photo'
                                  : 'Change photo')),
                        if (onEditPublic != null)
                          TextButton.icon(
                              onPressed: onEditPublic,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit my introduction')),
                      ]),
                  const Text('This is what your Circle sees.',
                      style: TextStyle(fontSize: 13, color: circleTeal)),
                ])),
          ])));

  Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(t(text).toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
              color: _muted)));

  /// A white card that holds rows, so they read on top of the background
  /// illustration instead of floating over it.
  Widget _card(List<Widget> children) => Material(
      color: Colors.white.withValues(alpha: .94),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: _line)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children));

  Widget _tile(IconData icon, String title, VoidCallback? onTap,
          {String? subtitle, bool destructive = false}) =>
      ListTile(
          leading: Icon(icon, color: destructive ? destructiveRed : circleTeal),
          title: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: destructive ? destructiveRed : circleNavy)),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: Icon(Icons.chevron_right_rounded,
              color: destructive ? destructiveRed : _muted),
          onTap: onTap);

  /// A labelled answer, so a question never reads as the answer's heading.
  Widget _row(BuildContext context, String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _muted)),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ]));
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
                    'Your place is released and your remaining meetups are removed from your plans. Your reason stays private. The group can see that you are no longer a member.'),
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
