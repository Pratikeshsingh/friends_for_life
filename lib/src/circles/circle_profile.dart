import 'package:flutter/material.dart' hide Text;
import '../core/destructive.dart';
import '../core/i18n.dart';
import 'circle_preferences.dart';
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
      this.onAdmin,
      this.onEditPublic,
      this.onHelp,
      this.onTerms,
      this.onPrivacy,
      this.onWithdraw,
      this.onEmailNotifications});
  final Json state;
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
          SwitchListTile(
              value: state['email_notifications'] != false,
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
