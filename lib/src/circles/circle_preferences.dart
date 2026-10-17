import '../core/i18n.dart' show t;
import 'circle_repository.dart' show Json, strings;

const circleLanguages = ['English', 'Dutch'];

/// Where Circles run. Places and suggestions are stored per city.
const circleCity = 'Alkmaar';
const circleDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];
const circleDayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const circlePeriods = ['morning', 'afternoon', 'evening'];

/// The time slots Circles run in: weekday late mornings (Tuesday to
/// Friday, for people who work four days or have children at school),
/// evenings, and Friday-to-Sunday afternoons. No Mondays and no Tuesday
/// evenings (many places are closed).
const circleSlotGrid = <String, List<String>>{
  'tue': ['morning'],
  'wed': ['morning', 'evening'],
  'thu': ['morning', 'evening'],
  'fri': ['morning', 'afternoon', 'evening'],
  'sat': ['afternoon', 'evening'],
  'sun': ['afternoon', 'evening'],
};

/// The usual start time of a slot.
const circleSlotStart = {
  'morning': '10:30',
  'afternoon': '14:00',
  'evening': '19:00',
};

/// When a slot's meetups end; people are free to stay on.
const circleSlotEnd = {
  'morning': '12:00',
  'afternoon': '16:00',
  'evening': '22:00',
};

/// "10:30–12:00".
String circleSlotHours(String part) =>
    '${circleSlotStart[part]}–${circleSlotEnd[part]}';

/// Only the slots in [circleSlotGrid]; older answers (Mondays, weekday
/// afternoons…) are left out so people pick again from what runs now.
Map<String, Set<String>> circleOfferedSlots(Map<String, Set<String>> slots) => {
      for (final e in circleSlotGrid.entries)
        if ((slots[e.key] ?? const {}).any(e.value.contains))
          e.key: slots[e.key]!.where(e.value.contains).toSet()
    };

/// Someone who only picked mornings meets in cafés: the morning plan.
bool circleMorningOnly(Map<String, Set<String>> slots) {
  final parts = slots.values.expand((p) => p).toSet();
  return parts.isNotEmpty && parts.every((p) => p == 'morning');
}

/// "Tue 19:00–22:00", "Sat 14:00–16:00"…, in week order and in the app
/// language.
List<String> circleSlotChips(Map<String, Set<String>> slots) => [
      for (final e in circleSlotGrid.entries)
        for (final part in e.value)
          if (slots[e.key]?.contains(part) == true)
            '${t(circleDays[circleDayKeys.indexOf(e.key)]).substring(0, 3)} ${circleSlotHours(part)}'
    ];

/// Answers to the old "A plan you'd say yes to" question, mapped onto the
/// interests they now live in. Unknown answers are dropped.
const circleLegacyActivity = {
  'Coffee & conversation': 'Coffee',
  'A walk': 'Walking',
  'Board games': 'Board games',
  'A museum': 'Museums',
  'Dinner': 'Food',
  'Bowling': 'Games',
};

/// Interests in groups, so a longer list stays short on screen: one group
/// is open at a time. People pick up to [circleMaxInterests].
const circleInterestCategories = <String, List<String>>{
  'Food & drink': [
    'Food',
    'Coffee',
    'Cooking',
    'Baking',
    'Wine & beer',
    'New restaurants',
  ],
  'Active': [
    'Walking',
    'Running',
    'Cycling',
    'Sport',
    'Yoga',
    'Gym',
    'Swimming',
    'Dancing',
  ],
  'Outdoors': [
    'Nature',
    'Hiking',
    'Gardening',
    'Camping',
  ],
  'Arts & culture': [
    'Art',
    'Museums',
    'Films',
    'Theatre',
    'Music',
    'Concerts',
    'Photography',
    'Books',
    'Writing',
  ],
  'Games': [
    'Games',
    'Board games',
    'Puzzles & quizzes',
    'Video games',
  ],
  'Learning & making': [
    'Crafts',
    'DIY',
    'Languages',
    'Tech',
    'Science',
  ],
  'Out and about': [
    'Travel',
    'Volunteering',
    'Pets',
    'Fashion',
    'Markets',
  ],
};
const circleMaxInterests = 5;

/// The group an interest belongs to, for matching people whose exact
/// picks differ but point the same way (Yoga and Running are both Active).
String? circleInterestCategory(String interest) {
  for (final e in circleInterestCategories.entries) {
    if (e.value.contains(interest)) return e.key;
  }
  return null;
}

const circleGenders = {
  'woman': 'Woman',
  'man': 'Man',
  'non_binary': 'Non-binary',
  'prefer_not': 'Prefer not to say',
};

const circleGoals = [
  'Regular plans',
  'Shared hobbies',
  'Local friends',
  'Other parents',
  'Something else'
];
const circleContexts = [
  'New to the area',
  'Working from home',
  'New job or studies',
  'Friends moved away',
  'A fresh start',
  'More free time now',
  'Something else'
];
const circleStyles = [
  'I warm up slowly',
  'A little of both',
  'I’ll break the ice'
];

int? circleAge(String? value, {DateTime? today}) {
  final date = DateTime.tryParse(value ?? '');
  if (date == null) return null;
  final now = today ?? DateTime.now();
  var age = now.year - date.year;
  if (now.month < date.month ||
      (now.month == date.month && now.day < date.day)) {
    age--;
  }
  return age;
}

Map<String, Set<String>> circleSlots(Json data) {
  final result = <String, Set<String>>{};
  final raw = data['availability_slots'];
  if (raw is Map) {
    for (final day in circleDayKeys) {
      final slots = strings(raw[day]).where(circlePeriods.contains).toSet();
      if (slots.isNotEmpty) result[day] = slots;
    }
  } else {
    // Old answers remain editable without inventing a birthday or new times.
    for (final value in strings(data['availability'])) {
      for (var i = 0; i < circleDays.length; i++) {
        for (final part in circlePeriods) {
          if (value == '${circleDays[i]} $part') {
            result.putIfAbsent(circleDayKeys[i], () => {}).add(part);
          }
        }
      }
    }
  }
  return result;
}

List<String> circleSlotLabels(Map<String, Set<String>> slots) => [
      for (var i = 0; i < circleDays.length; i++)
        for (final part in circlePeriods)
          if (slots[circleDayKeys[i]]?.contains(part) == true)
            '${circleDays[i]} $part',
    ];
