import 'circle_preferences.dart';
import 'circle_repository.dart' show Json, strings;

/// Matchmaking for the organiser. Everything here is a transparent points
/// system, never a black box: each group carries the reasons it scored well,
/// so the organiser can see *why* these people were put together.
///
/// Hard rules, matching what the database enforces in `admin_create`:
/// everyone shares one language, everyone has the same day and time free,
/// and no two people who asked to be kept apart end up together.
///
/// Soft preferences, scored out of 100:
///   interests in common                 40
///   goals in common                     15
///   a close age range                   15
///   a good social mix                   10
///   a shared life situation              5
///   waiting longest                     15

String _id(Json a) => '${a['profile_id']}';

/// Same key as the admin screen uses for "never match these two".
String matchPairKey(String a, String b) =>
    (a.compareTo(b) <= 0) ? '$a|$b' : '$b|$a';

bool isReadyApplicant(Json a) => a['ready'] != false;

int? applicantAge(Json a) => (a['age'] as num?)?.toInt();

/// How long someone has waited, in days. Null when the server did not send
/// a submission date.
int? waitingDays(Json a, {DateTime? now}) {
  final since = DateTime.tryParse('${a['submitted_at'] ?? ''}');
  if (since == null) return null;
  return (now ?? DateTime.now()).difference(since).inDays;
}

String waitingLabel(Json a, {DateTime? now}) {
  final days = waitingDays(a, now: now);
  if (days == null) return '';
  if (days < 1) return 'Applied today';
  if (days < 14) return 'Waiting $days ${days == 1 ? 'day' : 'days'}';
  final weeks = days ~/ 7;
  return 'Waiting $weeks weeks';
}

/// Interests, plus older plan answers translated into the same words, so
/// "A walk" and "Walking" count as one thing.
Set<String> _tastes(Json a) => {
      ...strings(a['interests']),
      for (final x in strings(a['activities'])) circleLegacyActivity[x] ?? x,
    };

/// How alike two people's interests are, 0–1: mostly the exact picks, partly
/// the groups they fall in, so with a long list "Yoga" and "Running" still
/// count for something.
double _tasteFit(Json a, Json b) {
  final x = _tastes(a), y = _tastes(b);
  Set<String> groups(Set<String> s) =>
      {for (final t in s) circleInterestCategory(t) ?? t};
  return 0.7 * _jaccard(x, y) + 0.3 * _jaccard(groups(x), groups(y));
}

double _jaccard(Set<String> x, Set<String> y) {
  if (x.isEmpty && y.isEmpty) return 0;
  final union = {...x, ...y}.length;
  return union == 0 ? 0 : x.intersection(y).length / union;
}

/// How well two people fit, 0–1. Drives who gets added to a group next.
double pairFit(Json a, Json b) {
  var score = 0.0;
  score += 0.5 * _tasteFit(a, b);
  score +=
      0.2 * _jaccard(strings(a['goals']).toSet(), strings(b['goals']).toSet());
  final ageA = applicantAge(a), ageB = applicantAge(b);
  if (ageA != null && ageB != null) {
    score += 0.2 * (1 - ((ageA - ageB).abs() / 15).clamp(0, 1));
  }
  score += 0.1 *
      _jaccard(strings(a['life_context']).toSet(),
          strings(b['life_context']).toSet());
  return score;
}

/// 'At a new table, I'm usually…': 0 warms up slowly, 1 a little of both,
/// 2 breaks the ice. Missing answers count as the middle.
int socialStyle(Json a) =>
    (((a['energy'] as num?)?.toDouble() ?? 2) / 2).round().clamp(0, 2);

/// A table of only quiet starters can stall on the first evening; one or two
/// people who break the ice get everyone talking.
({int points, String? reason}) socialMix(List<Json> members) {
  final styles = members.map(socialStyle).toList();
  final breakers = styles.where((s) => s == 2).length;
  final middle = styles.where((s) => s == 1).length;
  if (breakers > 0 && breakers < members.length) {
    return (points: 10, reason: 'A good mix: someone to break the ice');
  }
  if (breakers == members.length) {
    return (points: 7, reason: 'A lively group: everyone breaks the ice');
  }
  if (middle * 2 >= members.length) return (points: 6, reason: null);
  return (points: 0, reason: null);
}

