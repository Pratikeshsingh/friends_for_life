import 'dart:convert';
import '../core/i18n.dart' show isDutch;
import '../core/profile_photo_service.dart';
import 'circle_preferences.dart' show circleDays;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef Json = Map<String, dynamic>;

/// The six weeks, told the same way everywhere: landing page, invitation,
/// the weekly plan and the organiser panel. The database creates meetups
/// with these same titles (see supabase/migrations/20260930_week_one_dinner.sql).
const circleWeekTitles = [
  'Dinner together',
  'Bowling together',
  'A walk & a warm drink',
  'Choose something together',
  'A plan of your own',
  'One last get-together',
];

/// Kept for older call sites: the meetup titles are the week titles.
const circleActivities = circleWeekTitles;

/// One short line per week, for the six-week timeline.
const circleWeekShort = [
  'A two-hour dinner to meet everyone.',
  'A shared activity takes the pressure off.',
  'A catch-up on foot, less small talk.',
  'You pick the next activity as a group.',
  'Someone in the Circle makes the plan.',
  'Your group stays together. Nothing more to pay.',
];

/// The fuller description, on each week's card.
const circleWeekNotes = [
  'A two-hour dinner. We book the table; you pay the restaurant for what you order. Leaving early is always fine, but the first evening is the one worth staying for.',
  'A shared activity takes the pressure off conversation.',
  'Catch up as a group, or add an optional coffee with one person.',
  'Pick your next activity together.',
  'Someone in the Circle takes the lead this week.',
  'Make the plan yourselves. Keep the good thing going.',
];

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
  final date = DateTime.tryParse('${meetup['date']}');
  if (date == null) return null;
  final parts = '${meetup['time'] ?? '19:30'}'.split(':');
  return DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts.first) ?? 19,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30);
}

/// The venue of a programme meetup is revealed 24 hours before it starts, so
/// people commit to the Circle rather than to the restaurant. The server
/// already withholds it (`venue_hidden`); this repeats the rule for the local
/// preview, and for a payload that predates that change.
String circleVenueLabel(Json meetup, {DateTime? now}) {
  const hidden = 'Revealed 24 hours before · Alkmaar';
  final venue = (meetup['venue'] as String?)?.trim();
  if (meetup['venue_hidden'] == true) return hidden;
  if (venue == null || venue.isEmpty) return 'Location to be confirmed';
  // A plan the Circle made itself was never a secret from them.
  if (meetup['week'] == null) return venue;
  final start = circleMeetupStart(meetup);
  if (start == null) return venue;
  return start.difference(now ?? DateTime.now()) > const Duration(hours: 24)
      ? hidden
      : venue;
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
          : 'Earliest start: ${circleDate(start.toIso8601String())} at ${_hm(start)}. We’ll confirm it in your invitation.';
    }
    return switch (stillNeeded) {
      1 => 'Usually about a week',
      2 => 'Usually one to two weeks',
      3 => 'Usually two to three weeks',
      _ => 'Usually a few weeks',
    };
  }

  /// 'Thursday evening' reads as a single appointment; the queue is about the
  /// recurring slot, so it is pluralised with the day left capitalised.
  String get slotPhrase => slot == null ? '' : '${slot}s';

  String get progressLine {
    if (!isKnown) {
      return 'We’re looking for people who share your language and a time that fits.';
    }
    if (stillNeeded <= 0) return 'We found your group for $slotPhrase.';
    if (ready <= 1) return 'We’re gathering people for $slotPhrase.';
    return 'Your group for $slotPhrase is coming together.';
  }

  /// The first possible meetup for the slot: the matching weekday at least
  /// a week out, at the start time the organiser panel uses.
  DateTime? earliestStart({DateTime? now}) {
    final parts = (slot ?? '').split(' ');
    if (parts.length != 2) return null;
    final weekday = circleDays.indexOf(parts[0]) + 1;
    const starts = {
      'morning': (9, 30),
      'afternoon': (13, 0),
      'evening': (19, 0)
    };
    final time = starts[parts[1]];
    if (weekday == 0 || time == null) return null;
    var date = (now ?? DateTime.now()).add(const Duration(days: 7));
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day, time.$1, time.$2);
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
  Future<Json> load();
  Future<void> act(String action, [Json data = const {}]);
  Future<Json> adminLoad();
}

class SupabaseCircleRepository implements CircleRepository {
  SupabaseCircleRepository(this.client);
  final SupabaseClient client;
  @override
  bool get isDemo => false;
  @override
  Future<Json> load() async {
    final data =
        Map<String, dynamic>.from(await client.rpc('circle_snapshot') as Map);
    final app = Map<String, dynamic>.from(data['application'] as Map? ?? {});
    await _photo(app);
    data['application'] = app;
    final members = rows(data['members']);
    await Future.wait(members.map(_photo));
    data['members'] = members;
    await Future.wait([_emailSetting(data), _exclusions(data)]);
    return data;
  }

