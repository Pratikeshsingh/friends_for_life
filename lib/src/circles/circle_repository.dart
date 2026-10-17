import 'dart:convert';
import 'dart:math';
import '../core/i18n.dart' show isDutch, t;
import '../core/profile_photo_service.dart';
import 'circle_preferences.dart' show circleDays;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef Json = Map<String, dynamic>;

String circleRequestId() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// The six weeks, told the same way everywhere: landing page, invitation,
/// the weekly plan and the organiser panel. Afternoon and evening Circles
/// share one plan; morning Circles meet in cafés and get their own. Weeks 2
/// and 4 are included in the fee; week 5 is the group's own.
const circleWeekTitles = [
  'Hello, new faces',
  'Find out who’s secretly competitive',
  'Go beyond “what do you do?”',
  'The rematch',
  'Your call',
  'Graduation: a new beginning',
];

/// The same six weeks for morning Circles.
const circleMorningWeekTitles = [
  'Hello, new faces',
  'Find out who’s secretly competitive',
  'Go beyond “what do you do?”',
  'Say cheese',
  'Your call',
  'Graduation: a new beginning',
];

/// Kept for older call sites: the meetup titles are the week titles.
const circleActivities = circleWeekTitles;

/// The weeks whose activity is paid for by the fee (1–6).
const circleIncludedWeeks = {2, 4};

/// One short line per week, for the six-week timeline.
const circleWeekShort = [
  'A relaxed first drink or coffee to meet everyone.',
  'A playful challenge to break the ice.',
  'A long meal together, now that you know each other.',
  'A second challenge. Who wins this time?',
  'Your group picks the plan, the place and the time.',
  'Celebrate six weeks together. Then your group carries on, with no further VriendTime fee.',
];

/// The timeline's lines for morning Circles.
const circleMorningWeekShort = [
  'A relaxed first coffee to meet everyone.',
  'A playful challenge to break the ice.',
  'A shared brunch, now that you know each other.',
  'Something to discover together, indoors.',
  'Your group picks the plan, the place and the time.',
  'A celebration brunch. Then your group carries on, with no further VriendTime fee.',
];

/// The fuller description, on each week's card.
const circleWeekNotes = [
  'Everyone is new here, so it’s an easy start: a drink or a coffee and a first chat. Leaving early is fine, but the first meetup is the one worth staying for.',
  'A playful challenge to break the ice. It’s included in your fee: just show up.',
  'A long meal together. We book the table; you pay for your own food and drinks.',
  'A second challenge, also included in your fee. Who wins this time?',
  'Your group’s week: talk it over in the chat, choose what to do, where and the start time, then save it with “Plan it together”.',
  'Your graduation: we book the table to celebrate six weeks together. You pay for yourself, and your group carries on afterwards with no further VriendTime fee.',
];

/// The fuller description for morning Circles.
const circleMorningWeekNotes = [
  'Everyone is new here, so it’s an easy start: a coffee and a first chat. Leaving early is fine, but the first meetup is the one worth staying for.',
  'A playful challenge to break the ice. It’s included in your fee: just show up.',
  'A shared brunch together. We book the table; you pay for your own.',
  'Something to discover together, indoors. It’s included in your fee.',
  'Your group’s week: talk it over in the chat, choose what to do, where and the start time, then save it with “Plan it together”.',
  'Your graduation: we book the table for a celebration brunch. You pay for yourself, and your group carries on afterwards with no further VriendTime fee.',
];

typedef _DemoWeek = ({
  String time,
  String? venue,
  String? address,
  String cost
});

/// The plans as the database has them (20261035), for the demo.
const List<_DemoWeek> _demoEvening = [
  (
    time: '20:00',
    venue: '1480 Foodbar',
    address: 'Mient 16',
    cost: 'You pay for your own drinks.'
  ),
  (
    time: '20:00',
    venue: 'The Boules Club',
    address: 'Noorderkade 108',
    cost:
        'Included in your fee: we book and pay for the court. Drinks are on you.'
  ),
  (
    time: '19:00',
    venue: 'Rozey Alkmaar',
    address: 'Gedempte Nieuwesloot 4B',
    cost:
        'About €38 per person, or €43 from Friday to Sunday: dinner and drinks, all you can eat.'
  ),
  (
    time: '20:00',
    venue: 'The Hangout',
    address: 'Kwakelkade 10',
    cost:
        'Included in your fee: we book and pay for the game. Drinks are on you.'
  ),
  (time: '20:00', venue: null, address: null, cost: 'Up to your group.'),
  (
    time: '20:00',
    venue: 'Hofman',
    address: 'Kerkplein 7',
    cost:
        'Drinks and sharing bites, about €15–20 per person. You pay for yourself.'
  ),
];
const List<_DemoWeek> _demoAfternoon = [
  (
    time: '14:00',
    venue: 'Grand Café Klunder',
    address: 'Canadaplein 2',
    cost: 'You pay for your own coffee or drinks.'
  ),
  (
    time: '14:00',
    venue: 'De Spellentoren',
    address: 'Schoutenstraat 28',
    cost:
        'Included in your fee: entry to the board-game room. Drinks are on you.'
  ),
  (
    time: '14:00',
    venue: 'Rozey Alkmaar',
    address: 'Gedempte Nieuwesloot 4B',
    cost: 'About €35 per person: lunch and drinks, all you can eat.'
  ),
  (
    time: '14:00',
    venue: 'The Hangout',
    address: 'Kwakelkade 10',
    cost:
        'Included in your fee: we book and pay for the game. Drinks are on you.'
  ),
  (time: '14:00', venue: null, address: null, cost: 'Up to your group.'),
  (
    time: '14:00',
    venue: 'Hofman',
    address: 'Kerkplein 7',
    cost:
        'Drinks and sharing bites, about €15–20 per person. You pay for yourself.'
  ),
];
const List<_DemoWeek> _demoMorning = [
  (
    time: '10:30',
    venue: 'Grand Café Klunder',
    address: 'Canadaplein 2',
    cost: 'You pay for your own coffee.'
  ),
  (
    time: '10:30',
    venue: 'De Spellentoren',
    address: 'Schoutenstraat 28',
    cost:
        'Included in your fee: entry to the board-game room. Coffee is on you.'
  ),
  (
    time: '10:30',
    venue: 'Soepp',
    address: 'Hekelstraat 31',
    cost: 'A shared brunch, about €25 per person. You pay for yourself.'
  ),
  (
    time: '10:30',
    venue: 'Hollands Kaasmuseum',
    address: 'Waagplein 2',
    cost: 'Included in your fee: your museum tickets.'
  ),
  (time: '10:30', venue: null, address: null, cost: 'Up to your group.'),
  (
    time: '10:30',
    venue: 'Hofman',
    address: 'Kerkplein 7',
    cost: 'Brunch, about €15–20 per person. You pay for yourself.'
  ),
];

/// A meetup's title as saved; organisers' own titles are kept.
String circleMeetupTitle(Json meetup) => '${meetup['title'] ?? ''}';

