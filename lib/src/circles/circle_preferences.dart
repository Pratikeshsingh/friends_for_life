import 'circle_repository.dart' show Json, strings;

const circleLanguages = ['English', 'Dutch'];
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
const circlePeriodTimes = ['09:00–12:00', '12:00–17:00', '17:00–22:00'];
const circleGoals = ['Regular plans', 'Shared hobbies', 'Local friends'];
const circleContexts = [
  'New to the area',
  'Working from home',
  'New job or studies',
  'Friends moved away',
  'A fresh start',
  'More free time now'
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
