import 'package:flutter/material.dart';
import 'circle_preferences.dart';
import 'circle_repository.dart';
import 'circle_widgets.dart';

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
      this.onEmailNotifications});
  final Json state;
  final VoidCallback? onEditPublic;

  /// Turns the notification emails on or off. Null hides the row entirely,
  /// which is what the preview does: it has nowhere to send mail.
  final ValueChanged<bool>? onEmailNotifications;

  /// Opens the application at a given step so each card edits its own
  /// answers instead of starting at name and date of birth.
  final ValueChanged<int>? onEdit;
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
    final waiting = state['stage'] == 'waiting';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CircleHeading('A familiar face.', eyebrow: 'Your profile'),
      ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
              color: const Color(0xFFE0EEE8),
              child: Column(children: [
                SizedBox(
                    height: 145,
                    width: double.infinity,
                    child: Image.asset(
                        'assets/generated/profile-header-illustration.webp',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        excludeFromSemantics: true)),
                Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      CircleMemberAvatar(name,
                          photoUrl: app['photo_url'] as String?,
                          photoPath: app['photo_path'] as String?,
                          radius: 48),
                      const SizedBox(height: 14),
                      Text(name,
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                          'Alkmaar · ${strings(app['languages']).join(' / ')}'),
                      if ((app['intro'] as String? ?? '').isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(app['intro'] as String,
                            textAlign: TextAlign.center)
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final value in strings(app['interests']))
                              CirclePill(value)
                          ]),
                      const SizedBox(height: 12),
                      if (onPhoto != null)
                        TextButton.icon(
                            onPressed: onPhoto,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: Text(app['photo_path'] == null
                                ? 'Add your photo'
                                : 'Change photo')),
                      const Text('Visible to your assigned Circle',
                          style: TextStyle(fontSize: 11, color: circleTeal)),
                    ])),
              ]))),
      if (onEditPublic != null)
        TextButton.icon(
            onPressed: onEditPublic,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit my introduction')),
      const SizedBox(height: 24),
      CirclePanel(children: [
        Row(children: [
          const Icon(Icons.calendar_month_outlined, color: circleTeal),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  waiting ? 'Ready to make time.' : 'Your weekly rhythm.',
                  style: Theme.of(context).textTheme.headlineSmall))
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in circleSlots(app).entries)
            CirclePill(
                '${circleDays[circleDayKeys.indexOf(e.key)].substring(0, 3)} · ${e.value.join(' / ')}')
        ]),
        if (circleSlots(app).isEmpty)
          const Text('Choose the days and times that fit your life.'),
        const SizedBox(height: 18),
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
        if (onEdit != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: () => onEdit!(1),
              child: const Text('Edit my availability'))
        ],
      ]),
      const SizedBox(height: 16),
      CirclePanel(children: [
        const Text('JUST FOR MATCHING',
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                color: circleTeal,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Text(
            strings(app['goals']).isEmpty
                ? 'What kind of friendship are you looking for?'
                : strings(app['goals']).join(' · '),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Text(circleStyles[(((app['energy'] as num?)?.toDouble() ?? 2) / 2)
            .round()
            .clamp(0, 2)]),
        if (strings(app['life_context']).isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(strings(app['life_context']).join(' · '))
        ],
        const SizedBox(height: 12),
        const Text('Your birthday and matching answers stay private.',
            style: TextStyle(fontSize: 12)),
        if (onEdit != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: () => onEdit!(2),
              child: const Text('Edit my interests and goals'))
        ],
      ]),
      const SizedBox(height: 16),
      // The app tells people when their Circle is ready, where to go, and when
      // to turn up. None of that reaches someone who is not in the app, so
      // email is on by default — and this is the only place it can be stopped.
      if (onEmailNotifications != null)
        SwitchListTile(
            // Default padding, so this lines up with the plain ListTiles below
            // it rather than sitting a few pixels to their left.
            value: state['email_notifications'] != false,
            onChanged: onEmailNotifications,
            secondary: const Icon(Icons.mail_outline_rounded),
            title: const Text('Email me about my Circle'),
            subtitle: const Text(
                'Your invitation, the venue and a day-before reminder.')),
      const SizedBox(height: 6),
      if (onAdmin != null)
        ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Circle organiser'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onAdmin),
      if (onAccount != null)
        ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Account & support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onAccount),
      if (onReport != null)
        ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report a concern privately'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onReport),
      if (onBookings != null)
        ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Previous meetups'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onBookings),
      if (onHelp != null)
        ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: const Text('Help & contact'),
            subtitle: const Text('Chat with our team on WhatsApp'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onHelp),
      if (onExport != null)
        ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Download my data'),
            onTap: onExport),
      if (onSignOut != null)
        TextButton(onPressed: onSignOut, child: const Text('Sign out')),
      if (onTerms != null || onPrivacy != null) ...[
        const SizedBox(height: 18),
        const Divider(),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onTerms != null)
                TextButton(onPressed: onTerms, child: const Text('Terms')),
              if (onPrivacy != null)
                TextButton(onPressed: onPrivacy, child: const Text('Privacy')),
            ]),
        const Text('VriendTime · Friendship Circles · Alkmaar',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
      ],
    ]);
  }
}