/// The hour a meetup starts, Netherlands time.
int circleMeetupHour(Json meetup) {
  final time = '${meetup['time'] ?? ''}';
  final hour = int.tryParse(time.split(':').first);
  if (hour != null && time.contains(':')) return hour;
  final start = DateTime.tryParse('${meetup['starts_at'] ?? ''}');
  return start == null ? 19 : circleAmsterdam(start).hour;
}

/// The description of a programme week, only while the week still has our
/// plan's title: older Circles and weeks planned differently keep their own
/// story. Morning Circles (starting before noon) get the morning lines.
String? circleWeekNote(Json meetup) {
  final week = meetup['week'];
  if (week is! int || week < 1 || week > 6) return null;
  final morning = circleMeetupHour(meetup) < 12;
  final titles = morning ? circleMorningWeekTitles : circleWeekTitles;
  if (circleMeetupTitle(meetup) != titles[week - 1]) return null;
  return (morning ? circleMorningWeekNotes : circleWeekNotes)[week - 1];
}

List<Json> rows(dynamic value) => (value as List? ?? [])
    .map((v) => Map<String, dynamic>.from(v as Map))
    .toList();
List<String> strings(dynamic value) =>
    (value as List? ?? []).map((v) => v.toString()).toList();
String circleDate(String? raw) {
  final date = DateTime.tryParse(raw ?? '');
  if (date == null) return 'To be arranged';
  if (isDutch) {
    const months = [
      'jan', 'feb', 'mrt', 'apr', 'mei', 'jun', //
      'jul', 'aug', 'sep', 'okt', 'nov', 'dec'
    ];
    const days = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

/// When a meetup begins, from the date and time the server sends as separate
/// strings in the circle's own timezone. Null when either is missing.
DateTime? circleMeetupStart(Json meetup) {
  final instant = DateTime.tryParse('${meetup['starts_at']}');
  if (instant != null) return instant.toUtc();
  final date = DateTime.tryParse('${meetup['date']}');
  if (date == null) return null;
  final parts = '${meetup['time'] ?? '19:30'}'.split(':');
  final wall = DateTime.utc(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts.first) ?? 19,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30);
  // Compatibility for older snapshots. New snapshots send absolute instants.
  // Europe/Amsterdam switches on the last Sundays of March and October.
  DateTime sunday(int month) {
    final last = DateTime.utc(date.year, month + 1, 0);
    return last.subtract(Duration(days: last.weekday % 7));
  }

  final summer = !wall.isBefore(sunday(3).add(const Duration(hours: 3))) &&
      wall.isBefore(sunday(10).add(const Duration(hours: 3)));
  return wall.subtract(Duration(hours: summer ? 2 : 1));
}

/// Amsterdam clock time for an instant: summer time runs from 01:00 UTC on
/// the last Sunday of March to 01:00 UTC on the last Sunday of October.
DateTime circleAmsterdam(DateTime instant) {
  final utc = instant.toUtc();
  DateTime lastSunday(int month) {
    final last = DateTime.utc(utc.year, month + 1, 0);
    return last.subtract(Duration(days: last.weekday % 7));
  }

  final summer = !utc.isBefore(lastSunday(3).add(const Duration(hours: 1))) &&
      utc.isBefore(lastSunday(10).add(const Duration(hours: 1)));
  return utc.add(Duration(hours: summer ? 2 : 1));
}

/// Where a part of the day ends: morning meetups at 12:00, afternoon ones
/// at 16:00, evening ones at 22:00 (as the server plans them).
String circleWindowEnd(int startHour) =>
    startHour < 12 ? '12:00' : (startHour < 17 ? '16:00' : '22:00');

/// "19:00–22:00": when a meetup starts and ends, in Netherlands time.
String circleMeetupHours(Json meetup) {
  final start = '${meetup['time'] ?? '19:30'}';
  final ends = DateTime.tryParse('${meetup['ends_at'] ?? ''}');
  if (ends == null) {
    return '$start–${circleWindowEnd(int.tryParse(start.split(':').first) ?? 19)}';
  }
  final end = circleAmsterdam(ends);
  return '$start–${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
}

/// Week 5's possible starts (the server checks the same): evenings
/// 18:00–21:00, afternoons 12:00–16:00, mornings 09:00–11:30.
(String, String) circleWeek5Window(Json meetup) {
  final hour = circleMeetupHour(meetup);
  return hour >= 17
      ? ('18:00', '21:00')
      : hour >= 12
          ? ('12:00', '16:00')
          : ('09:00', '11:30');
}

/// Week 5 before the group has planned it: the day is set, the rest isn't.
bool circleWeekOpen(Json meetup) =>
    meetup['week'] == 5 &&
    '${meetup['venue'] ?? ''}'.trim().isEmpty &&
    !circleMeetupPast(meetup);

/// "Thu 5 Nov · 20:00–22:00"; for week 5 still to plan, "Thu 5 Nov · start
/// time to choose", since the group picks it.
String circleMeetupWhen(Json meetup) =>
    '${circleDate(meetup['date'] as String?)} · ${circleWeekOpen(meetup) ? t('start time to choose') : circleMeetupHours(meetup)}';

DateTime? circleMeetupEnd(Json meetup) =>
    DateTime.tryParse('${meetup['ends_at']}')?.toUtc() ??
    circleMeetupStart(meetup)?.add(const Duration(hours: 2));

/// "€39" from a payment's amount in cents (older Circles cost €19).
String circleEuros(Object? cents) {
  final value = cents is num ? cents : num.tryParse('${cents ?? ''}');
  return '€${((value ?? 3900) / 100).toStringAsFixed(0)}';
}

/// Plain words for Circle and payment states, so nobody reads
/// "awaiting_payment" on screen.
String circleStatusLabel(Object? status) => switch ('$status') {
      'offered' => 'Invitations sent',
      'active' => 'Active',
      'completed' => 'Finished',
      'cancelled' => 'Cancelled',
      'forming' => 'Forming',
      'awaiting_payment' => 'Awaiting payment',
      'paid' => 'Paid · place confirmed',
      'requested' => 'Refund requested',
      'refunded' => 'Refund completed',
      _ => '$status',
    };

/// One line for a payment in Profile: a refund, once there is one, says
/// more about where things stand than the original payment does.
String circlePaymentLabel(Json payment) =>
    circleStatusLabel(payment['refund'] ?? payment['status']);

bool circleMeetupPast(Json meetup, {DateTime? now}) =>
    meetup['completed'] == true ||
    (circleMeetupEnd(meetup)?.isBefore((now ?? DateTime.now()).toUtc()) ??
        false);
int circleMeetupCompare(Json a, Json b) =>
    (circleMeetupStart(a) ?? DateTime.utc(9999))
        .compareTo(circleMeetupStart(b) ?? DateTime.utc(9999));

/// The place of a meetup, shown from the invitation on.
String circleVenueLabel(Json meetup, {DateTime? now}) {
  final venue = (meetup['venue'] as String?)?.trim();
  if (meetup['venue_hidden'] == true) return 'Shared soon · Alkmaar';
  // Week 5 is the group's own until they plan it.
  if ((venue == null || venue.isEmpty) && meetup['week'] == 5) {
    return 'Your group picks the place';
  }
  if (venue == null || venue.isEmpty) return 'Location to be confirmed';
  return venue;
}

/// What we can honestly tell someone who is waiting for a Circle.
///
/// A Circle needs five people who share a language and one weekly slot, so
/// progress towards that five is the one number that genuinely means
/// something. Everything else here is a range, never a date: the final step is
/// an organiser forming the group, and promising a day we do not control is
/// worse than saying "about two weeks".
class CircleWaitEstimate {
  const CircleWaitEstimate({this.slot, this.peers = 0, this.daysWaiting});

  /// The applicant's most promising slot, e.g. 'Thursday evening'. Null when
  /// the server has not sent one, which keeps an older backend honest instead
  /// of inventing a number.
  final String? slot;

  /// Other people waiting who share that slot and at least one language.
  final int peers;
  final int? daysWaiting;

  /// The smallest group `admin_create` will accept.
  static const groupSize = 5;

  bool get isKnown => slot != null;
  int get ready => (peers + 1).clamp(1, groupSize);
  int get stillNeeded => groupSize - ready;
  double get progress => ready / groupSize;

  bool get complete => isKnown && stillNeeded <= 0;

  String get headline => switch (stillNeeded) {
        <= 0 => 'We’re setting up your first meetup',
        1 => 'Just one more person needed',
        _ => '$stillNeeded more people needed',
      };

  /// Deliberately vague at the far end. Early on, a Circle depends on people
  /// who have not applied yet. Once the group is complete, the earliest
  /// possible first meetup is shown instead: the same date the organiser
  /// panel suggests, and clearly not a promise.
  String get estimate {
    if (stillNeeded <= 0) {
      final start = earliestStart();
      return start == null
          ? 'Usually a few days from here'
          : 'Earliest start: ${circleDate(start.toIso8601String())}. We’ll confirm it in your invitation.';
    }
    // No time range until the pilot shows how long it really takes.
    return 'We’ll email you as soon as your invitation is ready.';
  }

  /// 'Thursday evening' reads as a single appointment; the queue is about the
  /// recurring slot, so it is pluralised with the day left capitalised.
  String get slotPhrase => slot == null ? '' : '${slot}s';

  String get progressLine {
    if (!isKnown) {
      return 'We’re looking for people who share your language and a time that fits.';
    }
    if (stillNeeded <= 0) {
      return 'Enough people are free on $slotPhrase. Your invitation will appear here once the group is set.';
    }
    if (ready <= 1) return 'We’re gathering people for $slotPhrase.';
    return 'We’re finding people for $slotPhrase.';
  }

  /// The first possible meetup for the slot: the matching weekday at least
  /// twelve days out (five days to say yes, then a week to book), at the
  /// start time the organiser panel uses.
  DateTime? earliestStart({DateTime? now}) {
    final parts = (slot ?? '').split(' ');
    if (parts.length != 2) return null;
    final weekday = circleDays.indexOf(parts[0]) + 1;
    const starts = {
      'morning': (10, 30),
      'afternoon': (14, 0),
      'evening': (19, 0)
    };
    final time = starts[parts[1]];
    if (weekday == 0 || time == null) return null;
    var date = (now ?? DateTime.now()).add(const Duration(days: 12));
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day, time.$1, time.$2);
  }
}

