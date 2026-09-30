import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/circles/circle_matching.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';

Json person(String id,
        {List<String> languages = const ['English'],
        List<String> availability = const ['Thursday evening'],
        List<String> interests = const ['Coffee'],
        List<String> goals = const ['Local friends'],
        int age = 30,
        bool ready = true}) =>
    {
      'profile_id': id,
      'name': id,
      'languages': languages,
      'availability': availability,
      'interests': interests,
      'goals': goals,
      'age': age,
      'ready': ready,
    };

void main() {
  test('groups never mix languages, slots or blocked pairs', () {
    final people = [
      for (var i = 0; i < 6; i++) person('en$i'),
      for (var i = 0; i < 6; i++) person('nl$i', languages: ['Dutch']),
      person('late', availability: ['Monday morning']),
    ];
    final matches =
        matchCircles(people, exclusions: {matchPairKey('en0', 'en1')});
    for (final m in matches) {
      for (final member in m.members) {
        expect((member['languages'] as List).contains(m.language), isTrue);
        expect((member['availability'] as List).contains(m.slot), isTrue);
      }
      expect(m.ids.contains('en0') && m.ids.contains('en1'), isFalse);
    }
    final dutch = matches.firstWhere((m) => m.language == 'Dutch');
    expect(dutch.complete, isTrue);
    expect(dutch.members, hasLength(6));
  });

  test('people who share interests end up together', () {
    final people = [
      for (var i = 0; i < 5; i++)
        person('food$i', interests: ['Cooking', 'Food']),
      for (var i = 0; i < 5; i++)
        person('sport$i', interests: ['Sport', 'Running']),
    ];
    final complete = matchCircles(people).where((m) => m.complete).toList();
    expect(complete, hasLength(2));
    for (final m in complete) {
      final kinds = m.ids.map((id) => id.replaceAll(RegExp(r'\d'), ''));
      expect(kinds.toSet(), hasLength(1));
      expect(m.reasons.any((r) => r.startsWith('All into')), isTrue);
    }
  });

  test('seven free people make one group of six, not five plus two', () {
    final people = [
      for (var i = 0; i < 5; i++) person('walk$i', interests: ['Walking']),
      person('cook', interests: ['Cooking']),
      person('film', interests: ['Film']),
    ];
    final best = matchCircles(people).first;
    expect(best.members, hasLength(6));
  });

  test('a small group is marked incomplete and suggests people nearly free',
      () {
    final people = [
      for (var i = 0; i < 3; i++) person('core$i'),
      person('sameDay', availability: ['Thursday morning']),
      person('otherLanguage',
          languages: ['Dutch'], availability: ['Thursday morning']),
    ];
    final almost = matchCircles(people, slot: 'Thursday evening').single;
    expect(almost.complete, isFalse);
    expect(almost.missing, 2);
    expect(almost.nearlyFree.map((p) => p['profile_id']), ['sameDay']);
  });

  test('people missing details are left out of matching and the grid', () {
    final people = [
      for (var i = 0; i < 5; i++) person('ok$i'),
      person('missing', ready: false),
    ];
    expect(matchCircles(people).first.ids, isNot(contains('missing')));
    expect(availabilityCounts(people)['Thursday evening'], 5);
  });

  test('waiting time reads sensibly', () {
    final now = DateTime(2026, 9, 30);
    expect(waitingLabel({'submitted_at': '2026-09-02T10:00:00Z'}, now: now),
        'Waiting 3 weeks');
    expect(waitingLabel({'submitted_at': '2026-09-27T10:00:00Z'}, now: now),
        'Waiting 2 days');
    expect(waitingLabel({}, now: now), '');
  });

  test('common ground and replacements respect the selection', () {
    final a = person('a', availability: ['Thursday evening', 'Friday evening']);
    final b = person('b', availability: ['Thursday evening']);
    final common = commonGround([a, b]);
    expect(common.slots, ['Thursday evening']);
    expect(common.languages, ['English']);

    final fits = replacementsFor(
        [
          a,
          b,
          person('c'),
          person('blocked'),
          person('busy', availability: ['Monday morning'])
        ],
        [a, b],
        slot: 'Thursday evening',
        language: 'English',
        exclusions: {matchPairKey('a', 'blocked')});
    expect(fits.map((p) => p['profile_id']), ['c']);
  });

  test('social style and shared situation count, and say why', () {
    Json p(String id, int energy, [List<String> context = const []]) =>
        {...person(id), 'energy': energy, 'life_context': context};
    final quiet = [for (var i = 0; i < 5; i++) p('q$i', 0)];
    final mixed = [p('b', 4), for (var i = 0; i < 4; i++) p('m$i', 0)];
    expect(socialMix(quiet).points, 0);
    expect(socialMix(mixed).points, 10);
    expect(socialMix(mixed).reason, contains('break the ice'));

    final twoNew = [
      p('a', 2, ['New to the area']),
      p('b', 2, ['New to the area']),
      p('c', 2),
    ];
    expect(sharedSituation(twoNew).points, 5);
    expect(sharedSituation(twoNew).reason, '2 share “New to the area”');
    expect(sharedSituation([p('x', 2), p('y', 2)]).points, 0);
  });

  test('the matcher pulls in someone who breaks the ice', () {
    final people = [
      for (var i = 0; i < 5; i++) {...person('quiet$i'), 'energy': 0},
      {...person('spark'), 'energy': 4},
      {...person('quiet5'), 'energy': 0},
    ];
    final group = matchCircles(people).first;
    expect(group.ids, contains('spark'));
  });

  test('the plan puts everyone in one group at most', () {
    final people = [
      // Six free on Thursday and Saturday: one complete group.
      for (var i = 0; i < 6; i++)
        person('both$i',
            availability: ['Thursday evening', 'Saturday afternoon']),
      // Two who only share Monday: a forming group, three more needed.
      person('mon1', availability: ['Monday morning']),
      person('mon2', availability: ['Monday morning']),
      // Someone alone in their slot.
      person('solo', availability: ['Sunday morning']),
    ];
    final plan = planCircles(people);
    final placed = [for (final g in plan.groups) ...g.ids];
    expect(placed.toSet().length, placed.length, reason: 'no one twice');
    expect(plan.complete, hasLength(1));
    expect(plan.complete.single.members, hasLength(6));
    final monday = plan.forming.single;
    expect(monday.ids.toSet(), {'mon1', 'mon2'});
    expect(monday.missing, 3);
    expect(plan.unmatched.map((p) => p['profile_id']), ['solo']);
  });
}