/// A life situation that at least two people share, e.g. 'New to the area'.
({int points, String? reason}) sharedSituation(List<Json> members) {
  final counts = <String, int>{};
  for (final m in members) {
    for (final c in strings(m['life_context'])) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
  }
  final shared = counts.entries.where((e) => e.value >= 2).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (shared.isEmpty) return (points: 0, reason: null);
  return (
    points: 5,
    reason: '${shared.first.value} share “${shared.first.key}”'
  );
}

/// A proposed group, complete (5–6 people) or not yet (2–4 people).
class CircleMatch {
  CircleMatch({
    required this.members,
    required this.language,
    required this.day,
    required this.period,
    required this.score,
    required this.reasons,
    this.nearlyFree = const [],
  });

  final List<Json> members;
  final String language, day, period;

  /// 0–100, see the table at the top of this file.
  final int score;

  /// Short, plain reasons, in the order the organiser should read them.
  final List<String> reasons;

  /// For an incomplete group: people who speak the language and are free
  /// on the same day or at the same time of day, but not both. Asking them
  /// to widen their availability is the quickest way to complete the group.
  final List<Json> nearlyFree;

  String get slot => '$day $period';
  bool get complete => members.length >= 5;
  int get missing => complete ? 0 : 5 - members.length;
  List<String> get ids => [for (final m in members) _id(m)];
}