/// Reads the estimate out of a snapshot, tolerating a server that has not
/// learned to send `nearest_slot` yet.
CircleWaitEstimate circleWaitEstimate(Json state, {DateTime? now}) {
  final nearest = state['nearest_slot'];
  final slot = nearest is Map ? '${nearest['slot'] ?? ''}'.trim() : '';
  final peers = nearest is Map ? (nearest['peers'] as num?)?.toInt() ?? 0 : 0;
  final submitted = DateTime.tryParse('${state['application_submitted_at']}');
  return CircleWaitEstimate(
    slot: slot.isEmpty ? null : slot,
    peers: peers < 0 ? 0 : peers,
    daysWaiting: submitted == null
        ? null
        : (now ?? DateTime.now()).difference(submitted).inDays.clamp(0, 3650),
  );
}

abstract class CircleRepository {
  bool get isDemo;

  /// What every screen needs, as fast as possible: one request.
  Future<Json> load();

  /// Photos and settings for [data], fetched after the screen is showing.
  /// Null when there is nothing to add.
  Future<Json?> loadExtras(Json data);
  Future<void> act(String action, [Json data = const {}]);
  Future<Json> adminLoad();

  /// The last 200 messages of a Circle's chat, for moderation.
  Future<List<Json>> adminMessages(String circleId) async => const [];

  /// The 200 messages before [before], oldest first.
  Future<List<Json>> adminMessagesBefore(String circleId, Json before) async =>
      const [];
}

class SupabaseCircleRepository implements CircleRepository {
  SupabaseCircleRepository(this.client);
  final SupabaseClient client;
  @override
  bool get isDemo => false;

  /// Email settings and "don't match again" choices only change through this
  /// member's own actions, so the 25-second refresh reuses them for a while.
  Json? _extras;
  DateTime? _extrasAt;

  @override
  Future<Json> load() async {
    // Home, messages and profile all come from this one request; the screen
    // shows as soon as it arrives. Photos and settings already known are
    // filled in straight away, the rest by [loadExtras] in the background.
    final data =
        Map<String, dynamic>.from(await client.rpc('circle_snapshot') as Map);
    if (_extras != null) data.addAll(_extras!);
    final app = Map<String, dynamic>.from(data['application'] as Map? ?? {});
    final members = rows(data['members']);
    for (final r in [app, ...members]) {
      r['photo_url'] =
          ProfilePhotoService.cachedSignedPhotoUrl(r['photo_path'] as String?);
    }
    data['application'] = app;
    data['members'] = members;
    return data;
  }

  @override
  Future<Json?> loadExtras(Json data) async {
    final fresh = _extras != null &&
        _extrasAt != null &&
        DateTime.now().difference(_extrasAt!) < const Duration(minutes: 5);
    final app = Map<String, dynamic>.from(data['application'] as Map? ?? {});
    final members = rows(data['members']);
    final needPhotos = [app, ...members].any(
        (r) => r['photo_url'] == null && '${r['photo_path'] ?? ''}'.isNotEmpty);
    if (fresh && !needPhotos) return null;
    final extras = <String, dynamic>{};
    await Future.wait<void>([
      if (!fresh) _emailSetting(extras),
      if (!fresh) _exclusions(extras),
      // All photo links in one request.
      if (needPhotos) _photos([app, ...members]),
    ]);
    if (!fresh) {
      // A failed read is passed on this time but not remembered.
      _extras = extras;
      _extrasAt = extras.values.contains(null) ? null : DateTime.now();
    }
    return Map<String, dynamic>.from(data)
      ..addAll(_extras ?? const {})
      ..['application'] = app
      ..['members'] = members;
  }

