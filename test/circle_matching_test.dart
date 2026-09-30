import 'package:flutter_test/flutter_test.dart';
import 'package:vriendtime/src/circles/circle_admin.dart';
import 'package:vriendtime/src/circles/circle_repository.dart';

/// Applicants arrive from the server ordered by how long they have waited,
/// so index order here means seniority.
Json applicant(
  String id, {
  List<String> languages = const ['English'],
  List<String> availability = const ['Thursday evening'],
  List<String> interests = const [],
  bool ready = true,
}) =>
    {
      'profile_id': id,
      'name': id,
      'languages': languages,
      'availability': availability,
      'interests': interests,
      'ready': ready,
    };

void main() {
  test('no suggestion until five people share a language and a slot', () {
    final four = [for (var i = 0; i < 4; i++) applicant('p$i')];
    expect(suggestCircles(four), isEmpty);
  });

  test('suggests a group that satisfies what admin_create requires', () {
    final six = [for (var i = 0; i < 6; i++) applicant('p$i')];
    final suggestions = suggestCircles(six);

    expect(suggestions, isNotEmpty);
    final group = suggestions.first;
    expect(group.members.length, 6);
    expect(group.day, 'Thursday');
    expect(group.period, 'evening');
    // Every member must share the language and the exact slot, because the
    // database rejects the group otherwise.
    for (final member in group.members) {
      expect((member['languages'] as List).contains(group.language), isTrue);
      expect((member['availability'] as List).contains(group.slot), isTrue);
    }
  });

  test('never proposes more than six even when more qualify', () {
    final nine = [for (var i = 0; i < 9; i++) applicant('p$i')];
    expect(suggestCircles(nine).first.members.length, 6);
  });

  test('skips applicants missing a birthday, photo or availability', () {
    final people = [
      for (var i = 0; i < 5; i++) applicant('ready$i'),
      applicant('incomplete', ready: false),
    ];
    final group = suggestCircles(people).first;
    expect(group.members.map((m) => m['profile_id']),
        isNot(contains('incomplete')));
    expect(group.members.length, 5);
  });

  test('people who have waited longest are offered first', () {
    final people = [
      for (var i = 0; i < 6; i++) applicant('early$i'),
      for (var i = 0; i < 6; i++) applicant('late$i'),
    ];
    final group = suggestCircles(people).first;
    expect(group.members.map((m) => m['profile_id']),
        everyElement(startsWith('early')));
  });

  test('a group needs one language in common, not the same language list', () {
    // Five bilingual people plus one Dutch-only: Dutch is the common ground.
    final people = [
      for (var i = 0; i < 5; i++)
        applicant('both$i', languages: const ['English', 'Dutch']),
      applicant('dutch', languages: const ['Dutch']),
    ];
    final dutchGroup =
        suggestCircles(people).firstWhere((s) => s.language == 'Dutch');
    expect(dutchGroup.members.length, 6);
  });

  test('a slot only counts when everyone has it free', () {
    final people = [
      for (var i = 0; i < 5; i++)
        applicant('mon$i', availability: const ['Monday morning']),
      applicant('tue', availability: const ['Tuesday morning']),
    ];
    final suggestions = suggestCircles(people);
    expect(suggestions, hasLength(1));
    expect(suggestions.first.day, 'Monday');
    expect(suggestions.first.members.map((m) => m['profile_id']),
        isNot(contains('tue')));
  });

  group('people who asked not to be matched', () {
    test('a pair key reads the same from either side', () {
      expect(exclusionKey('a', 'b'), exclusionKey('b', 'a'));
    });

    test('pairs are read out of the organiser snapshot', () {
      expect(
          circleExclusions({
            'exclusions': [
              ['b', 'a']
            ]
          }),
          {exclusionKey('a', 'b')});
    });

    test('a snapshot from before this existed yields no pairs', () {
      expect(circleExclusions({}), isEmpty);
      expect(circleExclusions(null), isEmpty);
    });

    test('the excluded person is skipped, and the next one takes the place',
        () {
      final people = [
        for (var i = 0; i < 6; i++) applicant('p$i'),
        applicant('spare'),
      ];
      final group = suggestCircles(people,
          exclusions: {exclusionKey('p0', 'p3')}).first;
      final ids = group.members.map((m) => m['profile_id']).toList();
      expect(ids, contains('p0'));
      expect(ids, isNot(contains('p3')));
      // The group is still full: the blocked person costs their own place,
      // not the group's.
      expect(group.members.length, 6);
      expect(ids, contains('spare'));
    });

    test('no suggestion when exclusions take the pool under five', () {
      final people = [for (var i = 0; i < 5; i++) applicant('p$i')];
      expect(
          suggestCircles(people, exclusions: {
            exclusionKey('p0', 'p1'),
            exclusionKey('p0', 'p2'),
          }),
          isEmpty);
    });

    test('unrelated exclusions never change a clean group', () {
      final people = [for (var i = 0; i < 6; i++) applicant('p$i')];
      expect(
          suggestCircles(people, exclusions: {exclusionKey('x', 'y')})
              .first
              .members
              .length,
          6);
    });
  });

  test('shared interests are the ones literally everyone picked', () {
    final people = [
      for (var i = 0; i < 5; i++)
        applicant('p$i', interests: const ['Food', 'Books']),
      applicant('p5', interests: const ['Food', 'Music']),
    ];
    expect(suggestCircles(people).first.sharedInterests, ['Food']);
  });
}