/// Reasons and score for any set of people at a given slot. Also used to
/// explain the organiser's own hand-picked selection.
({int score, List<String> reasons}) explainGroup(
  List<Json> members, {
  required String language,
  required String slot,
  required int Function(Json) seniorityRank,
  required int poolSize,
  DateTime? now,
}) {
  final reasons = <String>['Free $slot', 'All speak $language'];
  if (members.length < 2) return (score: 0, reasons: reasons);

  // Interests and activities: what most of the group shares.
  final counts = <String, int>{};
  for (final m in members) {
    for (final t in _tastes(m)) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  final majority = (members.length / 2).ceil();
  final shared = counts.entries
      .where((e) => e.value >= majority && e.value >= 2)
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final everyone =
      shared.where((e) => e.value == members.length).map((e) => e.key);
  final most = shared.where((e) => e.value < members.length).map((e) => e.key);

  var pairTaste = 0.0, pairGoals = 0.0, pairs = 0;
  for (var i = 0; i < members.length; i++) {
    for (var j = i + 1; j < members.length; j++) {
      pairTaste += _tasteFit(members[i], members[j]);
      pairGoals += _jaccard(strings(members[i]['goals']).toSet(),
          strings(members[j]['goals']).toSet());
      pairs++;
    }
  }
  pairTaste /= pairs;
  pairGoals /= pairs;
  // Jaccard between two people rarely passes 0.5, so scale it up.
  final tastePoints = (40 * (pairTaste * 2).clamp(0, 1)).round();
  final goalPoints = (15 * pairGoals).round();

  if (everyone.isNotEmpty) {
    reasons.add('All into ${everyone.take(3).join(', ')}');
  } else if (most.isNotEmpty) {
    reasons.add('Most into ${most.take(3).join(', ')}');
  }

  final goalCounts = <String, int>{};
  for (final m in members) {
    for (final g in strings(m['goals'])) {
      goalCounts[g] = (goalCounts[g] ?? 0) + 1;
    }
  }
  final topGoal = goalCounts.entries.isEmpty
      ? null
      : (goalCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first;
  if (topGoal != null && topGoal.value >= majority && topGoal.value >= 2) {
    reasons.add(topGoal.value == members.length
        ? 'All want ${topGoal.key.toLowerCase()}'
        : '${topGoal.value} of ${members.length} want ${topGoal.key.toLowerCase()}');
  }

  var agePoints = 8;
  final ages = [
    for (final m in members)
      if (applicantAge(m) != null) applicantAge(m)!
  ];
  if (ages.length >= 2) {
    ages.sort();
    final span = ages.last - ages.first;
    agePoints = span <= 8
        ? 15
        : span <= 12
            ? 11
            : span <= 18
                ? 6
                : 0;
    reasons.add('Ages ${ages.first}–${ages.last}');
  }

  // Waiting: the group's average place in the queue.
  final avgRank =
      members.map(seniorityRank).reduce((a, b) => a + b) / members.length;
  final waitPoints =
      poolSize <= 1 ? 15 : (15 * (1 - avgRank / poolSize)).round().clamp(0, 15);
  final longest = members
      .map((m) => waitingDays(m, now: now))
      .whereType<int>()
      .fold<int?>(null, (a, b) => a == null || b > a ? b : a);
  if (longest != null && longest >= 14) {
    reasons.add('Someone has waited ${longest ~/ 7} weeks');
  }

  final mix = socialMix(members);
  if (mix.reason != null) reasons.add(mix.reason!);
  final situation = sharedSituation(members);
  if (situation.reason != null) reasons.add(situation.reason!);

  final score = tastePoints +
      goalPoints +
      agePoints +
      mix.points +
      situation.points +
      waitPoints;
  return (score: score.clamp(0, 100), reasons: reasons);
}

/// Ready applicants free on each day and time, for the availability grid.
/// Keyed by 'Thursday evening'.
Map<String, int> availabilityCounts(List<Json> applicants, {String? language}) {
  final counts = <String, int>{};
  for (final a in applicants.where(isReadyApplicant)) {
    if (language != null && !strings(a['languages']).contains(language)) {
      continue;
    }
    for (final slot in strings(a['availability'])) {
      counts[slot] = (counts[slot] ?? 0) + 1;
    }
  }
  return counts;
}

/// Builds groups per language and slot. Each group starts with the
/// longest-waiting person who is still free, then repeatedly adds whoever
/// fits the current group best, with a small bonus for having waited long.
/// Within a slot the groups never overlap; across slots the same person can
/// appear in several proposals, because they are free at several times.
List<CircleMatch> matchCircles(
  List<Json> applicants, {
  Set<String> exclusions = const {},
  String? language,
  String? slot,
  DateTime? now,
}) {
  final ready = applicants.where(isReadyApplicant).toList();
  final rank = {for (var i = 0; i < ready.length; i++) _id(ready[i]): i};
  int seniority(Json a) => rank[_id(a)] ?? ready.length;
  bool clashes(Json candidate, List<Json> group) => group
      .any((m) => exclusions.contains(matchPairKey(_id(candidate), _id(m))));

  final slots = slot != null
      ? [slot]
      : {for (final a in ready) ...strings(a['availability'])}.toList();
  final languages = language != null ? [language] : circleLanguages;

  final results = <CircleMatch>[];
  final seen = <String>{};
  for (final lang in languages) {
    for (final s in slots) {
      final parts = s.split(' ');
      if (parts.length < 2) continue;
      final pool = [
        for (final a in ready)
          if (strings(a['languages']).contains(lang) &&
              strings(a['availability']).contains(s))
            a
      ];
      final left = [...pool];
      while (left.length >= 2) {
        final group = <Json>[left.removeAt(0)];
        while (group.length < 6) {
          Json? best;
          var bestScore = -1.0;
          for (final c in left) {
            if (clashes(c, group)) continue;
            final fit =
                group.map((m) => pairFit(c, m)).reduce((a, b) => a + b) /
                    group.length;
            // Up to 0.1 for waiting: enough to break ties, not to override fit.
            final wait = 0.1 * (1 - seniority(c) / (ready.length + 1));
            // A nudge towards someone who breaks the ice if nobody does yet.
            final spark =
                socialStyle(c) == 2 && group.every((m) => socialStyle(m) != 2)
                    ? 0.08
                    : 0.0;
            if (fit + wait + spark > bestScore) {
              bestScore = fit + wait + spark;
              best = c;
            }
          }
          if (best == null) break;
          // A sixth seat is a bonus, not a must. Skip a poor fit when exactly
          // five are left: taking one would stop them forming their own group.
          if (group.length == 5 && left.length == 5) {
            var internal = 0.0, pairs = 0;
            for (var i = 0; i < group.length; i++) {
              for (var j = i + 1; j < group.length; j++) {
                internal += pairFit(group[i], group[j]);
                pairs++;
              }
            }
            final fit =
                group.map((m) => pairFit(best!, m)).reduce((a, b) => a + b) /
                    group.length;
            if (fit < 0.6 * (internal / pairs)) break;
          }
          group.add(best);
          left.remove(best);
        }
        if (group.length < 2) continue;
        final key = (group.map(_id).toList()..sort()).join(',');
        if (!seen.add(key)) continue;
        final explained = explainGroup(group,
            language: lang,
            slot: s,
            seniorityRank: seniority,
            poolSize: ready.length,
            now: now);
        results.add(CircleMatch(
          members: group,
          language: lang,
          day: parts.first,
          period: parts.last,
          score: explained.score,
          reasons: explained.reasons,
          nearlyFree: group.length >= 5
              ? const []
              : _nearlyFree(ready, group, lang, parts.first, parts.last),
        ));
      }
    }
  }
  results.sort((a, b) {
    if (a.complete != b.complete) return a.complete ? -1 : 1;
    final byScore = b.score.compareTo(a.score);
    return byScore != 0
        ? byScore
        : b.members.length.compareTo(a.members.length);
  });
  return results;
}

/// Same language, and free on the same day or the same time of day, but not
/// at this exact slot. Best fit first.
List<Json> _nearlyFree(List<Json> ready, List<Json> group, String language,
    String day, String period) {
  final inGroup = group.map(_id).toSet();
  final slot = '$day $period';
  final candidates = [
    for (final a in ready)
      if (!inGroup.contains(_id(a)) &&
          strings(a['languages']).contains(language) &&
          !strings(a['availability']).contains(slot) &&
          strings(a['availability'])
              .any((s) => s.startsWith('$day ') || s.endsWith(' $period')))
        a
  ];
  double fit(Json c) =>
      group.map((m) => pairFit(c, m)).reduce((a, b) => a + b) / group.length;
  candidates.sort((a, b) => fit(b).compareTo(fit(a)));
  return candidates.take(3).toList();
}

/// Ready people who could join [selected] at [slot] in [language], best fit
/// first. Used for "swap someone" and "fill the last place".
List<Json> replacementsFor(
  List<Json> applicants,
  List<Json> selected, {
  required String slot,
  required String language,
  Set<String> exclusions = const {},
}) {
  final ids = selected.map(_id).toSet();
  final candidates = [
    for (final a in applicants.where(isReadyApplicant))
      if (!ids.contains(_id(a)) &&
          strings(a['languages']).contains(language) &&
          strings(a['availability']).contains(slot) &&
          !selected
              .any((m) => exclusions.contains(matchPairKey(_id(a), _id(m)))))
        a
  ];
  if (selected.isEmpty) return candidates;
  double fit(Json c) =>
      selected.map((m) => pairFit(c, m)).reduce((a, b) => a + b) /
      selected.length;
  candidates.sort((a, b) => fit(b).compareTo(fit(a)));
  return candidates;
}

/// The slots and languages every selected person shares. Empty means the
/// selection cannot become a Circle as it stands.
({List<String> slots, List<String> languages}) commonGround(
    List<Json> selected) {
  if (selected.isEmpty) return (slots: const [], languages: const []);
  final slots = strings(selected.first['availability']).toSet();
  final languages = strings(selected.first['languages']).toSet();
  for (final m in selected.skip(1)) {
    slots.retainAll(strings(m['availability']));
    languages.retainAll(strings(m['languages']));
  }
  final orderedSlots = [
    for (final d in circleDays)
      for (final p in circlePeriods)
        if (slots.contains('$d $p')) '$d $p'
  ];
  return (
    slots: orderedSlots,
    languages: circleLanguages.where(languages.contains).toList()
  );
}

/// Everyone who is ready, placed in at most one recommended group.
class CirclePlan {
  const CirclePlan({required this.groups, required this.unmatched});

  /// Complete groups first (ready to create), then groups still forming,
  /// largest first.
  final List<CircleMatch> groups;

  /// Ready people who share a language and a time with nobody else yet.
  final List<Json> unmatched;

  List<CircleMatch> get complete => [
        for (final g in groups)
          if (g.complete) g
      ];
  List<CircleMatch> get forming => [
        for (final g in groups)
          if (!g.complete) g
      ];
}

/// Splits the ready applicants into non-overlapping groups. Unlike
/// [matchCircles], which lists every possible group (so someone free on two
/// evenings shows up twice), each person lands in exactly one place here:
/// the best complete group available, else the largest group they can start.
CirclePlan planCircles(
  List<Json> applicants, {
  Set<String> exclusions = const {},
  String? language,
  DateTime? now,
}) {
  final ready = applicants.where(isReadyApplicant).toList();
  var left = [...ready];
  final groups = <CircleMatch>[];
  while (left.length >= 2) {
    final options = matchCircles(left,
        exclusions: exclusions, language: language, now: now);
    if (options.isEmpty) break;
    options.sort((a, b) {
      if (a.complete != b.complete) return a.complete ? -1 : 1;
      if (!a.complete && a.members.length != b.members.length) {
        return b.members.length.compareTo(a.members.length);
      }
      return b.score.compareTo(a.score);
    });
    final best = options.first;
    groups.add(best);
    final taken = best.ids.toSet();
    left = [
      for (final a in left)
        if (!taken.contains(_id(a))) a
    ];
  }
  return CirclePlan(groups: groups, unmatched: left);
}