  Future<void> _photos(List<Json> records) async {
    try {
      final urls = await ProfilePhotoService.createSignedPhotoUrls(
          supabase: client,
          paths: records.map((r) => r['photo_path'] as String?));
      for (final r in records) {
        r['photo_url'] = urls[r['photo_path']];
      }
    } catch (_) {
      // One by one as a fallback; a missing photo never blocks the screen.
      await Future.wait(records.map(_photo));
    }
  }

  /// Email is on unless the member has turned it off, so a missing row and a
  /// failed read both mean "on" — the setting screen never claims email is
  /// disabled when it cannot tell.
  Future<void> _emailSetting(Json data) async {
    try {
      final row = await client
          .from('notification_settings')
          .select('email_enabled,email_reminders,email_chat,email_organiser')
          .maybeSingle();
      data['email_notifications'] = row?['email_enabled'] as bool? ?? true;
      data['email_settings'] = {
        for (final key in circleEmailSettings.keys)
          key: row?[key] as bool? ?? true
      };
    } catch (_) {
      data['email_notifications'] = null;
      data['email_settings'] = null;
    }
  }

  Future<void> _exclusions(Json data) async {
    try {
      final rows =
          await client.from('circle_exclusions').select('excluded_profile_id');
      data['exclusions'] = (rows as List)
          .map((r) => r['excluded_profile_id'].toString())
          .toList();
    } catch (_) {
      data['exclusions'] = null;
    }
  }

  Future<void> _photo(Json record) async {
    try {
      record['photo_url'] = await ProfilePhotoService.createSignedPhotoUrl(
          supabase: client, path: record['photo_path'] as String?);
    } catch (_) {
      record['photo_url'] = null;
    }
  }

