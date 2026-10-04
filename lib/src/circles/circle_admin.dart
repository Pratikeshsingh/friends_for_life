import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/destructive.dart';
import 'circle_home.dart';
import 'circle_matching.dart';
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

const _muted = Color(0xFF66727C);
const _line = Color(0xFFDDE7E3);
const _styleLabels = ['Warms up slowly', 'A little of both', 'Breaks the ice'];

/// Applicant filters on the Applicants tab. Null means "any".
class _ApplicantFilter {
  String query = '';
  bool? ready;
  String? language, day, period, interest;
  bool get active =>
      query.isNotEmpty ||
      ready != null ||
      language != null ||
      day != null ||
      period != null ||
      interest != null;
}

class _CircleAdminState extends State<CircleAdmin>
    with SingleTickerProviderStateMixin {
  Json? data;
  String? error;
  bool busy = false;
  final selected = <String>{};
  final name = TextEditingController(text: t('Alkmaar Founding Circle'));
  final schedule = TextEditingController(text: t('Thursday evenings · 19:30'));
  final search = TextEditingController();
  final formScroll = ScrollController();
  late final TabController tabs = TabController(length: 4, vsync: this);
  DateTime? start;
  TimeOfDay time = const TimeOfDay(hour: 19, minute: 30);
  final filter = _ApplicantFilter();
  String? boardLanguage, boardSlot;
  int showMatches = 6;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    schedule.dispose();
    search.dispose();
    formScroll.dispose();
    tabs.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final d = await widget.repository.adminLoad();
      if (mounted) {
        setState(() {
          data = d;
          error = null;
          // Someone may have been grouped or withdrawn since the last load.
          final ids = {for (final a in applicants) '${a['profile_id']}'};
          selected.retainWhere(ids.contains);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Could not load organiser tools. Check your access and try again.');
      }
    }
  }

  Future<void> action(String action,
      [Json payload = const {}, bool propagate = false]) async {
    setState(() => busy = true);
    try {
      await widget.repository.act(action, payload);
      if (action == 'admin_create') selected.clear();
      await load();
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() => error =
            'That change could not be saved. ${e is StateError ? e.message : e is PostgrestException ? e.message : 'Please try again.'}');
      }
      if (propagate) rethrow;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ---------------------------------------------------------------- data

  List<Json> get applicants => rows(data?['applications']);
  List<Json> get payments => rows(data?['payments']);
  List<Json> get reports => rows(data?['reports']);
  List<Json> get refunds => rows(data?['refunds']);
  List<Json> get circles => rows(data?['circles']);
  List<Json> get awaitingPayment =>
      payments.where((p) => p['status'] == 'awaiting_payment').toList();
  List<Json> get openRefunds =>
      refunds.where((r) => r['status'] == 'requested').toList();
  List<Json> get needsDetails =>
      applicants.where((a) => !isReadyApplicant(a)).toList();
  List<Json> get selectedPeople => [
        for (final a in applicants)
          if (selected.contains('${a['profile_id']}')) a
      ];
  int get todoCount =>
      awaitingPayment.length + reports.length + openRefunds.length;

  Json? applicant(String id) {
    for (final a in applicants) {
      if ('${a['profile_id']}' == id) return a;
    }
    return null;
  }

  /// WhatsApp number, for the organiser only. Payments
  /// only carry a profile id, so their contact comes from 'contacts'.
  Json? contactFor(Object? profileId) {
    final contacts = data?['contacts'];
    if (contacts is! Map || profileId == null) return null;
    final c = contacts[profileId.toString()];
    return c is Map ? Map<String, dynamic>.from(c) : null;
  }

  // ------------------------------------------------------------ actions

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

  void _prefillFor(String day, String period, String language) {
    start = _nextWeekday(day);
    time = _periodStart[period] ?? time;
    name.text = 'The $day Circle';
    schedule.text = '${day}s · $period · $language';
  }

  void _useMatch(CircleMatch match) {
    setState(() {
      selected
        ..clear()
        ..addAll(match.ids);
      _prefillFor(match.day, match.period, match.language);
    });
    tabs.animateTo(2);
    if (formScroll.hasClients) {
      formScroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _toggle(Json a) {
    if (!isReadyApplicant(a)) return;
    final id = '${a['profile_id']}';
    if (!selected.contains(id) && selected.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('A Circle has at most 6 people. Remove someone first.')));
      return;
    }
    setState(() {
      if (!selected.remove(id)) selected.add(id);
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

  /// Messages follow the organiser's app language.
  Future<void> openWhatsApp(String phone, String message) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.https('wa.me', '/$digits', {'text': t(message)});
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp did not open.')));
    }
  }

  List<Widget> contactLines(String? phone,
      {String? whatsAppMessage,
      String whatsAppLabel = 'Send payment link on WhatsApp'}) {
    final hasPhone = phone != null && phone.isNotEmpty;
    return [
      if (hasPhone)
        SelectableText('WhatsApp: $phone')
      else
        const Text('No WhatsApp number yet',
            style: TextStyle(color: Colors.deepOrange)),
      if (hasPhone && whatsAppMessage != null)
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: () => openWhatsApp(phone, whatsAppMessage),
                icon: const Icon(Icons.chat_outlined),
                label: Text(whatsAppLabel))),
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

  // -------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final formLabel =
        selected.isEmpty ? 'Form Circles' : 'Form Circles · ${selected.length}';
    return Scaffold(
        appBar: AppBar(
            title: const Text('Circle organiser'),
            actions: [
              IconButton(
                  onPressed: load,
                  icon: const Icon(Icons.refresh),
                  tooltip: t('Refresh'))
            ],
            bottom: TabBar(
                controller: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: t(todoCount == 0 ? 'To do' : 'To do · $todoCount')),
                  Tab(
                      text: t(data == null
                          ? 'Applicants'
                          : 'Applicants · ${applicants.length}')),
                  Tab(text: t(formLabel)),
                  Tab(text: t('Circles')),
                ])),
        body: data == null
            ? Center(
                child: error == null
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(error!, textAlign: TextAlign.center)))
            : TabBarView(controller: tabs, children: [
                _page(_todoTab(context)),
                _page(_applicantsTab(context)),
                _page(_formTab(context), controller: formScroll),
                _page(_circlesTab(context)),
              ]));
  }

  Widget _page(List<Widget> children, {ScrollController? controller}) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
              children: [
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(error!,
                          style: const TextStyle(color: destructiveRed))),
                ...children
              ])));

  Widget _sectionTitle(BuildContext context, String text, {String? hint}) =>
      Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: Theme.of(context).textTheme.titleLarge),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint, style: const TextStyle(color: _muted, fontSize: 13)),
            ]
          ]));

  // -------------------------------------------------------------- To do

  double _tileWidth = 172;

  Widget _statTile(String label, int value, String hint, VoidCallback? onTap,
      {bool attention = false}) {
    return SizedBox(
        width: _tileWidth,
        child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: attention && value > 0 ? circleCoralText : _line)),
            child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$value',
                              style: TextStyle(
                                  fontSize: 28,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: attention && value > 0
                                      ? circleCoralText
                                      : value == 0
                                          ? _muted
                                          : circleNavy)),
                          const SizedBox(height: 4),
                          Text(label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: circleNavy)),
                          const SizedBox(height: 2),
                          Text(hint,
                              style: const TextStyle(
                                  fontSize: 12, color: _muted, height: 1.3)),
                        ])))));
  }

  void _showApplicants({bool? ready}) {
    setState(() => filter.ready = ready);
    tabs.animateTo(1);
  }

  List<Widget> _todoTab(BuildContext context) {
    final ready = applicants.where(isReadyApplicant).length;
    final running = circles
        .where((c) => ['offered', 'active'].contains(c['status']))
        .length;
    final completed = circles.where((c) => c['status'] == 'completed').length;
    return [
      CircleHeading('Make the introductions.',
          eyebrow: widget.repository.isDemo
              ? 'Preview organiser · example applicants'
              : 'Alkmaar founding pilot',
          subtitle: todoCount > 0
              ? 'Start with what needs you, then form the next Circle.'
              : needsDetails.isNotEmpty
                  ? '${needsDetails.length} ${needsDetails.length == 1 ? 'applicant needs' : 'applicants need'} to finish their profile before they can be matched.'
                  : 'Nothing needs you right now. Form a Circle when a group fits.'),
      LayoutBuilder(builder: (context, box) {
        // Two tiles per row on a phone, fixed-width tiles otherwise.
        _tileWidth = box.maxWidth < 560 ? (box.maxWidth - 12) / 2 : 172;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          // Straight to the recommended groups, where they can be formed.
          _statTile('Ready to match', ready, 'Waiting with complete details',
              () => tabs.animateTo(2)),
          _statTile(
              'Missing details',
              needsDetails.length,
              'Need a number, photo or times',
              () => _showApplicants(ready: false),
              attention: true),
          _statTile('Awaiting payment', awaitingPayment.length,
              'Accepted, not yet paid', null,
              attention: true),
          _statTile(
              'Open reports', reports.length, 'Concerns from members', null,
              attention: true),
          _statTile('Refunds to send', openRefunds.length,
              'Requested by members', null,
              attention: true),
          _statTile('Circles running', running, 'Invited or in progress',
              () => tabs.animateTo(3)),
          _statTile('Completed', completed, 'Circles that finished',
              () => tabs.animateTo(3)),
        ]);
      }),
      const SizedBox(height: 12),
      if (todoCount == 0)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(children: [
              Icon(Icons.check_circle_outline, color: circleTeal),
              SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'All clear. No payments, reports or refunds waiting.')),
            ])),
      if (awaitingPayment.isNotEmpty) ...[
        _sectionTitle(context, 'Payments to confirm',
            hint:
                'Send the link on WhatsApp, then confirm once the money is in.'),
        for (final p in awaitingPayment) _paymentCard(context, p),
      ],
      if (reports.isNotEmpty) ...[
        _sectionTitle(context, 'Member concerns'),
        for (final r in reports) _reportCard(r),
      ],
      if (openRefunds.isNotEmpty) ...[
        _sectionTitle(context, 'Refunds to send',
            hint: 'Return the money separately, then confirm it here.'),
        for (final r in openRefunds) _refundCard(r),
      ],
      if (needsDetails.isNotEmpty) ...[
        _sectionTitle(context, 'Missing details',
            hint:
                'They can’t be matched until they finish their profile. A friendly nudge helps.'),
        for (final a in needsDetails.take(8)) _applicantRow(context, a),
        if (needsDetails.length > 8)
          TextButton(
              onPressed: () => _showApplicants(ready: false),
              child: Text('See all ${needsDetails.length}')),
      ],
    ];
  }

  Widget _card(List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: children)));

  Widget _paymentCard(BuildContext context, Json p) {
    final contact = contactFor(p['profile_id']);
    return _card([
      Text('${p['name'] ?? 'Member'} · ${p['circle_name'] ?? 'Circle'}',
          style: Theme.of(context).textTheme.titleMedium),
      Text(
          '€19 · ${t(circleStatusLabel(p['status']))} · ${t('agreed')} ${circleDate(p['agreed_at']?.toString())}',
          style: const TextStyle(color: _muted)),
      SelectableText(p['email']?.toString() ?? 'Account removed'),
      ...contactLines(contact?['phone'] as String?,
          whatsAppMessage: p['status'] == 'awaiting_payment'
              ? 'Hi ${p['name'] ?? 'there'}! Welcome to your VriendTime Circle "${p['circle_name'] ?? ''}". Here is your link for the one-off €19 programme fee: '
              : null),
      if (p['status'] == 'awaiting_payment')
        Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
                onPressed: busy
                    ? null
                    : () => confirmAction(
                        'Confirm €19 received?',
                        'Only confirm after you have checked the money arrived. This unlocks the member’s Circle and group chat.',
                        'admin_confirm_payment',
                        {'id': p['id'], 'received': true}),
                child: const Text('Confirm payment received'))),
    ]);
  }

  Widget _reportCard(Json r) => _card([
        Text('${r['name'] ?? 'Member'} · ${r['circle_name']}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(r['reason'] as String? ?? ''),
        if (r['message'] != null)
          Text('Reported message: ${r['message']}',
              style: const TextStyle(color: _muted)),
        Wrap(spacing: 8, children: [
          if (r['message_id'] != null)
            TextButton(
                style: destructiveTextStyle,
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
      ]);

  Widget _refundCard(Json r) => _card([
        Text('${r['name'] ?? 'Member'} · ${t(circleStatusLabel(r['status']))}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        if (r['email'] != null) SelectableText('${r['email']}'),
        if (r['status'] == 'requested')
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: busy
                      ? null
                      : () => widget.repository.isDemo
                          ? action('resolve_refund', {'id': r['id']})
                          : confirmAction(
                              'Confirm €19 returned?',
                              'Only confirm after you have returned the money to the member.',
                              'admin_confirm_refund',
                              {'id': r['id'], 'returned': true}),
                  child: const Text('Confirm refund completed'))),
      ]);

  // --------------------------------------------------------- Applicants

  List<String> get _allInterests {
    final all = <String>{
      for (final a in applicants) ...strings(a['interests']),
      for (final a in applicants) ...strings(a['activities'])
    }.toList()
      ..sort();
    return all;
  }

  bool _matches(Json a) {
    final q = filter.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final hay = [
        a['name'],
        a['phone'],
        ...strings(a['interests']),
        ...strings(a['activities'])
      ].join(' ').toLowerCase();
      if (!hay.contains(q)) return false;
    }
    if (filter.ready != null && isReadyApplicant(a) != filter.ready) {
      return false;
    }
    if (filter.language != null &&
        !strings(a['languages']).contains(filter.language)) {
      return false;
    }
    final slots = strings(a['availability']);
    if (filter.day != null && filter.period != null) {
      if (!slots.contains('${filter.day} ${filter.period}')) return false;
    } else if (filter.day != null) {
      if (!slots.any((s) => s.startsWith('${filter.day} '))) return false;
    } else if (filter.period != null) {
      if (!slots.any((s) => s.endsWith(' ${filter.period}'))) return false;
    }
    if (filter.interest != null &&
        !strings(a['interests']).contains(filter.interest) &&
        !strings(a['activities']).contains(filter.interest)) {
      return false;
    }
    return true;
  }

  Widget _dropdown(String label, String? value, List<String> options,
      ValueChanged<String?> onChanged) {
    return SizedBox(
        width: 168,
        child: DropdownButtonFormField<String?>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: label,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Any')),
              for (final o in options)
                DropdownMenuItem<String?>(
                    value: o, child: Text(o, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => onChanged(v))));
  }

  List<Widget> _applicantsTab(BuildContext context) {
    final shown = applicants.where(_matches).toList();
    return [
      TextField(
          controller: search,
          onChanged: (v) => setState(() => filter.query = v),
          decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: t('Search name, number or interest'),
              isDense: true,
              suffixIcon: filter.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: t('Clear search'),
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                            search.clear();
                            filter.query = '';
                          })))),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final entry in {
          null: 'Everyone',
          true: 'Ready to match',
          false: 'Missing details'
        }.entries)
          ChoiceChip(
              label: Text(entry.value),
              selected: filter.ready == entry.key,
              onSelected: (_) => setState(() => filter.ready = entry.key)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _dropdown('Language', filter.language, circleLanguages,
            (v) => filter.language = v),
        _dropdown('Day', filter.day, circleDays, (v) => filter.day = v),
        _dropdown('Time of day', filter.period, circlePeriods,
            (v) => filter.period = v),
        _dropdown('Interest', filter.interest, _allInterests,
            (v) => filter.interest = v),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: Text(
                filter.active
                    ? '${shown.length} of ${applicants.length} applicants'
                    : '${applicants.length} applicants, longest waiting first',
                style: const TextStyle(color: _muted))),
        if (filter.active)
          TextButton(
              onPressed: () => setState(() {
                    search.clear();
                    filter
                      ..query = ''
                      ..ready = null
                      ..language = null
                      ..day = null
                      ..period = null
                      ..interest = null;
                  }),
              child: const Text('Clear filters')),
      ]),
      if (selected.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Row(children: [
              Expanded(
                  child: Text('${selected.length} selected for a new Circle',
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              FilledButton(
                  onPressed: () => tabs.animateTo(2),
                  child: const Text('Review group')),
            ])),
      const SizedBox(height: 4),
      if (applicants.isEmpty) const Text('No applications waiting yet.'),
      if (applicants.isNotEmpty && shown.isEmpty)
        const Text('Nobody matches these filters.'),
      for (final a in shown) _applicantRow(context, a),
    ];
  }

  String _slotSummary(Json a) {
    final slots = strings(a['availability']);
    if (slots.isEmpty) return 'No times yet';
    final short = slots
        .map((s) => s
            .replaceAllMapped(RegExp(r'^(\w{3})\w*'), (m) => m.group(1)!)
            .replaceAll('morning', 'am')
            .replaceAll('afternoon', 'pm')
            .replaceAll('evening', 'eve'))
        .toList();
    return short.length <= 3
        ? short.join(', ')
        : '${short.take(3).join(', ')} +${short.length - 3}';
  }

  Widget _applicantRow(BuildContext context, Json a) {
    final id = '${a['profile_id']}';
    final ready = isReadyApplicant(a);
    final isSelected = selected.contains(id);
    final waiting = waitingLabel(a);
    final meta = [
      if (a['age'] != null) '${a['age']}',
      strings(a['languages'])
          .map((l) => l == 'English' ? 'EN' : 'NL')
          .join('/'),
      if (waiting.isNotEmpty) waiting,
      if (a['moving'] == true) t('Moving · already paid'),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
            color: isSelected ? const Color(0xFFEAF7F5) : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isSelected ? circleTeal : _line)),
            child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openApplicant(a),
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                    child: Row(children: [
                      // Only ready people can be picked; others keep the
                      // same indent so the rows still line up.
                      if (ready)
                        Checkbox(
                            value: isSelected,
                            onChanged: busy ? null : (_) => _toggle(a))
                      else
                        const SizedBox(width: 48),
                      CircleMemberAvatar(a['name']?.toString() ?? '',
                          radius: 20,
                          photoUrl: a['photo_url'] as String?,
                          photoPath: a['photo_path'] as String?),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${a['name'] ?? 'Someone'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: circleNavy)),
                            Text(meta,
                                style: const TextStyle(
                                    fontSize: 12, color: _muted)),
                            Text(_slotSummary(a),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          ])),
                      if (!ready)
                        Tooltip(
                            message: t('Missing details'),
                            child: Icon(Icons.error_outline,
                                color: Colors.deepOrange, size: 20))
                      else
                        const Icon(Icons.chevron_right, color: _muted),
                    ])))));
  }

  Future<void> _openApplicant(Json a) async {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    Widget content(BuildContext c, ScrollController? scroll) => StatefulBuilder(
        builder: (c, update) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(24),
            children: _applicantDetails(c, a, () {
              _toggle(a);
              update(() {});
            })));
    if (wide) {
      await showDialog<void>(
          context: context,
          builder: (c) => Align(
              alignment: Alignment.centerRight,
              child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: SizedBox(
                      width: 440,
                      height: double.infinity,
                      child: SafeArea(child: content(c, null))))));
    } else {
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (c) => DraggableScrollableSheet(
              expand: false,
              initialChildSize: .85,
              maxChildSize: .95,
              builder: (c, scroll) => content(c, scroll)));
    }
  }

  List<Widget> _applicantDetails(
      BuildContext context, Json a, VoidCallback onToggle) {
    final id = '${a['profile_id']}';
    final ready = isReadyApplicant(a);
    final isSelected = selected.contains(id);
    Widget chips(String label, List<String> values) => values.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _muted)),
              const SizedBox(height: 6),
              Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final v in values) CirclePill(v)]),
            ]));
    final style = _styleLabels[
        (((a['energy'] as num?)?.toDouble() ?? 2) / 2).round().clamp(0, 2)];
    return [
      Row(children: [
        CircleMemberAvatar(a['name']?.toString() ?? '',
            radius: 32,
            photoUrl: a['photo_url'] as String?,
            photoPath: a['photo_path'] as String?),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${a['name'] ?? 'Someone'}',
              style: Theme.of(context).textTheme.titleLarge),
          Text(
              [
                if (a['age'] != null) '${a['age']}',
                '${a['city'] ?? 'Alkmaar'}',
                if (waitingLabel(a).isNotEmpty) waitingLabel(a)
              ].join(' · '),
              style: const TextStyle(color: _muted)),
        ])),
        IconButton(
            tooltip: t('Close'),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
      ]),
      const SizedBox(height: 16),
      if (a['moving'] == true)
        Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFEAF7F5),
                borderRadius: BorderRadius.circular(14)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Moving from another Circle',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: circleNavy)),
              const SizedBox(height: 4),
              const Text(
                  'Already paid: their next Circle is free. Place them first. If no group fits in time, refund them instead.'),
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: circleCoralText),
                      onPressed: busy || a['move_id'] == null
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await confirmAction(
                                  'Refund instead of moving?',
                                  'They leave the waiting list and appear under Refunds to send. Confirm there once you have returned the €19.',
                                  'admin_refund_move',
                                  {'id': a['move_id']},
                                  destructive: true);
                            },
                      child: const Text('Refund instead'))),
            ])),
      if (!ready)
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
                'Missing details: needs a WhatsApp number, birthday, photo or updated times before matching.',
                style: TextStyle(color: Colors.deepOrange))),
      ...contactLines(a['phone'] as String?,
          whatsAppLabel:
              ready ? 'Message on WhatsApp' : 'Ask to finish profile',
          whatsAppMessage: ready
              ? 'Hi ${a['name'] ?? 'there'}! This is the VriendTime organiser. '
              : 'Hi ${a['name'] ?? 'there'}! This is the VriendTime organiser. You’re nearly on the list for a Circle. Could you open the app and finish your profile? Then we can match you.'),
      const SizedBox(height: 8),
      if (ready)
        Align(
            alignment: Alignment.centerLeft,
            child: isSelected
                ? OutlinedButton.icon(
                    onPressed: busy ? null : onToggle,
                    icon: const Icon(Icons.remove),
                    label: const Text('Remove from new Circle'))
                : FilledButton.icon(
                    onPressed: busy || selected.length >= 6 ? null : onToggle,
                    icon: const Icon(Icons.add),
                    label: Text(selected.length >= 6
                        ? 'New Circle is full'
                        : 'Add to new Circle'))),
      chips('Free', strings(a['availability'])),
      chips('Speaks', strings(a['languages'])),
      chips('Interests', strings(a['interests'])),
      chips('Looking for', strings(a['goals'])),
      chips('Context', strings(a['life_context'])),
      chips('Social style', [style]),
      if ('${a['intro'] ?? ''}'.trim().isNotEmpty) ...[
        const SizedBox(height: 14),
        const Text('Intro',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _muted)),
        const SizedBox(height: 4),
        Text('${a['intro']}'),
      ],
      if (a['hopes'] != null) Text('Hopes: ${a['hopes']}'),
      if (a['context'] != null) Text('Context: ${a['context']}'),
    ];
  }

  // ------------------------------------------------------- Form Circles

  List<Widget> _formTab(BuildContext context) {
    final exclusions = circleExclusions(data);
    final plan = planCircles(applicants,
        exclusions: exclusions, language: boardLanguage);
    bool inSlot(CircleMatch m) => boardSlot == null || m.slot == boardSlot;
    final complete = plan.complete.where(inSlot).toList();
    final forming = plan.forming.where(inSlot).toList();
    final readyCount = applicants.where(isReadyApplicant).length;
    return [
      if (selected.isNotEmpty) _selectionPanel(context, exclusions),
      _sectionTitle(context, 'When people are free',
          hint:
              'Ready applicants per day and time. Tap a cell to see groups for that slot.'),
      _availabilityGrid(context),
      _sectionTitle(
          context,
          boardSlot == null
              ? 'Recommended groups'
              : 'Recommended groups on $boardSlot',
          hint:
              'Everyone is placed in one group only. Same language and time for everyone, ranked by shared interests and goals, age, social mix and waiting time.'),
      if (readyCount == 0)
        const Text(
            'Nobody is ready to match yet. People need a WhatsApp number, birthday, photo and times first.')
      else
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              CirclePill('$readyCount ready to match',
                  icon: Icons.people_outline),
              CirclePill('${plan.complete.length} complete',
                  icon: Icons.check_circle_outline),
              CirclePill('${plan.forming.length} forming',
                  icon: Icons.group_add_outlined),
              if (plan.unmatched.isNotEmpty)
                CirclePill('${plan.unmatched.length} not matched yet',
                    icon: Icons.person_search_outlined),
            ])),
      if (complete.isNotEmpty) ...[
        _subTitle('Ready to create'),
        for (final m in complete) _matchCard(context, m),
      ],
      if (forming.isNotEmpty) ...[
        _subTitle('Forming',
            hint:
                'These people fit together. The group still needs more people who share their language and time.'),
        for (final m in forming.take(showMatches)) _matchCard(context, m),
        if (forming.length > showMatches)
          TextButton(
              onPressed: () => setState(() => showMatches += 6),
              child: Text('Show more (${forming.length - showMatches} left)')),
      ],
      if (readyCount > 0 && complete.isEmpty && forming.isEmpty)
        Text(boardSlot != null
            ? 'No group on $boardSlot yet.'
            : 'No groups yet. People need to share a language and a time.'),
      if (plan.unmatched.isNotEmpty && boardSlot == null) ...[
        _subTitle('Not matched yet',
            hint:
                'Nobody else shares a language and a time with them yet. Asking them to add more times helps.'),
        for (final a in plan.unmatched) _applicantRow(context, a),
      ],
      if (selected.isEmpty) ...[
        const SizedBox(height: 12),
        const Text(
            'Or build a group by hand: tick people on the Applicants tab.',
            style: TextStyle(color: _muted)),
      ],
    ];
  }

  Widget _subTitle(String text, {String? hint}) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, color: circleNavy)),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint, style: const TextStyle(color: _muted, fontSize: 13)),
        ]
      ]));

  Widget _availabilityGrid(BuildContext context) {
    final counts = availabilityCounts(applicants, language: boardLanguage);
    final maxCount =
        counts.values.fold<int>(0, (a, b) => b > a ? b : a).clamp(1, 1 << 30);
    Widget cell(String day, String period, double size) {
      final slot = '$day $period';
      final n = counts[slot] ?? 0;
      final chosen = boardSlot == slot;
      final strength = n / maxCount;
      return Padding(
          padding: const EdgeInsets.all(3),
          child: Material(
              color: chosen
                  ? circleNavy
                  : n == 0
                      ? const Color(0xFFF3F1EC)
                      : Color.lerp(
                          const Color(0xFFE3F4F1), circleTeal, strength * .75),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: n == 0
                      ? null
                      : () => setState(() {
                            boardSlot = chosen ? null : slot;
                            showMatches = 6;
                          }),
                  child: SizedBox(
                      width: size,
                      height: 40,
                      child: Center(
                          child: Text(n == 0 ? '–' : '$n',
                              semanticsLabel: t('$n free on $slot'),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: chosen || strength > .55
                                      ? Colors.white
                                      : circleNavy)))))));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, children: [
        for (final entry in {
          null: 'All languages',
          'English': 'English',
          'Dutch': 'Dutch'
        }.entries)
          ChoiceChip(
              label: Text(entry.value),
              selected: boardLanguage == entry.key,
              onSelected: (_) => setState(() {
                    boardLanguage = entry.key;
                    showMatches = 6;
                  })),
        if (boardSlot != null)
          InputChip(
              label: Text(boardSlot!),
              onDeleted: () => setState(() => boardSlot = null)),
      ]),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, box) {
        // Seven columns must fit a 320px phone, so cells shrink to fit.
        const labelWidth = 70.0;
        final size = ((box.maxWidth - labelWidth) / 7 - 6).clamp(30.0, 46.0);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const SizedBox(width: labelWidth),
            for (final d in circleDays)
              SizedBox(
                  width: size + 6,
                  child: Center(
                      child: Text(d.substring(0, 3),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _muted)))),
          ]),
          for (final p in circlePeriods)
            Row(children: [
              SizedBox(
                  width: labelWidth,
                  child: Text(p[0].toUpperCase() + p.substring(1),
                      style: const TextStyle(fontSize: 12, color: _muted))),
              for (final d in circleDays) cell(d, p, size),
            ]),
        ]);
      }),
    ]);
  }

  Widget _matchCard(BuildContext context, CircleMatch m) {
    final title = m.complete
        ? '${m.members.length} people · ${m.slot} · ${m.language}'
        : '${m.members.length} fit together · ${m.slot} · ${m.language} · ${m.missing} more needed';
    return _card([
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: circleNavy))),
        const SizedBox(width: 8),
        // Tappable as well as hoverable: on a phone there is no hover.
        Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 6),
            message: t(
                'A guide for your judgement, not a verdict. Out of 100: interests, goals, age, social mix, shared situation and waiting time.'),
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: m.score >= 70
                        ? const Color(0xFFE3F4F1)
                        : const Color(0xFFF3F1EC),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Match fit ${m.score}/100',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: _muted),
                ]))),
      ]),
      const SizedBox(height: 6),
      Wrap(spacing: 10, runSpacing: 8, children: [
        for (final p in m.members)
          InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _openApplicant(p),
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleMemberAvatar(p['name']?.toString() ?? '',
                        radius: 14,
                        photoUrl: p['photo_url'] as String?,
                        photoPath: p['photo_path'] as String?),
                    const SizedBox(width: 6),
                    Text('${p['name'] ?? 'Someone'}'),
                  ]))),
      ]),
      const SizedBox(height: 8),
      for (final r in m.reasons.skip(2))
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Icon(Icons.check, size: 14, color: circleTeal)),
          const SizedBox(width: 6),
          Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
        ]),
      if (!m.complete && m.nearlyFree.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text('Could complete it if they widen their times:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        for (final p in m.nearlyFree)
          Row(children: [
            Expanded(
                child: Text(
                    '${p['name'] ?? 'Someone'} · free ${_slotSummary(p)}',
                    style: const TextStyle(fontSize: 13))),
            if ('${p['phone'] ?? ''}'.isNotEmpty)
              TextButton(
                  onPressed: () => openWhatsApp('${p['phone']}',
                      'Hi ${p['name'] ?? 'there'}! This is the VriendTime organiser. We’re forming a Circle on ${m.slot}s with people who share your interests. Would that time work for you too? If so, add it to your availability in the app.'),
                  child: const Text('Ask')),
          ]),
      ],
      const SizedBox(height: 6),
      Align(
          alignment: Alignment.centerLeft,
          child: m.complete
              ? FilledButton(
                  onPressed: busy ? null : () => _useMatch(m),
                  child: const Text('Use this group'))
              : OutlinedButton(
                  onPressed: busy ? null : () => _useMatch(m),
                  child: const Text('Start with these people'))),
    ]);
  }

  Widget _selectionPanel(BuildContext context, Set<String> exclusions) {
    final people = selectedPeople;
    final common = commonGround(people);
    final blocked = _blockedPairs();
    final slot = common.slots.isEmpty ? null : common.slots.first;
    final language = common.languages.isEmpty ? null : common.languages.first;
    final ready = applicants.where(isReadyApplicant).toList();
    final rank = {
      for (var i = 0; i < ready.length; i++) '${ready[i]['profile_id']}': i
    };
    final explained = slot != null && language != null && people.length >= 2
        ? explainGroup(people,
            language: language,
            slot: slot,
            seniorityRank: (a) => rank['${a['profile_id']}'] ?? ready.length,
            poolSize: ready.length)
        : null;
    final fillers = slot != null && language != null && people.length < 6
        ? replacementsFor(applicants, people,
                slot: slot, language: language, exclusions: exclusions)
            .take(4)
            .toList()
        : const <Json>[];
    final problems = <String>[
      if (people.length < 5) 'Add ${5 - people.length} more (5–6 people).',
      if (common.slots.isEmpty && people.length > 1)
        'No shared time: these people have no day and time in common.',
      if (common.languages.isEmpty && people.length > 1) 'No shared language.',
      if (blocked.isNotEmpty)
        blocked.length == 1
            ? 'Two people here asked not to be matched. Swap one of them out.'
            : '${blocked.length} pairs here asked not to be matched. Swap them out.',
    ];
    return CirclePanel(tint: true, children: [
      Row(children: [
        Expanded(
            child: Text('Your new Circle · ${people.length}/6',
                style: Theme.of(context).textTheme.titleLarge)),
        TextButton(
            onPressed: busy ? null : () => setState(selected.clear),
            child: const Text('Clear')),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in people)
          InputChip(
              avatar: CircleMemberAvatar(p['name']?.toString() ?? '',
                  radius: 12,
                  photoUrl: p['photo_url'] as String?,
                  photoPath: p['photo_path'] as String?),
              label: Text('${p['name'] ?? 'Someone'}'),
              onPressed: () => _openApplicant(p),
              onDeleted: busy ? null : () => _toggle(p)),
      ]),
      if (explained != null) ...[
        const SizedBox(height: 12),
        Text(
            'Match fit ${explained.score}/100 · ${explained.reasons.join(' · ')}',
            style: const TextStyle(fontSize: 13)),
        if (common.slots.length > 1)
          Text('Also all free: ${common.slots.skip(1).join(', ')}',
              style: const TextStyle(fontSize: 12, color: _muted)),
      ],
      for (final p in problems)
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, size: 16, color: circleCoral),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(p,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: circleCoralText))),
            ])),
      if (fillers.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Good fits free on $slot',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final f in fillers)
          Row(children: [
            Expanded(
                child: Text(
                    '${f['name'] ?? 'Someone'}${f['age'] == null ? '' : ', ${f['age']}'} · ${strings(f['interests']).take(3).join(', ')}',
                    style: const TextStyle(fontSize: 13))),
            TextButton(
                onPressed: busy ? null : () => _toggle(f),
                child: const Text('Add')),
          ]),
      ],
      const Divider(height: 28),
      TextField(
          controller: name,
          maxLength: 100,
          decoration: InputDecoration(labelText: t('Circle name'))),
      const SizedBox(height: 10),
      TextField(
          controller: schedule,
          maxLength: 100,
          decoration: InputDecoration(labelText: t('Schedule description'))),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton.icon(
            icon: const Icon(Icons.event_outlined, size: 18),
            onPressed: busy
                ? null
                : () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                        context: context,
                        initialDate: start ?? now.add(const Duration(days: 14)),
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)));
                    if (d != null && mounted) setState(() => start = d);
                  },
            label: Text(start == null
                ? 'Choose start date'
                : circleDate(start!.toIso8601String()))),
        OutlinedButton.icon(
            icon: const Icon(Icons.schedule, size: 18),
            onPressed: busy
                ? null
                : () async {
                    final t = await showTimePicker(
                        context: context, initialTime: time);
                    if (t != null && mounted) setState(() => time = t);
                  },
            label: Text('${time.format(context)} · Netherlands time')),
      ]),
      const SizedBox(height: 10),
      const Text('Creates six weekly plans and sends the invitations.',
          style: TextStyle(fontSize: 12, color: _muted)),
      const SizedBox(height: 10),
      ElevatedButton(
          onPressed: busy ||
                  people.length < 5 ||
                  people.length > 6 ||
                  start == null ||
                  blocked.isNotEmpty ||
                  common.slots.isEmpty ||
                  common.languages.isEmpty
              ? null
              : () => action('admin_create', {
                    'members': selected.toList(),
                    'name': name.text.trim(),
                    'schedule': schedule.text.trim(),
                    'start_date': start!.toIso8601String().split('T').first,
                    'time':
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                  }),
          child: Text(busy
              ? 'Setting up your Circle…'
              : 'Create Circle & invitations')),
      const SizedBox(height: 8),
    ]);
  }

  // ------------------------------------------------------------ Circles

  List<Widget> _circlesTab(BuildContext context) {
    final otherPayments =
        payments.where((p) => p['status'] != 'awaiting_payment').toList();
    return [
      _sectionTitle(context, 'Circles'),
      if (circles.isEmpty) const Text('No Circles yet.'),
      for (final c in circles) _circleCard(context, c),
      _sectionTitle(context, 'Payment history'),
      if (payments.isEmpty) const Text('No accepted invitations yet.'),
      if (awaitingPayment.isNotEmpty)
        Text(
            '${awaitingPayment.length} waiting for payment: see the To do tab.',
            style: const TextStyle(color: _muted)),
      for (final p in otherPayments)
        _card([
          Text('${p['name'] ?? 'Member'} · ${p['circle_name'] ?? 'Circle'}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
              '€19 · ${t(circleStatusLabel(p['status']))} · ${t('agreed')} ${circleDate(p['agreed_at']?.toString())}',
              style: const TextStyle(color: _muted)),
        ]),
      _sectionTitle(context, 'Refunds'),
      if (refunds.isEmpty) const Text('No refund requests.'),
      for (final r in refunds) _refundCard(r),
    ];
  }

  Widget _circleCard(BuildContext context, Json c) => _card([
        Text(c['name'] as String? ?? 'Circle',
            style: Theme.of(context).textTheme.titleMedium),
        if (c['paid_members'] != null && (c['paid_members'] as num) < 5)
          Text(
              '${c['paid_members']}/5 paid places. Confirm enough people are joining before the first meetup.',
              style: const TextStyle(color: Colors.deepOrange)),
        Text('${c['schedule']} · ${t(circleStatusLabel(c['status']))}',
            style: const TextStyle(color: _muted)),
        if (['offered', 'active'].contains(c['status']))
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  style: destructiveTextStyle,
                  onPressed: busy
                      ? null
                      : () => confirmAction(
                          'Cancel this Circle?',
                          'Members will be notified, upcoming meetups cancelled, and refund requests created for received payments. Return the money separately and then confirm each refund on the To do tab.',
                          'admin_cancel_circle',
                          {'id': c['id']},
                          destructive: true),
                  child: const Text('Cancel Circle'))),
        for (final m in rows(c['meetups']))
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(m['title'] as String? ?? 'Meetup'),
                subtitle: Text(
                    '${circleDate(m['date'] as String?)} · ${m['completed'] == true ? 'Completed' : 'Planned'}')),
            Wrap(spacing: 8, children: [
              if (m['completed'] != true)
                TextButton.icon(
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: const Text('Edit plan'),
                    onPressed: busy
                        ? null
                        : () => scheduleCircleMeetup(
                            context,
                            (a, [d = const {}]) =>
                                action('admin_schedule', d, true),
                            organiser: true,
                            meetup: m)),
              if (m['completed'] != true && circleMeetupPast(m))
                TextButton.icon(
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: const Text('Mark completed'),
                    onPressed: busy
                        ? null
                        : () => action('complete_meetup', {'id': m['id']})),
              if (circleMeetupPast(m))
                TextButton.icon(
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: const Text('Attendance'),
                    onPressed: () => attendance(m))
              else
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Attendance after the meetup',
                        style: TextStyle(fontSize: 12, color: _muted))),
            ]),
          ]),
      ]);
}
