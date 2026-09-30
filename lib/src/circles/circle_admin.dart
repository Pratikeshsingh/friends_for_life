import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/destructive.dart';
import 'circle_home.dart';
import 'circle_preferences.dart';
import 'circle_repository.dart';
import 'circle_widgets.dart';

/// A group of waiting applicants who could actually be put in a Circle
/// together: everyone shares this language and has this day and time in
/// their availability, which is what `admin_create` insists on.
class CircleSuggestion {
  const CircleSuggestion({
    required this.members,
    required this.language,
    required this.day,
    required this.period,
  });

  final List<Json> members;
  final String language, day, period;

  String get slot => '$day $period';

  /// Interests every single member picked — the organiser's cue for
  /// whether this group has anything to talk about.
  List<String> get sharedInterests {
    if (members.isEmpty) return const [];
    final shared = strings(members.first['interests']).toSet();
    for (final member in members.skip(1)) {
      shared.retainAll(strings(member['interests']));
    }
    return shared.toList()..sort();
  }
}

/// Two people who asked not to be matched, in the order the database stores
/// them, as one key that reads the same from either side.
String exclusionKey(String a, String b) =>
    (a.compareTo(b) <= 0) ? '$a|$b' : '$b|$a';

/// The pairs the organiser must keep apart, read from the admin snapshot.
Set<String> circleExclusions(Json? data) => {
      for (final pair in (data?['exclusions'] as List? ?? []))
        if (pair is List && pair.length == 2)
          exclusionKey('${pair.first}', '${pair.last}')
    };

/// Applicants arrive ordered by how long they have been waiting, so the
/// first valid group we can build from the front of the list is also the
/// fairest one. No scoring model — just "these six genuinely fit, and
/// they have waited longest".
///
/// [exclusions] are pairs who asked never to share a Circle. The database
/// refuses such a group outright, so a suggestion containing one would only
/// waste the organiser's time.
List<CircleSuggestion> suggestCircles(List<Json> applications,
    {Set<String> exclusions = const {}}) {
  final waiting = [
    for (final a in applications)
      if (a['ready'] != false) a
  ];
  final seniority = {
    for (var i = 0; i < waiting.length; i++) waiting[i]['profile_id']: i
  };
  final slots = <String>{
    for (final a in waiting) ...strings(a['availability'])
  };

  final found = <CircleSuggestion>[];
  final seen = <String>{};
  for (final language in circleLanguages) {
    for (final slot in slots) {
      final pool = [
        for (final a in waiting)
          if (strings(a['languages']).contains(language) &&
              strings(a['availability']).contains(slot))
            a
      ];
      // Fill from the front, skipping anyone who clashes with a member
      // already in the group. Skipping rather than abandoning the slot means
      // one blocked pair costs the next person their place, not everybody.
      final members = <Json>[];
      for (final candidate in pool) {
        if (members.length == 6) break;
        final id = '${candidate['profile_id']}';
        final clashes = members.any(
            (m) => exclusions.contains(exclusionKey(id, '${m['profile_id']}')));
        if (!clashes) members.add(candidate);
      }
      if (members.length < 5) continue;
      // The same six people can qualify under both languages; show once.
      final key =
          (members.map((m) => '${m['profile_id']}').toList()..sort()).join(',');
      if (!seen.add(key)) continue;
      final parts = slot.split(' ');
      if (parts.length < 2) continue;
      found.add(CircleSuggestion(
          members: members,
          language: language,
          day: parts.first,
          period: parts.last));
    }
  }

  found.sort((a, b) {
    double wait(CircleSuggestion s) =>
        s.members
            .map((m) => seniority[m['profile_id']] ?? 0)
            .reduce((x, y) => x + y) /
        s.members.length;
    final byWait = wait(a).compareTo(wait(b));
    return byWait != 0 ? byWait : b.members.length.compareTo(a.members.length);
  });
  return found;
}

class CircleAdmin extends StatefulWidget {
  const CircleAdmin(
      {super.key, required this.repository, required this.onChanged});
  final CircleRepository repository;
  final VoidCallback onChanged;
  @override
  State<CircleAdmin> createState() => _CircleAdminState();
}