  @override
  Future<void> act(String action, [Json data = const {}]) async {
    // Three flows deliberately live outside circle_action. Leaving a started
    // programme is not a payment decision; an exclusion is nobody else's
    // business and is read back under the member's own row-level security;
    // and an email preference is a plain table write. Dispatching here keeps
    // all of that out of the widgets.
    if (const {'exclude', 'email_notifications', 'email_setting'}
        .contains(action)) {
      _extras = null;
    }
    switch (action) {
      case 'leave_circle':
        await client.rpc('circle_leave', params: {'reason': data['reason']});
        return;
      case 'exclude':
        await client.rpc('circle_exclude', params: {
          'target': data['target'],
          'active': data['active'] ?? true
        });
        return;
      case 'payment_opened':
        await client.rpc('circle_payment_opened');
        return;
      case 'admin_remove_member':
        await client.rpc('circle_admin_remove_member', params: {
          'target_circle': data['circle_id'],
          'member': data['profile_id'],
          'reason': data['reason']
        });
        return;
      case 'admin_release_place':
        await client.rpc('circle_admin_release_place', params: {
          'target_circle': data['circle_id'],
          'member': data['profile_id']
        });
        return;
      case 'admin_invite':
        await client.rpc('circle_admin_invite', params: {
          'target_circle': data['circle_id'],
          'member': data['profile_id']
        });
        return;
      case 'admin_payment_link':
        await client.rpc('circle_set_payment_link',
            params: {'target': data['id'], 'link': data['link']});
        return;
      case 'email_notifications':
      case 'email_setting':
        final uid = client.auth.currentUser?.id;
        if (uid == null) throw StateError('Sign in first.');
        final key =
            action == 'email_setting' ? '${data['key']}' : 'email_enabled';
        if (!circleEmailSettings.containsKey(key)) {
          throw StateError('Unknown setting.');
        }
        await client.from('notification_settings').upsert({
          'profile_id': uid,
          key: data['enabled'] == true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        return;
      default:
        await client
            .rpc('circle_action', params: {'action': action, 'payload': data});
    }
  }

  Future<List<Json>> olderMessages(Json before) async =>
      rows(await client.rpc('circle_messages_before', params: {
        'before_time': before['created_at'],
        'before_id': before['id'],
      }).timeout(const Duration(seconds: 15)));

  @override
  Future<List<Json>> adminMessages(String circleId) async => rows(await client
      .rpc('circle_admin_messages', params: {'target_circle': circleId}));

  @override
  Future<List<Json>> adminMessagesBefore(String circleId, Json before) async =>
      rows(await client.rpc('circle_admin_messages_before', params: {
        'target_circle': circleId,
        'before_time': before['created_at'],
        'before_id': before['id'],
      }).timeout(const Duration(seconds: 15)));

  @override
  Future<Json> adminLoad() async {
    final data = Map<String, dynamic>.from(
        await client.rpc('circle_admin_snapshot') as Map);
    // 'ready' comes from the database: birthday, photo and times. The
    // WhatsApp number is optional and does not affect it.
    final applications = rows(data['applications']);
    await _photos(applications);
    data['applications'] = applications;
    return data;
  }
}

/// A completely local sandbox. Never reads or writes Supabase or processes money.
/// The email categories a member can switch off separately, with what each
/// one covers. 'email_organiser' is only shown to organisers.
const circleEmailSettings = {
  'email_enabled': (
    'Circle updates',
    'Invitations, payments, changes to your Circle'
  ),
  'email_reminders': (
    'Reminders',
    'The day before a meetup, check-ins and payment reminders'
  ),
  'email_chat': ('Chat summary', 'Once a day when your Circle wrote'),
  'email_organiser': (
    'Organiser alerts',
    'Payments to confirm, reports, refunds and changes'
  ),
};

class DemoCircleRepository implements CircleRepository {
  DemoCircleRepository(this.preferences);
  final SharedPreferences preferences;
  static const storageKey = 'vriendtime.circle-preview.v1';
  @override
  Future<Json?> loadExtras(Json data) async => null;

  @override
  bool get isDemo => true;
  Json get _state {
    try {
      final raw = preferences.getString(storageKey);
      if (raw != null) return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {/* A corrupt preview can safely start again. */}
    return {
      'stage': 'apply',
      'application': <String, dynamic>{},
      'is_admin': true,
      'messages': <Json>[],
      'check_ins': <Json>[],
      'notifications': <Json>[]
    };
  }

  Future<void> _save(Json state) async {
    if (!await preferences.setString(storageKey, jsonEncode(state))) {
      throw StateError('Your preview could not be saved. Please try again.');
    }
  }

  @override
  Future<Json> load() async {
    final state = _state;
    // There is no queue behind the preview, so it stands in a plausible one.
    // Without it the waiting screen would demonstrate only its empty state,
    // which is the half nobody is trying to see. Presentation only: this is
    // never written back to storage.
    if (state['stage'] == 'waiting') {
      final app = Map<String, dynamic>.from(state['application'] as Map? ?? {});
      state['nearest_slot'] ??= {
        'slot': strings(app['availability']).firstOrNull ?? 'Thursday evening',
        'peers': 2
      };
      state['application_submitted_at'] ??=
          DateTime.now().subtract(const Duration(days: 6)).toIso8601String();
    }
    state['email_notifications'] ??= true;
    state['email_settings'] = {
      for (final key in circleEmailSettings.keys) key: true,
      ...Map<String, dynamic>.from(state['email_settings'] as Map? ?? {}),
    };
    state['exclusions'] ??= const <String>[];
    // Pay first, as on the server: until the group is booked, seats instead
    // of people, and the weeks without dates or places. Shown only; the
    // stored preview keeps everything for the next stage.
    if (state['pay_first'] is Map &&
        (state['pay_first'] as Map)['started'] != true) {
      return {
        ...state,
        'members': const <Json>[],
        'messages': const <Json>[],
        'circle': Map<String, dynamic>.from(state['circle'] as Map? ?? {})
          ..remove('start_date'),
        'meetups': [
          for (final m in rows(state['meetups']))
            if (m['week'] is int)
              {
                'id': m['id'],
                'week': m['week'],
                'title': m['title'],
                'included': m['included'],
                'cost_notes': m['cost_notes'],
              }
        ],
      };
    }
    // One free move, between the first and the second meetup, as on the
    // server.
    if (state['stage'] == 'active') {
      bool done(int week) => rows(state['meetups'])
          .any((m) => m['week'] == week && m['completed'] == true);
      state['move'] = {
        'used': state['move_used'] == true,
        'available': state['move_used'] != true && done(1) && !done(2),
      };
      state['switch'] = {'available': state['move_used'] != true && !done(2)};
    }
    return state;
  }

  Json _seed(Json state) {
    final app = Map<String, dynamic>.from(state['application'] as Map? ?? {});
    final name = (app['name'] as String?)?.trim();
    state['circle'] = {
      'id': 'demo-circle',
      'name': 'The Thursday Circle',
      'city': 'Alkmaar',
      'schedule': 'Thursday evenings · English',
      'start_date': '2026-10-08',
      'status': 'active'
    };
    state['members'] = [
      {
        'id': 'you',
        'name': name == null || name.isEmpty ? 'You' : name,
        'bio': 'Ready for a few familiar faces.',
        'interests': app['interests'] ?? ['Coffee', 'Walking']
      },
      {
        'id': 'noor',
        'name': 'Noor',
        'bio': 'New to Alkmaar. Always up for a walk and good coffee.',
        'interests': ['Walking', 'Coffee']
      },
      {
        'id': 'sam',
        'name': 'Sam',
        'bio': 'Remote worker, amateur cook, enthusiastic board gamer.',
        'interests': ['Cooking', 'Games']
      },
      {
        'id': 'lena',
        'name': 'Lena',
        'bio': 'Finding my favourite places and people in the city.',
        'interests': ['Art', 'Food']
      },
      {
        'id': 'daan',
        'name': 'Daan',
        'bio': 'Weekend cyclist. Looking for more plans close to home.',
        'interests': ['Cycling', 'Music']
      },
      {
        'id': 'alex',
        'name': 'Alex',
        'bio': 'A good conversation beats another evening scrolling.',
        'interests': ['Books', 'Coffee']
      },
    ];
    final coffee = DateTime.now().add(const Duration(days: 3));
    state['coffees'] = {
      'started': true,
      'round': 1,
      'current': {
        'id': 'demo-coffee',
        'round': 1,
        'starts_at': DateTime(coffee.year, coffee.month, coffee.day, 14)
            .toUtc()
            .toIso8601String(),
        'place': 'De Koffiemolen',
        'address': 'Ritsevoort 26',
        'status': 'asked',
        'swap': false,
        'mine': null,
        'theirs': 'yes',
        'other': {'id': 'noor', 'name': 'Noor'}
      },
      'met': ['sam'],
      'free_week': false
    };
    // Week 1 was six days ago; the rest are still to come, whatever today is.
    final firstWeek = DateTime.now().subtract(const Duration(days: 6));
    state['meetups'] = List.generate(
        6,
        (i) => {
              'id': 'week-${i + 1}',
              'week': i + 1,
              'title': circleActivities[i],
              'date': DateTime(
                      firstWeek.year, firstWeek.month, firstWeek.day + i * 7)
                  .toIso8601String(),
              'time': _demoEvening[i].time,
              'venue': _demoEvening[i].venue,
              'venue_address': _demoEvening[i].address,
              'cost_notes': _demoEvening[i].cost,
              'included': circleIncludedWeeks.contains(i + 1),
              if (i == 1) ...{
                'booking_status': 'requested',
                'booking_requested_at': firstWeek.toUtc().toIso8601String(),
                'booking_email': {
                  'created_at': firstWeek.toUtc().toIso8601String(),
                  'sent_at': firstWeek.toUtc().toIso8601String(),
                  'failed': false
                }
              },
              if (i == 2) 'booking_status': 'booked',
              'completed': false,
              'rsvp': false,
              'confirmed': i == 0 ? 4 : 3,
              'organiser': i == 4 ? 'Your Circle' : 'VriendTime',
              'attendees': rows(state['members'])
                  .map((p) => {
                        'profile_id': p['id'],
                        'name': p['name'],
                        'attended': null
                      })
                  .toList()
            });
    // A small conversation over two days, so the preview shows how the
    // chat reads: days, others in white, you in navy.
    String ago(int hours) => DateTime.now()
        .subtract(Duration(hours: hours))
        .toUtc()
        .toIso8601String();
    state['messages'] = [
      {
        'name': 'Noor',
        'body': 'Hi everyone! Really looking forward to meeting you all. ☕',
        'own': false,
        'created_at': ago(30)
      },
      {
        'name': 'Sam',
        'body':
            'Same here! Nice to have something in the calendar with the same people.',
        'own': false,
        'created_at': ago(29)
      },
      {
        'name': 'You',
        'body': 'Me too! See you all on Friday.',
        'own': true,
        'created_at': ago(2)
      },
      {
        'id': 'demo-week5',
        'created_at': ago(1),
        'name': 'VriendTime',
        'body':
            'Week 5 is your call! Share ideas here, then tap “Plan it” on the week 5 card to set the place and the time.',
        'own': false,
        'system': true
      },
    ];
    state['check_ins'] = <Json>[];
    state['notifications'] = [
      {
        'id': 'demo-ready',
        'kind': 'update',
        'created_at': DateTime.now()
            .subtract(const Duration(hours: 2))
            .toUtc()
            .toIso8601String(),
        'read_at': null,
        'title': 'Your Circle is ready',
        'body':
            'Your group and six Thursdays are ready. Have a look, and say yes if it works for you.'
      }
    ];
    return state;
  }

  @override
  Future<void> act(String action, [Json data = const {}]) async {
    var state = _state;
    switch (action) {
      case 'reset':
        await preferences.remove(storageKey);
        return;
      case 'draft':
        // Editing one answer must not drop a waiting applicant off the list.
        // Only an application that was never submitted goes back to 'apply'.
        if (state['stage'] != 'waiting') state['stage'] = 'apply';
        state['application'] = data;
        break;
      case 'apply':
        state['application'] = data;
        state['stage'] = 'waiting';
        break;
      case 'withdraw':
        state['stage'] = 'apply';
        break;
      case 'preview':
        final stage = data['stage'];
        if (['invited', 'confirmed', 'active', 'completed'].contains(stage)) {
          state = _seed(state);
        }
        state['stage'] = stage;
        // Pay first: an invitation or a paid place before the group is
        // booked shows seats, not people.
        // {'pay_first': false} shows the older flow (meet, then pay), which
        // Circles made before 16 October still use.
        if ((stage == 'invited' || stage == 'confirmed') &&
            data['pay_first'] != false) {
          state['pay_first'] = {
            'started': false,
            'seats': 6,
            'found': 6,
            'confirmed': stage == 'confirmed' ? 4 : 3,
            'expired': false,
          };
        } else {
          state.remove('pay_first');
        }
        // After week 2 the WhatsApp question; the preview shows it in the
        // six-week stage.
        if (stage == 'active') {
          state['whatsapp'] = {'answer': null, 'has_phone': false};
        } else {
          state.remove('whatsapp');
        }
        state.remove('refund');
        state.remove('outcome');
        state.remove('move_credit');
        state.remove('move_used');
        state['payment'] = ['confirmed', 'active', 'completed'].contains(stage)
            ? 'demo_paid'
            : 'unpaid';
        if (stage == 'invited' || stage == 'confirmed') {
          // An invitation is for six weeks still to come: the first
          // Thursday at least twelve days out, answers due in five.
          var firstWeek = DateTime.now().add(const Duration(days: 12));
          while (firstWeek.weekday != DateTime.thursday) {
            firstWeek = firstWeek.add(const Duration(days: 1));
          }
          String day(DateTime d) =>
              DateTime(d.year, d.month, d.day).toIso8601String();
          state['meetups'] = rows(state['meetups'])
              .map((m) => {
                    ...m,
                    'completed': false,
                    if (m['week'] is int)
                      'date': day(firstWeek
                          .add(Duration(days: ((m['week'] as int) - 1) * 7))),
                  })
              .toList();
          state['circle'] = {
            ...state['circle'] as Map,
            'start_date': day(firstWeek)
          };
          state['pay_by'] =
              day(DateTime.now().add(const Duration(days: 7))).substring(0, 10);
          state['accept_until'] =
              day(firstWeek.subtract(const Duration(days: 7))).substring(0, 10);
        } else {
          state.remove('pay_by');
          state.remove('accept_until');
        }
        if (stage == 'completed') {
          // After the last week no one-to-ones are suggested any more.
          if (state['coffees'] is Map) {
            state['coffees'] = {
              ...Map<String, dynamic>.from(state['coffees'] as Map),
              'current': null,
            };
          }
          // All six weeks are behind them.
          final firstWeek = DateTime.now().subtract(const Duration(days: 44));
          state['meetups'] = rows(state['meetups'])
              .map((m) => {
                    ...m,
                    'completed': true,
                    if (m['week'] is int)
                      'date': DateTime(firstWeek.year, firstWeek.month,
                              firstWeek.day + ((m['week'] as int) - 1) * 7)
                          .toIso8601String(),
                  })
              .toList();
        }
        break;
      case 'whatsapp':
        if (state['whatsapp'] is! Map) {
          throw StateError('This question comes after your second meetup.');
        }
        state['whatsapp'] = {
          'answer': data['answer'],
          'has_phone': data['phone'] != null ||
              (state['whatsapp'] as Map)['has_phone'] == true,
        };
        break;
      case 'refresh_commitment':
        state['application_updated_at'] = DateTime.now().toIso8601String();
        break;
      case 'leave_circle':
        if (state['stage'] != 'active') {
          throw StateError('You are not in a Circle.');
        }
        state['stage'] = 'apply';
        state.remove('circle');
        state.remove('members');
        state.remove('meetups');
        state['payment'] = 'unpaid';
        break;
      case 'exclude':
        final excluded = strings(state['exclusions']).toSet();
        if (data['active'] == false) {
          excluded.remove('${data['target']}');
        } else {
          excluded.add('${data['target']}');
        }
        state['exclusions'] = excluded.toList();
        break;
      case 'admin_release_place':
      case 'admin_invite':
        throw StateError('Not available in the preview.');
      case 'admin_payment_link':
        if (state['circle'] is Map) {
          final link = '${data['link'] ?? ''}'.trim();
          state['circle'] = {
            ...state['circle'] as Map,
            'payment_link': link.isEmpty ? null : link
          };
        }
        break;
      case 'payment_opened':
        break;
      case 'email_setting':
        state['email_settings'] = {
          ...Map<String, dynamic>.from(state['email_settings'] as Map? ?? {}),
          '${data['key']}': data['enabled'] == true
        };
        break;
      case 'email_notifications':
        state['email_notifications'] = data['enabled'] == true;
        break;
      case 'join':
        if (state['stage'] != 'invited') {
          throw StateError('Open your invitation first.');
        }
        final payFirst = state['pay_first'] is Map
            ? Map<String, dynamic>.from(state['pay_first'] as Map)
            : null;
        if (payFirst != null && payFirst['started'] != true) {
          // Paid, and waiting for the group to be booked.
          payFirst['confirmed'] =
              (((payFirst['confirmed'] as num?)?.toInt() ?? 0) + 1).clamp(0, 6);
          state['pay_first'] = payFirst;
          state['stage'] = 'confirmed';
        } else {
          state['stage'] = 'active';
        }
        state['payment'] = 'demo_paid';
        if (state['move_credit'] == true) {
          state['move_credit'] = false;
          state['move_used'] = true;
        }
        break;
      case 'request_move':
        bool done(int week) => rows(state['meetups'])
            .any((m) => m['week'] == week && m['completed'] == true);
        if (state['stage'] != 'active' ||
            state['move_used'] == true ||
            !done(1) ||
            done(2)) {
          throw StateError(
              'A move is possible between your first and second meetup.');
        }
        state['stage'] = 'waiting';
        state['move_credit'] = true;
        state.remove('circle');
        state.remove('members');
        state.remove('meetups');
        state.remove('move');
        break;
      case 'rsvp':
        state['meetups'] = rows(state['meetups'])
            .map((m) => m['id'] == data['id']
                ? {
                    ...m,
                    'rsvp': data['going'],
                    'confirmed': (m['confirmed'] as int) +
                        (data['going'] == true ? 1 : -1) *
                            (m['rsvp'] == data['going'] ? 0 : 1)
                  }
                : m)
            .toList();
        break;
      case 'message':
        final body = (data['body'] as String).trim();
        if (body.isEmpty || body.length > 2000) {
          throw StateError('Write a message of 1–2000 characters.');
        }
        state['messages'] = [
          ...rows(state['messages']),
          {
            'name': 'You',
            'body': body,
            'own': true,
            'created_at': DateTime.now().toUtc().toIso8601String()
          }
        ];
        break;
      case 'complete_meetup':
        state['meetups'] = rows(state['meetups'])
            .map((m) => m['id'] == data['id'] ? {...m, 'completed': true} : m)
            .toList();
        if (rows(state['meetups'])
            .where((m) => m['week'] != null)
            .every((m) => m['completed'] == true)) {
          state['stage'] = 'completed';
          state['circle'] = {...state['circle'] as Map, 'status': 'completed'};
        }
        break;
      case 'check_in':
        state['check_ins'] = [
          ...rows(state['check_ins']).where((c) => c['id'] != data['id']),
          data
        ];
        break;
      case 'outcome':
        state['outcome'] = data;
        break;
      case 'refund':
        state['refund'] = 'requested';
        break;
      case 'resolve_refund':
        state['refund'] = 'refunded';
        state['payment'] = 'demo_refunded';
        break;
      case 'admin_attendance':
        state['meetups'] = rows(state['meetups'])
            .map((m) => m['id'] == data['id']
                ? {
                    ...m,
                    'attendees': rows(m['attendees'])
                        .map((p) => p['profile_id'] == data['profile_id']
                            ? {...p, 'attended': data['attended']}
                            : p)
                        .toList()
                  }
                : m)
            .toList();
        break;
      case 'payment_sent':
        state['payment_agreement'] = {
          ...?state['payment_agreement'] as Json?,
          'payment_reported_at': DateTime.now().toIso8601String()
        };
        break;
      case 'cancel_extra':
        state['meetups'] =
            rows(state['meetups']).where((m) => m['id'] != data['id']).toList();
        break;
      case 'admin_schedule':
      case 'schedule':
        final existing = rows(state['meetups']);
        if (data['id'] != null) {
          state['meetups'] = existing
              .map((m) => m['id'] == data['id']
                  ? {
                      ...m,
                      ...data,
                      'plan_version': (m['plan_version'] as int? ?? 0) + 1,
                      if (action == 'schedule' && m['week'] != null) ...{
                        'date': m['date'],
                        'time': m['week'] == 5
                            ? data['time'] ?? m['time']
                            : m['time'],
                      },
                    }
                  : m)
              .toList();
        } else {
          state['meetups'] = [
            ...existing,
            {
              ...data,
              'id': 'extra-${DateTime.now().microsecondsSinceEpoch}',
              'week': null,
              'completed': false,
              'rsvp': true,
              'confirmed': 1,
              'created_by': state['profile_id'] ?? 'you',
              'plan_version': 1,
              'organiser': 'Your Circle'
            }
          ];
        }
        break;
      case 'admin_create':
        state = _seed(state);
        final selected = strings(data['members']);
        if (selected.isNotEmpty) {
          final original = rows(state['members']);
          state['members'] = [
            for (var i = 0; i < original.length; i++)
              if (selected.contains(i == 0 ? 'you' : 'person-$i')) original[i]
          ];
        }
        state['circle'] = {
          ...state['circle'] as Map,
          'name': data['name'],
          'schedule': data['schedule'],
          'start_date': data['start_date']
        };
        state['meetups'] = rows(state['meetups'])
            .map((m) => {
                  ...m,
                  'date': (() {
                    final d = DateTime.parse(data['start_date'] as String);
                    return DateTime(
                        d.year, d.month, d.day + ((m['week'] as int) - 1) * 7);
                  })()
                      .toIso8601String(),
                  'time': data['time'] ?? '19:30',
                  if (data['weeks'] case final List weeks
                      when weeks.length >= (m['week'] as int)) ...{
                    'title': weeks[(m['week'] as int) - 1]['title'],
                    'venue': weeks[(m['week'] as int) - 1]['venue'],
                  },
                })
            .toList();
        state['stage'] = 'invited';
        break;
      case 'switch_group':
        if (state['stage'] != 'active' || state['move_used'] == true) {
          throw StateError('A switch is possible until your second meetup.');
        }
        state['stage'] = 'waiting';
        state['move_credit'] = true;
        state.remove('circle');
        state.remove('members');
        state.remove('meetups');
        state.remove('move');
        state.remove('switch');
        break;
      case 'cancel_agreement':
        state['left_circle'] = {
          'name': (state['circle'] as Map?)?['name'] ?? 'your Circle',
          'refund': state['payment'] == 'paid' ? 'requested' : null
        };
        state['stage'] = 'apply';
        state.remove('circle');
        state.remove('members');
        state.remove('meetups');
        break;
      case 'rejoin':
        state.remove('left_circle');
        state['stage'] = 'waiting';
        break;
      case 'join_again':
        state['looking_again'] = true;
        break;
      case 'stop_looking':
        state['looking_again'] = false;
        break;
      case 'past_message':
        state['past_circles'] = [
          for (final c in rows(state['past_circles']))
            '${c['id']}' == '${data['circle_id']}'
                ? {
                    ...c,
                    'messages': [
                      ...rows(c['messages']),
                      {
                        'name': 'You',
                        'body': '${data['body']}'.trim(),
                        'own': true
                      }
                    ]
                  }
                : c
        ];
        break;
      case 'coffee_answer':
        final coffees = Map<String, dynamic>.from(state['coffees'] as Map);
        final c = Map<String, dynamic>.from(coffees['current'] as Map);
        if (c['status'] == 'confirmed' && data['answer'] == 'no') {
          coffees['current'] = null;
        } else {
          c['mine'] = data['answer'];
          if (c['mine'] == 'yes' && c['theirs'] == 'yes') {
            c['status'] = 'confirmed';
          }
          coffees['current'] = c;
        }
        state['coffees'] = coffees;
        break;
      case 'admin_booking':
        state['meetups'] = [
          for (final m in rows(state['meetups']))
            if (m['id'] == data['id'])
              {
                ...m,
                'booking_status': switch (data['step']) {
                  'email' => 'requested',
                  'booked' => 'booked',
                  _ => null
                },
                // The preview has no email worker: it goes out at once.
                if (data['step'] == 'email') ...{
                  'booking_requested_at':
                      DateTime.now().toUtc().toIso8601String(),
                  'booking_email': {
                    'created_at': DateTime.now().toUtc().toIso8601String(),
                    'sent_at': DateTime.now().toUtc().toIso8601String(),
                    'failed': false
                  },
                },
                if (data['step'] != 'email') 'booking_previous': null,
              }
            else
              m
        ];
        break;
      case 'admin_template':
      case 'admin_coffee_places':
      case 'coffee_feedback':
        break;
      default:
        throw StateError('This action is not available.');
    }
    await _save(state);
  }

  @override
  Future<List<Json>> adminMessages(String circleId) async =>
      rows(_state['messages']);

  @override
  Future<List<Json>> adminMessagesBefore(String circleId, Json before) async =>
      const [];

  @override
  Future<Json> adminLoad() async {
    final state = _state;
    return {
      'applications': _demoApplicants(),
      'circles': state['circle'] == null
          ? []
          : [
              {...state['circle'] as Map, 'meetups': state['meetups']}
            ],
      'refunds': state['refund'] == null
          ? []
          : [
              {'id': 'demo-refund', 'name': 'You', 'status': state['refund']}
            ],
      'programme': [
        for (final (kind, plan) in [
          ('evening', _demoEvening),
          ('afternoon', _demoAfternoon),
          ('morning', _demoMorning),
        ])
          for (var i = 0; i < plan.length; i++)
            {
              'city': 'Alkmaar',
              'kind': kind,
              'week': i + 1,
              'title': (kind == 'morning'
                  ? circleMorningWeekTitles
                  : circleWeekTitles)[i],
              'venue': plan[i].venue,
              'address': plan[i].address,
              'cost': plan[i].cost,
              'start_time': '${plan[i].time}:00',
              'included': circleIncludedWeeks.contains(i + 1),
            }
      ],
      'venues': [
        for (final (name, booking, url, email, phone) in [
          (
            '1480 Foodbar',
            'online',
            'https://www.1480foodbar.nl/',
            'bar@1480foodbar.nl',
            '072 241 0099'
          ),
          (
            'The Boules Club',
            'email',
            'https://theboulesclub.com/alkmaar/',
            'reserveringen.alkmaar@theboulesclub.com',
            '072 202 9779'
          ),
          (
            'Rozey Alkmaar',
            'online',
            'https://rozey.nl/rozey-alkmaar',
            'alkmaar@rozey.nl',
            '072 220 3961'
          ),
          (
            'The Hangout',
            'online',
            'https://booking.thehangout.nl/',
            'events@thehangout.nl',
            '072 202 9799'
          ),
          (
            'Hofman',
            'online',
            'https://www.hofman-alkmaar.nl/reserveren',
            'info@hofman-alkmaar.nl',
            '072 582 3612'
          ),
          (
            'De Spellentoren',
            'email',
            null,
            'info@despellentoren.nl',
            '072 220 3100'
          ),
        ])
          {
            'city': 'Alkmaar',
            'name': name,
            'booking': booking,
            'booking_url': url,
            'booking_email': email,
            'booking_phone': phone
          }
      ],
      'coffee_places': [
        {
          'kind': 'daytime',
          'name': 'De Koffiemolen',
          'address': 'Ritsevoort 26',
          'opening_hours': {
            for (final d in ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'])
              d: [
                {'open': '09:00', 'close': '17:00'}
              ]
          }
        },
        {'kind': 'daytime', 'name': 'Kaldi'},
        {'kind': 'evening', 'name': 'Mr. Gold'},
      ],
      'metrics': {
        'applications': 6,
        'paid': state['payment'] == 'demo_paid' ? 6 : 0,
        'completed': state['stage'] == 'completed' ? 1 : 0
      }
    };
  }
}

/// Example applicants for the preview organiser panel: varied enough that
/// the availability grid, filters and group suggestions have something to
/// show. Never sent anywhere.
List<Json> _demoApplicants() {
  final now = DateTime.now();
  Json person(String id, String name, int age, List<String> languages,
          List<String> availability, List<String> interests,
          {List<String> activities = const [],
          List<String> goals = const ['Local friends'],
          int energy = 2,
          String phone = '+31612345678',
          int waitedDays = 7,
          bool ready = true}) =>
      {
        'profile_id': id,
        'name': name,
        'city': 'Alkmaar',
        'age': age,
        'languages': languages,
        'availability': availability,
        'interests': interests,
        'activities': activities,
        'goals': goals,
        'energy': energy,
        'phone': phone,
        'intro': '',
        'status': 'waiting',
        'ready': ready,
        'submitted_at':
            now.subtract(Duration(days: waitedDays)).toIso8601String(),
      };
  const en = ['English'], both = ['English', 'Dutch'], nl = ['Dutch'];
  return [
    person('you', 'You', 31, both, ['Thursday evening', 'Saturday afternoon'],
        ['Coffee', 'Walking'],
        activities: ['A walk'], waitedDays: 40),
    person(
        'person-1', 'Noor', 29, both, ['Thursday evening'], ['Coffee', 'Books'],
        activities: ['A walk', 'Board games'], waitedDays: 38),
    person('person-2', 'Sam', 33, en, ['Thursday evening', 'Tuesday evening'],
        ['Walking', 'Cooking'],
        activities: ['A walk'], waitedDays: 35),
    person('person-3', 'Lena', 27, both, ['Thursday evening', 'Sunday morning'],
        ['Coffee', 'Walking', 'Art'],
        activities: ['A walk'], waitedDays: 30),
    person('person-4', 'Daan', 35, both, ['Thursday evening'],
        ['Cooking', 'Coffee'],
        goals: ['Regular plans'], waitedDays: 26),
    person('person-5', 'Alex', 30, en,
        ['Thursday evening', 'Saturday afternoon'], ['Books', 'Walking'],
        activities: ['Board games'], waitedDays: 21),
    person('person-6', 'Mila', 26, nl, ['Saturday afternoon', 'Sunday morning'],
        ['Sport', 'Music'],
        activities: ['Sport'], goals: ['Shared hobbies'], waitedDays: 20),
    person(
        'person-7', 'Joris', 28, nl, ['Saturday afternoon'], ['Sport', 'Games'],
        activities: ['Sport', 'Board games'],
        goals: ['Shared hobbies'],
        waitedDays: 18),
    person('person-8', 'Fleur', 31, both,
        ['Saturday afternoon', 'Wednesday evening'], ['Music', 'Art'],
        goals: ['Shared hobbies'], waitedDays: 16),
    person(
        'person-9', 'Bram', 27, nl, ['Saturday afternoon'], ['Sport', 'Music'],
        activities: ['Sport'], goals: ['Shared hobbies'], waitedDays: 12),
    person('person-10', 'Priya', 34, en,
        ['Tuesday evening', 'Thursday evening'], ['Cooking', 'Books'],
        activities: ['Dinner'], goals: ['Regular plans'], waitedDays: 10),
    person('person-11', 'Tom', 38, en, ['Tuesday evening'], ['Cooking', 'Film'],
        activities: ['Dinner'], goals: ['Regular plans'], waitedDays: 8),
    person('person-12', 'Sara', 36, en,
        ['Tuesday evening', 'Wednesday evening'], ['Film', 'Books'],
        activities: ['Dinner'], goals: ['Regular plans'], waitedDays: 6),
    person('person-13', 'Eva', 24, nl, ['Sunday morning'], ['Walking'],
        waitedDays: 5, ready: false, phone: ''),
    person('person-14', 'Mo', 41, en, ['Monday evening'], ['Games'],
        waitedDays: 3),
    person(
        'person-15', 'Kim', 29, both, ['Wednesday evening'], ['Art', 'Music'],
        waitedDays: 1, ready: false),
  ];
}