  /// Email is on unless the member has turned it off, so a missing row and a
  /// failed read both mean "on" — the setting screen never claims email is
  /// disabled when it cannot tell.
  Future<void> _emailSetting(Json data) async {
    try {
      final row = await client
          .from('notification_settings')
          .select('email_enabled')
          .maybeSingle();
      data['email_notifications'] = row?['email_enabled'] as bool? ?? true;
    } catch (_) {
      data['email_notifications'] = true;
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
      data['exclusions'] = const <String>[];
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
      case 'email_notifications':
        final uid = client.auth.currentUser?.id;
        if (uid == null) throw StateError('Sign in first.');
        await client.from('notification_settings').upsert({
          'profile_id': uid,
          'email_enabled': data['enabled'] == true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        return;
      default:
        await client
            .rpc('circle_action', params: {'action': action, 'payload': data});
    }
  }

  @override
  Future<Json> adminLoad() async {
    final data = Map<String, dynamic>.from(
        await client.rpc('circle_admin_snapshot') as Map);
    final applications = rows(data['applications']);
    // A WhatsApp number is required before someone can be grouped.
    for (final a in applications) {
      if ((a['phone'] ?? '').toString().isEmpty) a['ready'] = false;
    }
    await Future.wait(applications.map(_photo));
    data['applications'] = applications;
    return data;
  }
}

/// A completely local sandbox. Never reads or writes Supabase or processes money.
class DemoCircleRepository implements CircleRepository {
  DemoCircleRepository(this.preferences);
  final SharedPreferences preferences;
  static const storageKey = 'vriendtime.circle-preview.v1';
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
    state['exclusions'] ??= const <String>[];
    return state;
  }

  Json _seed(Json state) {
    final app = Map<String, dynamic>.from(state['application'] as Map? ?? {});
    final name = (app['name'] as String?)?.trim();
    state['circle'] = {
      'id': 'demo-circle',
      'name': 'The Thursday Circle',
      'city': 'Alkmaar',
      'schedule': 'Thursday evenings · 19:30',
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
    state['meetups'] = List.generate(
        6,
        (i) => {
              'id': 'week-${i + 1}',
              'week': i + 1,
              'title': circleActivities[i],
              'date': DateTime(2026, 10, 8 + i * 7).toIso8601String(),
              'time': '19:30',
              'venue': i == 0
                  ? 'A restaurant in central Alkmaar'
                  : i == 1
                      ? 'Bowling in Alkmaar'
                      : 'Alkmaar · choose together',
              'completed': false,
              'rsvp': false,
              'confirmed': i == 0 ? 4 : 3,
              'organiser': i < 3 ? 'VriendTime' : 'Your Circle',
              'attendees': rows(state['members'])
                  .map((p) => {
                        'profile_id': p['id'],
                        'name': p['name'],
                        'attended': null
                      })
                  .toList()
            });
    state['messages'] = [
      {
        'name': 'Noor',
        'body': 'Hi everyone! Really looking forward to meeting you all. ☕',
        'own': false
      },
      {
        'name': 'Sam',
        'body':
            'Same here! Nice to have something in the calendar with the same people.',
        'own': false
      },
    ];
    state['check_ins'] = <Json>[];
    state['notifications'] = [
      {
        'title': 'Your Circle is ready',
        'body':
            'Your group and six Thursdays are ready. The first dinner is on 8 October.'
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
        if (['invited', 'active', 'completed'].contains(stage)) {
          state = _seed(state);
        }
        state['stage'] = stage;
        state.remove('refund');
        state.remove('outcome');
        state['payment'] =
            ['active', 'completed'].contains(stage) ? 'demo_paid' : 'unpaid';
        if (stage == 'completed') {
          for (final m in rows(state['meetups'])) {
            m['completed'] = true;
          }
          state['meetups'] = rows(state['meetups'])
              .map((m) => {...m, 'completed': true})
              .toList();
        }
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
      case 'email_notifications':
        state['email_notifications'] = data['enabled'] == true;
        break;
      case 'join':
        if (state['stage'] != 'invited') {
          throw StateError('Open your invitation first.');
        }
        state['stage'] = 'active';
        state['payment'] = 'demo_paid';
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
          {'name': 'You', 'body': body, 'own': true}
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
      case 'admin_schedule':
      case 'schedule':
        final existing = rows(state['meetups']);
        if (data['id'] != null) {
          state['meetups'] = existing
              .map((m) => m['id'] == data['id'] ? {...m, ...data} : m)
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
                  'date': DateTime.parse(data['start_date'] as String)
                      .add(Duration(days: ((m['week'] as int) - 1) * 7))
                      .toIso8601String(),
                  'time': data['time'] ?? '19:30'
                })
            .toList();
        state['stage'] = 'invited';
        break;
      default:
        throw StateError('This action is not available.');
    }
    await _save(state);
  }

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