class _CircleAdminState extends State<CircleAdmin> {
  Json? data;
  String? error;
  bool busy = false;
  final selected = <String>{};
  final name = TextEditingController(text: 'Alkmaar Founding Circle');
  final schedule = TextEditingController(text: 'Thursday evenings · 19:30');
  DateTime? start;
  TimeOfDay time = const TimeOfDay(hour: 19, minute: 30);
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    schedule.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final d = await widget.repository.adminLoad();
      if (mounted) {
        setState(() {
          data = d;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Could not load organiser tools. Check your access and try again.');
      }
    }
  }

  Future<void> action(String action, [Json payload = const {}]) async {
    setState(() => busy = true);
    try {
      await widget.repository.act(action, payload);
      selected.clear();
      await load();
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() => error =
            'That change could not be saved. ${e is StateError ? e.message : e is PostgrestException ? e.message : 'Please try again.'}');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// `circle_time_period` only accepts a start time that leaves room for
  /// the full two hours inside the member-facing window, so these are the
  /// safe starts for each period rather than the window openings.
  static const _periodStart = {
    'morning': TimeOfDay(hour: 9, minute: 30),
    'afternoon': TimeOfDay(hour: 13, minute: 0),
    'evening': TimeOfDay(hour: 19, minute: 0),
  };

  /// First matching weekday at least a week out, so nobody is invited to
  /// something happening in two days.
  DateTime _nextWeekday(String day) {
    final target = circleDays.indexOf(day) + 1;
    var date = DateTime.now().add(const Duration(days: 7));
    while (target > 0 && date.weekday != target) {
      date = date.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day);
  }

  void _useSuggestion(CircleSuggestion suggestion) {
    setState(() {
      selected
        ..clear()
        ..addAll(suggestion.members.map((m) => '${m['profile_id']}'));
      start = _nextWeekday(suggestion.day);
      time = _periodStart[suggestion.period] ?? time;
      name.text = 'The ${suggestion.day} Circle';
      schedule.text =
          '${suggestion.day}s · ${suggestion.period} · ${suggestion.language}';
    });
  }

  /// Pairs inside the organiser's current selection who asked not to be
  /// matched. Empty is the normal case.
  List<String> _blockedPairs() {
    final exclusions = circleExclusions(data);
    if (exclusions.isEmpty) return const [];
    final ids = selected.toList();
    return [
      for (var i = 0; i < ids.length; i++)
        for (var j = i + 1; j < ids.length; j++)
          if (exclusions.contains(exclusionKey(ids[i], ids[j])))
            exclusionKey(ids[i], ids[j])
    ];
  }

  Widget _suggestionsPanel(BuildContext context) {
    final suggestions = suggestCircles(rows(data!['applications']),
        exclusions: circleExclusions(data));
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: CirclePanel(tint: true, children: [
          Text('Groups that would work',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'Everyone here shares a language and has this day and time free. '
              'Longest-waiting applicants come first. Check the people before you create.'),
          const SizedBox(height: 16),
          for (final suggestion in suggestions.take(3)) ...[
            Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .7),
                    borderRadius: BorderRadius.circular(18)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${suggestion.members.length} people · ${suggestion.day} ${suggestion.period} · ${suggestion.language}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: circleNavy)),
                      const SizedBox(height: 6),
                      Text(suggestion.members
                          .map((m) => '${m['name'] ?? 'Someone'}')
                          .join(' · ')),
                      if (suggestion.sharedInterests.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                            'All into: ${suggestion.sharedInterests.join(' · ')}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed:
                              busy ? null : () => _useSuggestion(suggestion),
                          child: const Text('Use this group')),
                    ])),
          ],
        ]));
  }

  /// WhatsApp number and optional address, for the organiser only.
  Json? contactFor(Object? profileId) {
    final contacts = data?['contacts'];
    if (contacts is! Map || profileId == null) return null;
    final c = contacts[profileId.toString()];
    return c is Map ? Map<String, dynamic>.from(c) : null;
  }

  Future<void> openWhatsApp(String phone, String message) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.https('wa.me', '/$digits', {'text': message});
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp did not open.')));
    }
  }

  List<Widget> contactLines(String? phone, String? address,
      {String? whatsAppMessage}) {
    final hasPhone = phone != null && phone.isNotEmpty;
    return [
      if (hasPhone)
        SelectableText('WhatsApp: $phone')
      else
        const Text('No WhatsApp number yet',
            style: TextStyle(color: Colors.deepOrange)),
      if (address != null && address.isNotEmpty)
        SelectableText('Address: $address')
      else
        const Text('No address given',
            style: TextStyle(fontSize: 12, color: Color(0xFF66727C))),
      if (hasPhone && whatsAppMessage != null)
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: () => openWhatsApp(phone, whatsAppMessage),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Send payment link on WhatsApp'))),
    ];
  }

  Future<void> confirmAction(
      String title, String explanation, String command, Json payload,
      {bool destructive = false}) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text(title),
              content: Text(explanation),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Back')),
                FilledButton(
                    style: destructive ? destructiveFilledStyle : null,
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(destructive ? 'Yes, go ahead' : 'Confirm')),
              ],
            ));
    if (confirmed == true) await action(command, payload);
  }

  Future<void> attendance(Json meetup) async {
    final people = rows(meetup['attendees']);
    await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Actual attendance'),
                content: SizedBox(
                    width: 400,
                    child: SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'Record who attended after the meetup. An RSVP alone does not count.'),
                      if (people.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No attendance records yet.')),
                      for (final p in people)
                        ListTile(
                            title: Text(p['name'] as String? ?? 'Member'),
                            subtitle: Text(p['attended'] == true
                                ? 'Attended'
                                : p['attended'] == false
                                    ? 'Absent'
                                    : 'Not recorded'),
                            trailing: PopupMenuButton<bool>(
                                onSelected: (v) {
                                  Navigator.pop(c);
                                  action('admin_attendance', {
                                    'id': meetup['id'],
                                    'profile_id': p['profile_id'],
                                    'attended': v
                                  });
                                },
                                itemBuilder: (_) => const [
                                      PopupMenuItem(
                                          value: true, child: Text('Attended')),
                                      PopupMenuItem(
                                          value: false, child: Text('Absent'))
                                    ]))
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Close'))
                ]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Circle organiser'), actions: [
        IconButton(
            onPressed: load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh')
      ]),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: data == null
                  ? Center(
                      child: error == null
                          ? const CircularProgressIndicator()
                          : Text(error!))
                  : ListView(padding: const EdgeInsets.all(24), children: [
                      CircleHeading('Make the introductions.',
                          eyebrow: widget.repository.isDemo
                              ? 'Preview organiser · example applicants'
                              : 'Alkmaar founding pilot',
                          subtitle:
                              'Start with a shared language and a time everyone can make. Keep the first groups small.'),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(error!,
                                style: const TextStyle(color: Colors.red))),
                      CirclePanel(tint: true, children: [
                        Wrap(spacing: 30, runSpacing: 14, children: [
                          for (final entry
                              in (data!['metrics'] as Map? ?? {}).entries)
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${entry.value}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium),
                                  Text('${entry.key}'.replaceAll('_', ' '))
                                ])
                        ])
                      ]),
                      const SizedBox(height: 22),
                      Text('Payment agreements',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      if (rows(data!['payments']).isEmpty)
                        const Text('No accepted invitations yet.'),
                      for (final p in rows(data!['payments']))
                        CirclePanel(children: [
                          Text(
                              '${p['name'] ?? 'Member'} · ${p['circle_name'] ?? 'Circle'}',
                              style: Theme.of(context).textTheme.titleMedium),
                          SelectableText(
                              p['email']?.toString() ?? 'Account removed'),
                          ...contactLines(
                              contactFor(p['profile_id'])?['phone'] as String?,
                              contactFor(p['profile_id'])?['address']
                                  as String?,
                              whatsAppMessage: p['status'] == 'awaiting_payment'
                                  ? 'Hi ${p['name'] ?? 'there'}! Welcome to your VriendTime Circle "${p['circle_name'] ?? ''}". Here is your link for the one-off €19 programme fee: '
                                  : null),
                          Text(
                              '€19 · ${p['status'].toString().replaceAll('_', ' ')}'),
                          Text(
                              'Agreed ${circleDate(p['agreed_at']?.toString())}'),
                          if (p['status'] == 'awaiting_payment')
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => confirmAction(
                                        'Confirm €19 received?',
                                        'Only confirm after you have checked the money arrived. This unlocks the member’s Circle and group chat.',
                                        'admin_confirm_payment',
                                        {'id': p['id'], 'received': true}),
                                child: const Text('Confirm payment received')),
                        ]),
                      const SizedBox(height: 22),
                      Text('Member concerns',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      if (rows(data!['reports']).isEmpty)
                        const Text('No open reports.'),
                      for (final r in rows(data!['reports']))
                        CirclePanel(children: [
                          Text(
                              '${r['name'] ?? 'Member'} · ${r['circle_name']}'),
                          Text(r['reason'] as String),
                          if (r['message'] != null)
                            Text('Reported message: ${r['message']}'),
                          if (r['message_id'] != null)
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => confirmAction(
                                        'Remove this message?',
                                        'Replace the message with a removal notice in the group conversation.',
                                        'admin_hide_message',
                                        {'id': r['message_id']},
                                        destructive: true),
                                child: const Text('Remove message')),
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => confirmAction(
                                      'Resolve report?',
                                      'Confirm that you have reviewed the concern and followed up with the member.',
                                      'admin_resolve_report',
                                      {'id': r['id']}),
                              child: const Text('Mark resolved')),
                        ]),
                      const SizedBox(height: 22),
                      _suggestionsPanel(context),
                      Text('Applications',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      if (rows(data!['applications']).isEmpty)
                        const Text('No applications waiting yet.'),
                      for (final a in rows(data!['applications']))
                        Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CirclePanel(children: [
                              CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  secondary: CircleMemberAvatar(
                                      a['name']?.toString() ?? '',
                                      photoUrl: a['photo_url'] as String?,
                                      photoPath: a['photo_path'] as String?),
                                  value: selected.contains(a['profile_id']),
                                  onChanged: busy || a['ready'] == false
                                      ? null
                                      : (v) => setState(() => v == true
                                          ? selected
                                              .add(a['profile_id'] as String)
                                          : selected.remove(a['profile_id'])),
                                  title: Text(
                                      '${a['name']} · ${a['age'] ?? 'Age not given'}'),
                                  subtitle: Text(
                                      '${a['city']} · ${strings(a['languages']).join(', ')}\n${strings(a['availability']).join(', ')}')),
                              Text(strings(a['interests']).join(' · ')),
                              ...contactLines(a['phone'] as String?,
                                  a['address'] as String?),
                              if (a['ready'] == false)
                                const Text(
                                    'Needs WhatsApp number, birthday, photo or availability update',
                                    style: TextStyle(color: Colors.deepOrange)),
                              if (strings(a['goals']).isNotEmpty)
                                Text(
                                    'Looking for: ${strings(a['goals']).join(' · ')}'),
                              if (strings(a['life_context']).isNotEmpty)
                                Text(
                                    'Context: ${strings(a['life_context']).join(' · ')}'),
                              Text('Social style: ${[
                                'Warms up slowly',
                                'A little of both',
                                'Breaks the ice'
                              ][(((a['energy'] as num?)?.toDouble() ?? 2) / 2).round().clamp(0, 2)]}'),
                              if (a['hopes'] != null)
                                Text('Hopes: ${a['hopes']}'),
                              if (a['context'] != null)
                                Text('Context: ${a['context']}')
                            ])),
                      const SizedBox(height: 16),
                      CirclePanel(children: [
                        Text('Form a Circle · ${selected.length}/6 selected',
                            style: Theme.of(context).textTheme.headlineSmall),
                        // The database refuses this group anyway. Saying so
                        // here turns a failed save into something the
                        // organiser can fix before trying.
                        if (_blockedPairs().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.block_rounded,
                                    size: 18, color: circleCoral),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        _blockedPairs().length == 1
                                            ? 'Two people here asked not to be matched. Swap one of them out.'
                                            : '${_blockedPairs().length} pairs here asked not to be matched. Swap them out.',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: circleCoral)))
                              ]),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                            controller: name,
                            maxLength: 100,
                            decoration: const InputDecoration(
                                labelText: 'Circle name')),
                        const SizedBox(height: 14),
                        TextField(
                            controller: schedule,
                            maxLength: 100,
                            decoration: const InputDecoration(
                                labelText: 'Schedule description')),
                        const SizedBox(height: 14),
                        OutlinedButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    final now = DateTime.now();
                                    final d = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            now.add(const Duration(days: 14)),
                                        firstDate: now,
                                        lastDate:
                                            now.add(const Duration(days: 365)));
                                    if (d != null && mounted) {
                                      setState(() => start = d);
                                    }
                                  },
                            child: Text(start == null
                                ? 'Choose start date'
                                : circleDate(start!.toIso8601String()))),
                        const SizedBox(height: 10),
                        OutlinedButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    final t = await showTimePicker(
                                        context: context, initialTime: time);
                                    if (t != null && mounted) {
                                      setState(() => time = t);
                                    }
                                  },
                            child: Text(
                                '${time.format(context)} · Netherlands time')),
                        const SizedBox(height: 14),
                        const Text(
                            'Creates six weekly plans and invitations. Choose 5–6 people with overlapping availability and at least one shared language.'),
                        const SizedBox(height: 14),
                        ElevatedButton(
                            onPressed: busy ||
                                    selected.length < 5 ||
                                    selected.length > 6 ||
                                    start == null ||
                                    _blockedPairs().isNotEmpty
                                ? null
                                : () => action('admin_create', {
                                      'members': selected.toList(),
                                      'name': name.text.trim(),
                                      'schedule': schedule.text.trim(),
                                      'start_date': start!
                                          .toIso8601String()
                                          .split('T')
                                          .first,
                                      'time':
                                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                                    }),
                            child: Text(busy
                                ? 'Setting up your Circle…'
                                : 'Create Circle & invitations'))
                      ]),
                      const SizedBox(height: 24),
                      Text('Circles',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      for (final c in rows(data!['circles']))
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: CirclePanel(children: [
                              Text(c['name'] as String,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              Text('${c['schedule']} · ${c['status']}'),
                              if (['offered', 'active'].contains(c['status']))
                                TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => confirmAction(
                                            'Cancel this Circle?',
                                            'Members will be notified, upcoming meetups cancelled, and refund requests created for received payments. Return the money separately and then confirm each refund below.',
                                            'admin_cancel_circle',
                                            {'id': c['id']},
                                            destructive: true),
                                    child: const Text('Cancel Circle')),
                              for (final m in rows(c['meetups']))
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(m['title'] as String),
                                          subtitle: Text(
                                              '${circleDate(m['date'] as String?)} · ${m['completed'] == true ? 'Completed' : 'Planned'}')),
                                      Wrap(spacing: 8, children: [
                                        if (m['completed'] != true)
                                          TextButton.icon(
                                              icon: const Icon(
                                                  Icons.edit_calendar_outlined,
                                                  size: 18),
                                              label: const Text('Edit plan'),
                                              onPressed: busy
                                                  ? null
                                                  : () => scheduleCircleMeetup(
                                                      context,
                                                      (a, [d = const {}]) =>
                                                          action(
                                                              'admin_schedule',
                                                              d),
                                                      meetup: m)),
                                        if (m['completed'] != true)
                                          TextButton.icon(
                                              icon: const Icon(Icons.task_alt,
                                                  size: 18),
                                              label:
                                                  const Text('Mark completed'),
                                              onPressed: busy
                                                  ? null
                                                  : () => action(
                                                      'complete_meetup',
                                                      {'id': m['id']})),
                                        TextButton.icon(
                                            icon: const Icon(
                                                Icons.people_outline,
                                                size: 18),
                                            label: const Text('Attendance'),
                                            onPressed: () => attendance(m)),
                                      ]),
                                    ]),
                            ])),
                      const SizedBox(height: 20),
                      Text('Refund requests',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      if (rows(data!['refunds']).isEmpty)
                        const Text('No refund requests.'),
                      for (final r in rows(data!['refunds']))
                        CirclePanel(children: [
                          Text('${r['name'] ?? 'Member'} · ${r['status']}'),
                          const Text(
                              'Return the money separately, then confirm the refund here.'),
                          if (r['status'] == 'requested')
                            TextButton(
                                onPressed: busy
                                    ? null
                                    : () => widget.repository.isDemo
                                        ? action(
                                            'resolve_refund', {'id': r['id']})
                                        : confirmAction(
                                            'Confirm €19 returned?',
                                            'Only confirm after you have returned the money to the member.',
                                            'admin_confirm_refund',
                                            {'id': r['id'], 'returned': true}),
                                child: const Text('Confirm refund completed'))
                        ]),
                    ]))));
}
