import 'package:flutter/material.dart' hide Text;
import '../core/destructive.dart';
import '../core/i18n.dart';
import '../core/app_diagnostics.dart';
import 'circle_leave.dart';
import 'circle_preferences.dart';
import 'circle_home.dart' show CircleAction;
import 'circle_repository.dart';
import 'circle_widgets.dart';

const _muted = Color(0xFF4F5D66);
const _line = Color(0xFFDDE7E3);
const _violet = Color(0xFF6B5BD2);
const _gold = Color(0xFFD08A12);
const _green = Color(0xFF1F9D55);

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
      const SizedBox(height: 22),
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
              const SizedBox(height: 10),
              if (circleSlots(app).isEmpty)
                const Text('Choose the days and times that fit your life.')
              else
                _slotGrid(circleSlots(app)),
              const SizedBox(height: 12),
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
              () => onEdit!(1),
              color: circleTeal),
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
                      color: circleTealText,
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
              () => onEdit!(2),
              color: circleCoral),
        ],
        if (onWithdraw != null) ...[
          const Divider(height: 1, color: _line),
          _tile(Icons.logout_rounded, 'Withdraw my application', onWithdraw,
              destructive: true,
              subtitle: 'You’ll lose your place on the waiting list.'),
        ],
      ]),
      const SizedBox(height: 22),
      _sectionLabel('Settings'),
      _card([
        // On the narrowest phones the toggle sits under the label, so the
        // label never breaks mid-word.
        LayoutBuilder(
            builder: (context, box) => box.maxWidth < 340
                ? ListTile(
                    leading: _badge(Icons.translate_rounded, _violet),
                    title: const Text('Language'),
                    subtitle: const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: LanguageToggle())))
                : ListTile(
                    leading: _badge(Icons.translate_rounded, _violet),
                    title: const Text('Language'),
                    trailing: const LanguageToggle())),
        // The app tells people when their Circle is ready, where to go, and
        // when to turn up. None of that reaches someone who is not in the
        // app, so email is on by default, and this is the only place to stop it.
        if (onEmailNotifications != null) ...[
          const Divider(height: 1, color: _line),
          if (state['email_notifications'] == null)
            const ListTile(
                title: Text('Email preference unavailable'),
                subtitle: Text('Refresh to load your saved choice.'))
          else
            SwitchListTile(
                value: state['email_notifications'] == true,
                onChanged: onEmailNotifications,
                secondary: _badge(Icons.mail_outline_rounded, _gold),
                title: const Text('Email me about my Circle'),
                subtitle: const Text(
                    'Invitations, payment updates, meetup details, reminders and new messages.')),
        ],
      ]),
      if (inCircle || onAdmin != null) ...[
        const SizedBox(height: 22),
        _sectionLabel('Your Circle'),
        _card([
          if (onBookings != null && inCircle)
            _tile(Icons.history_rounded, 'Previous meetups', onBookings,
                color: circleTeal),
          if (_canChooseMatches) ...[
            const Divider(height: 1, color: _line),
            _tile(Icons.people_alt_outlined, 'Future Circles',
                () => _futureCircles(context),
                subtitle: 'Who you’d rather not be matched with again',
                color: _violet),
          ],
          if (onReport != null) ...[
            const Divider(height: 1, color: _line),
            _tile(Icons.flag_outlined, 'Report a concern privately', onReport,
                color: circleCoral),
          ],
          if (onAdmin != null) ...[
            if (inCircle) const Divider(height: 1, color: _line),
            _tile(Icons.admin_panel_settings_outlined, 'Circle organiser',
                onAdmin,
                color: circleNavy),
          ],
        ]),
      ],
      if (act != null &&
          ((inCircle && ['active', 'forming', 'invited'].contains(stage)) ||
              ((state['payment_agreement'] as Map?)?['can_cancel'] == true &&
                  state['refund'] == null))) ...[
        const SizedBox(height: 22),
        _card([
          ExpansionTile(
            leading: _badge(Icons.event_note_outlined, circleNavy),
            title: const Text('Programme settings',
                style: TextStyle(fontWeight: FontWeight.w600)),
            children: [
              _tile(
                  Icons.swap_horiz_rounded,
                  'Switch group or leave',
                  busy
                      ? null
                      : () => showCircleLeaveFlow(context,
                          state: state, act: act!)),
            ],
          ),
        ]),
      ],
      if (rows(state['payment_history']).isNotEmpty) ...[
        const SizedBox(height: 22),
        _card([
          ExpansionTile(
              leading: _badge(Icons.receipt_long_outlined, _gold),
              title: const Text('Payments & refunds',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              children: [
                for (final payment in rows(state['payment_history']))
                  ListTile(
                      title: Text('€19 · ${t(circlePaymentLabel(payment))}'),
                      subtitle: payment['circle_name'] == null
                          ? null
                          : Text('${payment['circle_name']}')),
              ])
        ]),
      ],
      const SizedBox(height: 12),
      Text('App version ${AppDiagnostics.build}',
          style: const TextStyle(fontSize: 11)),
      const SizedBox(height: 22),
      _sectionLabel('Help & account'),
      _card([
        if (onHelp != null)
          _tile(Icons.chat_outlined, 'Help & contact', onHelp,
              subtitle: 'Chat with our team on WhatsApp', color: _green),
        if (onAccount != null) ...[
          const Divider(height: 1, color: _line),
          _tile(Icons.manage_accounts_outlined, 'Account details', onAccount,
              color: circleNavy),
        ],
        if (onExport != null) ...[
          const Divider(height: 1, color: _line),
          _tile(Icons.download_outlined, 'Download my data', onExport,
              color: _violet),
        ],
      ]),
      if (onSignOut != null) ...[
        const SizedBox(height: 20),
        SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: const Color(0xFFC2452A),
                    backgroundColor: const Color(0xFFFFE6DF),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
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
            // The photo overlaps the header. It sits inside the Stack's own
            // height (not hanging below it) so a tap on it registers.
            SizedBox(
                height: 128,
                child: Stack(alignment: Alignment.topCenter, children: [
                  SizedBox(
                      height: 84,
                      width: double.infinity,
                      child: Image.asset(
                          'assets/generated/profile-header-illustration.webp',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          excludeFromSemantics: true)),
                  Positioned(
                      top: 44,
                      child: Semantics(
                          button: true,
                          label: t('Show photo larger'),
                          child: GestureDetector(
                              onTap: () => showCirclePhoto(context, name,
                                  photoUrl: app['photo_url'] as String?,
                                  photoPath: app['photo_path'] as String?),
                              child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle),
                                  child: CircleMemberAvatar(name,
                                      photoUrl: app['photo_url'] as String?,
                                      photoPath: app['photo_path'] as String?,
                                      radius: 38))))),
                ])),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                child: Column(children: [
                  Text(name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(['Alkmaar', ...strings(app['languages'])].join(' · ')),
                  if ((app['intro'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('“${app['intro']}”',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontStyle: FontStyle.italic, height: 1.4)),
                  ],
                  if (strings(app['interests']).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final value in strings(app['interests']))
                            CirclePill(value)
                        ]),
                  ],
                  const SizedBox(height: 10),
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
                      style: TextStyle(fontSize: 13, color: circleTealText)),
                ])),
          ])));

  /// The other members of the Circle, without you.
  List<Json> get _others => rows(state['members'])
      .where((m) =>
          '${m['id']}' != '${state['profile_id']}' && '${m['id']}' != 'you')
      .toList();

  /// Only once the Circle has actually met: you cannot judge someone you
  /// have not sat at a table with. Also needs the saved choices to have
  /// loaded, so a switch never shows the wrong position.
  bool get _canChooseMatches =>
      act != null &&
      state['circle'] != null &&
      state['exclusions'] != null &&
      _others.isNotEmpty &&
      rows(state['meetups']).any((m) => circleMeetupPast(m));

  /// Private and only about future matching: the other person is never told
  /// and the current Circle does not change.
  Future<void> _futureCircles(BuildContext context) async {
    final excluded = strings(state['exclusions']).toSet();
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (c) => StatefulBuilder(
            builder: (c, update) => SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Future Circles',
                              style: Theme.of(c).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          const Text(
                              'When we form new Circles, we can keep you apart from someone. They are never told, and your current Circle stays as it is.',
                              style: TextStyle(color: _muted, height: 1.4)),
                          const SizedBox(height: 12),
                          for (final m in _others)
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                secondary: CircleMemberAvatar('${m['name']}',
                                    radius: 20,
                                    photoUrl: m['photo_url'] as String?,
                                    photoPath: m['photo_path'] as String?),
                                title: Text('${m['name']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(excluded.contains('${m['id']}')
                                    ? 'Not in my next Circle'
                                    : 'Happy to meet again'),
                                value: !excluded.contains('${m['id']}'),
                                onChanged: busy
                                    ? null
                                    : (meetAgain) async {
                                        final id = '${m['id']}';
                                        update(() => meetAgain
                                            ? excluded.remove(id)
                                            : excluded.add(id));
                                        await act!('exclude', {
                                          'target': id,
                                          'active': !meetAgain
                                        });
                                      }),
                        ])))));
  }

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

  /// A tinted rounded square behind each icon, so every row has a colour and
  /// related rows share one.
  static Widget _badge(IconData icon, Color color) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(11)),
      child: Icon(icon, size: 20, color: color));

  /// Seven days by three parts of the day. It stays the same size whether
  /// someone picked one evening or every slot of the week.
  Widget _slotGrid(Map<String, Set<String>> slots) {
    const labels = ['Morning', 'Afternoon', 'Evening'];
    Widget cell(bool on) => Expanded(
        child: Container(
            height: 22,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                color: on ? circleTeal : const Color(0xFFEAF2EF),
                borderRadius: BorderRadius.circular(6)),
            child: on
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null));
    return Column(children: [
      Row(children: [
        const SizedBox(width: 76),
        for (final day in circleDays)
          Expanded(
              child: Text(t(day).substring(0, 2),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _muted))),
      ]),
      const SizedBox(height: 2),
      for (var p = 0; p < circlePeriods.length; p++)
        Row(children: [
          SizedBox(
              width: 76,
              child: Text(labels[p],
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _muted))),
          for (final day in circleDayKeys)
            cell(slots[day]?.contains(circlePeriods[p]) ?? false),
        ]),
    ]);
  }

  Widget _tile(IconData icon, String title, VoidCallback? onTap,
          {String? subtitle,
          bool destructive = false,
          Color color = circleTeal}) =>
      ListTile(
          leading: _badge(icon, destructive ? destructiveRed : color),
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 112,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _muted))),
        const SizedBox(width: 8),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: circleNavy))),
      ]));
}

/// Owns its text controller so the controller outlives the dialog's closing
/// animation: disposing it the moment the dialog is popped tears it away from
/// a TextField that is still on screen.
