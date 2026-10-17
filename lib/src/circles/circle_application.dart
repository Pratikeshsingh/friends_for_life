import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import 'circle_repository.dart';
import 'circle_preferences.dart';
import 'circle_widgets.dart';

/// Everything someone can pick under "What are you into?".
final circleInterestOptions = [
  for (final group in circleInterestCategories.values) ...group
];

/// Exposes the phone rules to tests without widening the widget's API.
class CircleApplicationTesting {
  static String normalise(String v) =>
      _CircleApplicationState.normalisePhone(v);
  static bool isValid(String v) => _CircleApplicationState.isValidPhone(v);
}

class CircleApplication extends StatefulWidget {
  const CircleApplication(
      {super.key,
      required this.initial,
      required this.onSave,
      required this.onSubmit,
      required this.busy,
      this.onPhoto,
      this.onSaveForLater,
      this.onDone,
      this.onCancel,
      this.initialStep = 0,
      this.focusedEdit = false,
      this.resume = false});
  final Json initial;
  final Future<void> Function(Json) onSave, onSubmit;
  final Future<Json?> Function()? onPhoto;
  final bool busy;

  /// Called once a "save for later" draft is stored, so the shell can put
  /// people somewhere other than the form they just chose to leave.
  final VoidCallback? onSaveForLater;

  /// Called after a focused edit is saved, so the shell can close the form
  /// and return the member to where they came from.
  final VoidCallback? onDone;
  final VoidCallback? onCancel;

  /// Which step to open on, so "edit my availability" from the profile
  /// doesn't drop people back on the name and date-of-birth step.
  final int initialStep;

  /// Editing one answer, not filling in an application. The step indicator,
  /// the "2 of 4" counter and the walk to the end all belong to the first
  /// run; someone changing their availability wants to change it and leave.
  final bool focusedEdit;

  /// Continuing an application: open at the first step that still needs an
  /// answer instead of walking again through steps that are already done.
  final bool resume;
  @override
  State<CircleApplication> createState() => _CircleApplicationState();
}

class _CircleApplicationState extends State<CircleApplication> {
  late final TextEditingController name, intro, phone;
  late Set<String> languages, interests, goals, lifeContext;
  late Map<String, Set<String>> slots;
  late final TextEditingController otherTimes;

  /// One-to-ones on their own times (often more than the group's).
  late Map<String, Set<String>> coffeeSlots;
  bool coffeeSeparate = false;

  /// "Something else": a few words of their own (optional).
  late final TextEditingController goalsOther, contextOther;
  String? gender;
  DateTime? birthday;

  /// Day, month and year picked separately: three short lists are clearer
  /// than a calendar where you have to discover that the years scroll.
  int? bDay, bMonth, bYear;
  String? photoPath, photoUrl;
  int style = 1, step = 0;

  /// The interest group open when the step appears: the first one with a
  /// choice in it, else the first group.
  late String openInterestGroup;
  bool commitment = false, saving = false;
  String? error, saved;
  bool get busy => widget.busy || saving;
  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    name = TextEditingController(text: d['name'] as String? ?? '');
    intro = TextEditingController(text: d['intro'] as String? ?? '');
    phone = TextEditingController(text: d['phone'] as String? ?? '');
    birthday = DateTime.tryParse(d['date_of_birth']?.toString() ?? '');
    bDay = birthday?.day;
    bMonth = birthday?.month;
    bYear = birthday?.year;
    photoPath = d['photo_path'] as String?;
    photoUrl = d['photo_url'] as String?;
    languages = strings(d['languages']).where(circleLanguages.contains).toSet();
    // Earlier applicants answered a separate plan question; fold those
    // answers into the matching interests so nothing they said is lost.
    interests = {
      ...strings(d['interests']),
      for (final a in strings(d['activities']))
        if (circleLegacyActivity[a] != null) circleLegacyActivity[a]!,
    }.where(circleInterestOptions.contains).toSet();
    openInterestGroup = circleInterestCategories.keys.firstWhere(
        (g) => circleInterestCategories[g]!.any(interests.contains),
        orElse: () => circleInterestCategories.keys.first);
    goals = strings(d['goals']).where(circleGoals.contains).toSet();
    lifeContext =
        strings(d['life_context']).where(circleContexts.contains).toSet();
    slots = circleOfferedSlots(circleSlots(d));
    coffeeSlots = circleOfferedSlots(
        circleSlots({'availability_slots': d['coffee_slots'] ?? const {}}));
    coffeeSeparate = coffeeSlots.isNotEmpty;
    otherTimes = TextEditingController(text: d['other_times'] as String? ?? '');
    goalsOther = TextEditingController(text: d['goals_other'] as String? ?? '');
    contextOther =
        TextEditingController(text: d['life_context_other'] as String? ?? '');
    gender =
        circleGenders.containsKey(d['gender']) ? d['gender'] as String : null;
    style = (((d['energy'] as num?)?.toDouble() ?? 2) / 2).round().clamp(0, 2);
    commitment = d['commitment'] == true;
    step = widget.initialStep.clamp(0, 3);
    if (widget.resume && widget.initialStep == 0 && !widget.focusedEdit) {
      step = _firstIncompleteStep();
    }
  }

  int _firstIncompleteStep() {
    final asked = step;
    for (var s = 0; s < 3; s++) {
      step = s;
      if (validate() != null) {
        step = asked;
        return s;
      }
    }
    step = asked;
    return 3;
  }

  // The form stays alive (off-screen) while the Profile tab is open; a
  // photo added there must show up here too.
  @override
  void didUpdateWidget(covariant CircleApplication old) {
    super.didUpdateWidget(old);
    final path = widget.initial['photo_path'] as String?;
    if (path != null && path != old.initial['photo_path']) {
      photoPath = path;
      photoUrl = widget.initial['photo_url'] as String?;
    }
  }

  @override
  void dispose() {
    name.dispose();
    intro.dispose();
    phone.dispose();
    otherTimes.dispose();
    goalsOther.dispose();
    contextOther.dispose();
    super.dispose();
  }

  Map<String, Set<String>> get currentSlots => {
        for (final e in slots.entries)
          if (e.value.isNotEmpty) e.key: e.value
      };

  /// Only the first letter: "robin" becomes "Robin", while Dutch names
  /// keep their own shape ("van der Berg" must not become "Van Der Berg").
  static String capitaliseName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  /// Mirrors the database: spaces and dashes dropped, 06… and 00… turned
  /// into international form, so "06 1234 5678" is stored as +31612345678.
  static String normalisePhone(String value) {
    var v = value.replaceAll(RegExp(r'[\s().-]'), '');
    if (v.startsWith('00')) v = '+${v.substring(2)}';
    if (RegExp(r'^06\d{8}$').hasMatch(v)) v = '+31${v.substring(1)}';
    return v;
  }

  static bool isValidPhone(String value) =>
      RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalisePhone(value));

  Json get data => {
        'name': capitaliseName(name.text),
        'city': 'Alkmaar',
        'date_of_birth': birthday == null
            ? null
            : '${birthday!.year.toString().padLeft(4, '0')}-${birthday!.month.toString().padLeft(2, '0')}-${birthday!.day.toString().padLeft(2, '0')}',
        'languages': languages.toList(),
        'availability_slots': {
          for (final e in currentSlots.entries) e.key: e.value.toList()
        },
        'availability': circleSlotLabels(currentSlots),
        if (coffeeSeparate &&
            coffeeSlots.values.any((parts) => parts.isNotEmpty))
          'coffee_slots': {
            for (final e in coffeeSlots.entries)
              if (e.value.isNotEmpty) e.key: e.value.toList()
          },
        'interests': interests.toList(),
        // The database still requires this field; it now mirrors interests.
        'activities': interests.toList(),
        'energy': style * 2,
        'goals': goals.toList(),
        'life_context': lifeContext.toList(),
        if (goals.contains('Something else'))
          'goals_other': goalsOther.text.trim(),
        if (lifeContext.contains('Something else'))
          'life_context_other': contextOther.text.trim(),
        'intro': intro.text.trim(),
        'commitment': commitment,
        'phone': normalisePhone(phone.text),
        'gender': gender,
        'other_times': otherTimes.text.trim(),
      };
  String? validate() {
    if (step == 0) {
      if (name.text.trim().isEmpty) return 'Add your first name.';
      if (_impossibleDate) {
        return 'That date doesn’t exist. Check the day and month.';
      }
      final age = circleAge(data['date_of_birth'] as String?);
      if (age == null || age < 18 || age > 120) {
        return 'Add your date of birth. Circles are for adults 18+.';
      }
      if (phone.text.trim().isNotEmpty && !isValidPhone(phone.text)) {
        return 'Check your WhatsApp number, for example 06 12345678.';
      }
      if (gender == null) {
        return 'Choose how you describe yourself. It stays private.';
      }
      if (languages.isEmpty) return 'Choose English, Dutch, or both.';
    }
    if (step == 1 && currentSlots.isEmpty && otherTimes.text.trim().isEmpty) {
      return 'Choose at least one time, or tell us which times work for you.';
    }
    if (step == 2 && interests.isEmpty) {
      return 'Choose at least one thing under “What are you into?”.';
    }
    if (step == 2 && goals.isEmpty) {
      return 'Choose at least one thing under “I’d love to find…”.';
    }
    if (step == 3) {
      if (widget.onPhoto != null && photoPath == null) {
        return 'Add a clear photo so your Circle can recognise you.';
      }
      if (!commitment) {
        return 'Confirm that you can make time for six weekly meetups.';
      }
    }
    return null;
  }

  Future<void> next({bool draft = false}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      error = draft ? null : validate();
      saved = null;
    });
    if (error != null) return;
    setState(() => saving = true);
    try {
      if (widget.focusedEdit && !draft) {
        // One answer changed, saved, done. Walking on to the remaining steps
        // would re-ask for a photo and the commitment checkbox, and a full
        // re-submission is not what "edit my availability" means.
        await widget.onSave(data);
        if (mounted) widget.onDone?.call();
      } else if (step == 3 && !draft) {
        await widget.onSubmit(data);
      } else {
        await widget.onSave(data);
        if (mounted) {
          setState(() {
            if (!draft) {
              step++;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Scrollable.ensureVisible(context,
                      alignment: 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220));
                }
              });
            } else {
              saved = 'Saved. Pick up here anytime.';
            }
          });
          // "Save for later" means leaving, so hand back to the shell
          // rather than sitting on the form with a confirmation message.
          if (draft) widget.onSaveForLater?.call();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => error = 'Your answers could not be saved. Please try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  /// Sets [birthday] once all three parts form a real date.
  void _setBirthdayPart({int? day, int? month, int? year}) {
    setState(() {
      bDay = day ?? bDay;
      bMonth = month ?? bMonth;
      bYear = year ?? bYear;
      birthday = null;
      if (bDay != null && bMonth != null && bYear != null) {
        final date = DateTime(bYear!, bMonth!, bDay!);
        if (date.month == bMonth && date.day == bDay) birthday = date;
      }
    });
  }

  bool get _impossibleDate =>
      bDay != null && bMonth != null && bYear != null && birthday == null;

  Widget _birthdayPicker(BuildContext context) {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', //
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    // Shown in the closed box; the open list keeps the full month names.
    const shortMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    Widget pick<T>(String label, T? value, List<(T, String)> options,
            ValueChanged<T?> onChanged, {List<String>? closedLabels}) =>
        DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            menuMaxHeight: 320,
            iconSize: 20,
            selectedItemBuilder: closedLabels == null
                ? null
                : (context) => [
                      for (final text in closedLabels)
                        Text(text, overflow: TextOverflow.ellipsis)
                    ],
            // Three boxes share one phone-width row: a slightly smaller font
            // and short month names keep "30" and the month whole.
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontSize: 16, color: circleNavy),
            decoration: InputDecoration(
                labelText: t(label),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 14)),
            items: [
              for (final (v, text) in options)
                DropdownMenuItem<T>(
                    value: v,
                    child: Text(text, overflow: TextOverflow.ellipsis))
            ],
            onChanged: busy ? null : onChanged);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Date of birth',
          style: TextStyle(fontWeight: FontWeight.w800, color: circleNavy)),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, box) {
        final dayBox = pick<int>(
            'Day',
            bDay,
            [for (var d = 1; d <= 31; d++) (d, '$d')],
            (v) => _setBirthdayPart(day: v));
        // Newest first, starting at the youngest age allowed (18).
        final yearBox = pick<int>(
            'Year',
            bYear,
            [for (var y = now.year - 18; y >= now.year - 100; y--) (y, '$y')],
            (v) => _setBirthdayPart(year: v));
        // On a phone three boxes in one row leave too little room: "30"
        // and the month were cut off. Day and month share a row there,
        // with the year underneath; wider screens keep one row.
        final oneRow = box.maxWidth >= 250;
        final monthBox = pick<int>(
            'Month',
            bMonth,
            [for (var m = 1; m <= 12; m++) (m, months[m - 1])],
            (v) => _setBirthdayPart(month: v),
            closedLabels: oneRow || box.maxWidth < 300 ? shortMonths : null);
        if (oneRow) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 4, child: dayBox),
            const SizedBox(width: 8),
            Expanded(flex: 4, child: monthBox),
            const SizedBox(width: 8),
            Expanded(flex: 5, child: yearBox),
          ]);
        }
        return Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: dayBox),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: monthBox),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: yearBox),
            const Spacer(),
          ]),
        ]);
      }),
      const SizedBox(height: 6),
      Text(
          _impossibleDate
              ? 'That date doesn’t exist. Check the day and month.'
              : 'Circles are for adults 18+. Kept private.',
          style: TextStyle(
              fontSize: 12,
              color: _impossibleDate
                  ? Theme.of(context).colorScheme.error
                  : const Color(0xFF66727C))),
    ]);
  }

  /// A rectangular upload gets cropped to a circle everywhere it appears,
  /// so show it that way rather than as the original rectangle.
  Future<void> _previewPhoto() async {
    await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
              scrollable: true,
              title: const Text('How your Circle sees you'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                CircleMemberAvatar(capitaliseName(name.text),
                    radius: 92, photoUrl: photoUrl, photoPath: photoPath),
                const SizedBox(height: 16),
                Text(capitaliseName(name.text),
                    style: Theme.of(c).textTheme.titleMedium),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Looks good')),
                FilledButton(
                    onPressed: () {
                      Navigator.pop(c);
                      choosePhoto();
                    },
                    child: const Text('Change photo'))
              ],
            ));
  }

  Future<void> choosePhoto() async {
    setState(() => saving = true);
    try {
      final result = await widget.onPhoto!();
      if (result != null && mounted) {
        setState(() {
          photoPath = result['photo_path'] as String?;
          photoUrl = result['photo_url'] as String?;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is StateError
            ? e.message
            : 'Photo upload failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!widget.focusedEdit) ...[
          Row(children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 5,
                          decoration: BoxDecoration(
                              color: i <= step
                                  ? circleTeal
                                  : const Color(0xFFDDE7E3),
                              borderRadius: BorderRadius.circular(4)))))
          ]),
          const SizedBox(height: 24),
        ],
        CircleHeading(
            widget.focusedEdit
                ? [
                    'Your details.',
                    'Your time.',
                    'Your kind of company.',
                    'Your first hello.'
                  ][step]
                : [
                    'Start with you.',
                    'Find your time.',
                    'Your kind of company.',
                    'Your first hello.'
                  ][step],
            eyebrow: widget.focusedEdit
                ? 'Editing'
                : '${[
                    'You',
                    'Your week',
                    'Your people',
                    'Your profile'
                  ][step]} · ${step + 1} of 4',
            subtitle: [
              'A few basics. Your birthday and number stay private.',
              'A regular slot you can keep for six weeks.',
              'No right answers. Just what feels like you.',
              'This is how your Circle will get to know you.'
            ][step]),
        CirclePanel(children: [
          if (step == 0) ...[
            TextField(
                controller: name,
                enabled: !busy,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                    labelText: t('First name'), counterText: '')),
            const SizedBox(height: 20),
            _birthdayPicker(context),
            const SizedBox(height: 20),
            _genderChoice(),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _label('WhatsApp number (optional)')),
              const CircleInfoButton('Your WhatsApp number',
                  'Optional. Only the organiser sees it, in case they need to reach you quickly. After week 2 you can choose to join a WhatsApp group with your Circle; then the others who join see it too. For example: 06 12345678.'),
            ]),
            const SizedBox(height: 6),
            TextField(
                controller: phone,
                enabled: !busy,
                maxLength: 20,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                // The why sits behind the ⓘ; the field itself stays plain.
                decoration: InputDecoration(
                    hintText: '06 12345678',
                    prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 14, right: 8),
                        child: CircleWhatsAppIcon()),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 0, minHeight: 0),
                    counterText: '')),
            const SizedBox(height: 20),
            _choices('Which languages are you happy to talk in?',
                circleLanguages, languages),
            const SizedBox(height: 10),
            const Text(
                'Comfortable in both? Pick both: you’ll meet more people.',
                style: TextStyle(fontSize: 12)),
          ],
          if (step == 1) ...[
            _label('When are you free?'),
            const SizedBox(height: 4),
            const Text('Tap every time that works (Netherlands time).',
                style: TextStyle(fontSize: 13, color: Color(0xFF4F5D66))),
            const SizedBox(height: 6),
            const Row(children: [
              Icon(Icons.place_outlined, size: 17, color: circleTeal),
              SizedBox(width: 6),
              Expanded(
                  child: Text('All meetups are in the centre of Alkmaar.',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: circleNavy))),
            ]),
            const SizedBox(height: 14),
            _slotGrid(slots),
            const SizedBox(height: 6),
            Wrap(spacing: 4, children: [
              TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            for (final e in circleSlotGrid.entries) {
                              if (e.value.contains('evening')) {
                                slots
                                    .putIfAbsent(e.key, () => {})
                                    .add('evening');
                              }
                            }
                          }),
                  child: const Text('All evenings')),
              TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            // Friday to Sunday afternoons and evenings
                            // (not Friday morning: that's a weekday).
                            for (final day in ['fri', 'sat', 'sun']) {
                              slots.putIfAbsent(day, () => {}).addAll(
                                  circleSlotGrid[day]!
                                      .where((p) => p != 'morning'));
                            }
                          }),
                  child: const Text('Weekends')),
              TextButton(
                  onPressed: busy ? null : () => setState(slots.clear),
                  child: const Text('Clear')),
            ]),
            if (currentSlots.isNotEmpty) ...[
              const SizedBox(height: 8),
              _MatchChance(
                  slots: currentSlots.values.fold(0, (n, v) => n + v.length)),
            ],
            const SizedBox(height: 12),
            // Times we don't run yet go to the organiser, who gets in touch:
            // a free-text time can't be matched automatically.
            _otherTimesRow(),
            const Divider(height: 36),
            // One-to-ones: the same times, or their own (often more).
            Row(children: [
              Expanded(child: _label('Times for one-to-one coffees or drinks')),
              const CircleInfoButton('One-to-ones',
                  'Between the group meetups we suggest a coffee or a drink with one person from your Circle: optional, but recommended. We pick a time you’re both free. Rather meet in the daytime? Choose your own times and add a daytime.'),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                  label: const Text('Same times'),
                  selected: !coffeeSeparate,
                  onSelected: busy
                      ? null
                      : (_) => setState(() => coffeeSeparate = false)),
              ChoiceChip(
                  label: const Text('Choose separately'),
                  selected: coffeeSeparate,
                  onSelected: busy
                      ? null
                      : (_) => setState(() {
                            coffeeSeparate = true;
                            // Start from the group times, to add to.
                            if (coffeeSlots.isEmpty) {
                              for (final e in slots.entries) {
                                coffeeSlots[e.key] = {...e.value};
                              }
                            }
                          })),
            ]),
            if (coffeeSeparate) ...[
              const SizedBox(height: 14),
              _slotGrid(coffeeSlots),
            ],
          ],
          if (step == 2) ...[
            // One question. "A plan you'd say yes to" used to follow, but
            // matching already treated both lists as one, so it only made
            // the form longer.
            _interestPicker(),
            // Each question its own block, so the step reads as three
            // short questions rather than one long list.
            const Divider(height: 48),
            _label('At a new table, I’m usually…'),
            const SizedBox(height: 12),
            for (var i = 0; i < 3; i++)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                      selected: style == i,
                      child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: busy ? null : () => setState(() => style = i),
                          child: AnimatedContainer(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: style == i
                                      ? const Color(0xFFE0F0E9)
                                      : const Color(0xFFF8F5EE),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: style == i
                                          ? circleTeal
                                          : Colors.transparent)),
                              child: Row(children: [
                                Icon(
                                    [
                                      Icons.coffee_outlined,
                                      Icons.wb_twilight_rounded,
                                      Icons.waving_hand_outlined
                                    ][i],
                                    color: circleTeal),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: Text(circleStyles[i],
                                        style: const TextStyle(
                                            color: circleNavy,
                                            fontWeight: FontWeight.w600))),
                                if (style == i)
                                  const Icon(Icons.check_circle,
                                      color: circleTeal, size: 20)
                              ]))))),
            const Divider(height: 40),
            _choices('I’d love to find…', circleGoals, goals),
            if (goals.contains('Something else')) _otherNote(goalsOther),
            const SizedBox(height: 20),
            // This was hidden behind a collapsed "(optional)" disclosure,
            // which is why almost nobody filled it in — and it is one of the
            // better matching signals we have. People who arrived in the
            // city the same way tend to have the same week.
            // Optional, so it sits in its own quieter box with a label,
            // after the required questions, rather than looking like one.
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8F5EE),
                    borderRadius: BorderRadius.circular(18)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('OPTIONAL',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF66727C))),
                      const SizedBox(height: 6),
                      _choices(
                          'What brings you here?', circleContexts, lifeContext,
                          info: const CircleInfoButton('Why we ask',
                              'Private: never shown to your Circle. People who are in a similar moment, like new to the area or back to more free time, often have the same kind of week. It helps us put you together.')),
                      if (lifeContext.contains('Something else'))
                        _otherNote(contextOther),
                    ])),
          ],
          if (step == 3) ...[
            Center(
                child: Column(children: [
              Semantics(
                  button: photoUrl != null,
                  label: photoUrl == null
                      ? null
                      : 'See how your photo looks to your Circle',
                  // The portrait leads, with its own camera badge.
                  child: Stack(clipBehavior: Clip.none, children: [
                    InkWell(
                        customBorder: const CircleBorder(),
                        onTap: photoUrl == null ? null : _previewPhoto,
                        child: CircleMemberAvatar(capitaliseName(name.text),
                            radius: 48,
                            photoUrl: photoUrl,
                            photoPath: photoPath)),
                    if (widget.onPhoto != null)
                      Positioned(
                          right: -2,
                          bottom: -2,
                          child: Material(
                              color: circleNavy,
                              shape: const CircleBorder(
                                  side: BorderSide(
                                      color: Colors.white, width: 3)),
                              child: IconButton(
                                  tooltip: t(photoPath == null
                                      ? 'Add a clear photo'
                                      : 'Change photo'),
                                  onPressed: busy ? null : choosePhoto,
                                  iconSize: 18,
                                  constraints: const BoxConstraints.tightFor(
                                      width: 38, height: 38),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.photo_camera_rounded,
                                      color: Colors.white)))),
                  ])),
              const SizedBox(height: 10),
              Text(capitaliseName(name.text),
                  style: Theme.of(context).textTheme.headlineSmall),
              const Text('Alkmaar'),
              if (widget.onPhoto != null)
                TextButton.icon(
                    onPressed: busy ? null : choosePhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(photoPath == null
                        ? 'Add a clear photo'
                        : 'Change photo')),
              if (photoUrl != null)
                Text('Tap your photo to see how your Circle sees it',
                    style: Theme.of(context).textTheme.labelSmall),
            ])),
            const SizedBox(height: 18),
            TextField(
                controller: intro,
                enabled: !busy,
                maxLength: 160,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                    labelText: t('A line about you (optional)'),
                    hintText: t('e.g. A long walk, a good coffee, no rush.'))),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final interest in interests) CirclePill(interest)
            ]),
            const SizedBox(height: 16),
            const Text(
                'Your Circle sees your first name, photo, interests and this line.',
                style: TextStyle(fontSize: 13, color: Color(0xFF4F5D66))),
            const SizedBox(height: 24),
            _CommitmentCard(
                period: _chosenPeriod,
                checked: commitment,
                enabled: !busy,
                onChanged: (v) => setState(() => commitment = v)),
          ],
          if (error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (saved != null)
            Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(saved!,
                    style: const TextStyle(color: circleTealText))),
          const SizedBox(height: 24),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: busy ? null : () => next(),
                  child: busy
                      ? const Text('Saving your answers…')
                      : widget.focusedEdit
                          ? const Text('Save changes')
                          : step == 3
                              ? const Text('Find my Circle')
                              // "Continue" plus where it leads.
                              : Wrap(
                                  alignment: WrapAlignment.center,
                                  children: [
                                      const Text('Continue'),
                                      Text([
                                        ' to your times',
                                        ' to what you like',
                                        ' to your profile'
                                      ][step]),
                                    ]))),
          const SizedBox(height: 4),
          // A focused edit has one way out that isn't saving: discard. The
          // first run instead offers Back and a way to stop without losing
          // the answers already given.
          if (widget.focusedEdit)
            Center(
                child: TextButton(
                    onPressed: busy ? null : (widget.onCancel ?? widget.onDone),
                    child: const Text('Cancel')))
          else
            // A Wrap, not a Row: at 320px the two labels plus their icons do
            // not fit on one line, and stacking is better than clipping.
            SizedBox(
                width: double.infinity,
                child: Wrap(
                    alignment: step > 0
                        ? WrapAlignment.spaceBetween
                        : WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (step > 0)
                        TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                      step--;
                                      error = null;
                                      saved = null;
                                    }),
                            icon: const Icon(Icons.chevron_left_rounded,
                                size: 20),
                            label: const Text('Back')),
                      TextButton.icon(
                          onPressed: busy ? null : () => next(draft: true),
                          icon: const Icon(Icons.bookmark_border_rounded,
                              size: 18),
                          label: const Text('Save for later'),
                          style: TextButton.styleFrom(
                              foregroundColor:
                                  circleNavy.withValues(alpha: .72))),
                    ])),
        ]),
      ]);

  /// 'evening' when every chosen day uses the same time of day, else null.
  String? get _chosenPeriod {
    final periods = {for (final v in currentSlots.values) ...v};
    return periods.length == 1 ? periods.first : null;
  }

  /// A question's heading: clearly larger than the options under it.
  Widget _label(String value) => Text(value,
      style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w800, color: circleNavy));

  /// Up to five interests from a grouped list. One group is open at a time,
  /// so the long list stays a short page; what is chosen sits on top.
  Widget _interestPicker() {
    final full = interests.length >= circleMaxInterests;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('What are you into?'),
      const SizedBox(height: 4),
      Text(
          full
              ? '${interests.length} of $circleMaxInterests chosen. Remove one to pick another.'
              : 'Pick up to $circleMaxInterests. ${interests.length} chosen.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF66727C))),
      const SizedBox(height: 10),
      if (interests.isNotEmpty) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final value in interests)
            InputChip(
                label: Text(value),
                selected: true,
                showCheckmark: false,
                onDeleted:
                    busy ? null : () => setState(() => interests.remove(value)),
                deleteButtonTooltipMessage: t('Remove'))
        ]),
        const SizedBox(height: 8),
      ],
      for (final group in circleInterestCategories.entries)
        Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
                key: PageStorageKey('interests-${group.key}'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                expandedAlignment: Alignment.centerLeft,
                initiallyExpanded: openInterestGroup == group.key,
                onExpansionChanged: (open) {
                  if (open) openInterestGroup = group.key;
                },
                // A category, quieter than the question above it.
                title: Text(group.key,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E4A63))),
                subtitle: () {
                  final n = group.value.where(interests.contains).length;
                  return n == 0
                      ? null
                      : Text('$n chosen',
                          style: const TextStyle(
                              fontSize: 12, color: circleTealText));
                }(),
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final value in group.value)
                      FilterChip(
                          label: Text(value),
                          selected: interests.contains(value),
                          onSelected:
                              busy || (full && !interests.contains(value))
                                  ? null
                                  : (v) => setState(() => v
                                      ? interests.add(value)
                                      : interests.remove(value)))
                  ])
                ])),
    ]);
  }

  /// Morning, afternoon and evening across six days: the hours once, in
  /// the header; every cell a big ＋ that turns into a ✓. A time we don't
  /// run is a faint dot, so every row lines up (Friday has all three).
  Widget _slotGrid(Map<String, Set<String>> target) {
    const icons = {
      'morning': Icons.wb_twilight_rounded,
      'afternoon': Icons.wb_sunny_outlined,
      'evening': Icons.nights_stay_outlined,
    };
    const names = {
      'morning': 'Morning',
      'afternoon': 'Afternoon',
      'evening': 'Evening',
    };
    Widget header(String part) => Expanded(
            child: Column(children: [
          Icon(icons[part], size: 18, color: circleTeal),
          const SizedBox(height: 2),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(t(names[part]!),
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: circleNavy))),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(circleSlotHours(part),
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF66727C)))),
        ]));
    Widget cell(String day, String part) {
      if (circleSlotGrid[day]?.contains(part) != true) {
        return Expanded(
            child: SizedBox(
                height: 46,
                child: Center(
                    child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                            color: Color(0xFFDCD6CC),
                            shape: BoxShape.circle)))));
      }
      final on = target[day]?.contains(part) == true;
      return Expanded(
          child: Padding(
              padding: const EdgeInsets.all(3),
              child: Semantics(
                  selected: on,
                  button: true,
                  label:
                      '${t(circleDays[circleDayKeys.indexOf(day)])} ${t(part)} ${circleSlotHours(part)}',
                  child: ExcludeSemantics(
                      child: SizedBox(
                          height: 46,
                          key: ValueKey('slot-$day-$part'),
                          child: Material(
                              color: on ? circleTeal : Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                      color: on
                                          ? circleTeal
                                          : const Color(0xFFD5DEDA))),
                              child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: busy
                                      ? null
                                      : () => setState(() {
                                            final set = target.putIfAbsent(
                                                day, () => {});
                                            if (!set.remove(part)) {
                                              set.add(part);
                                            }
                                          }),
                                  // Empty until chosen, then a tick.
                                  child: on
                                      ? const Icon(Icons.check_rounded,
                                          size: 22, color: Colors.white)
                                      : null)))))));
    }

    return Column(children: [
      Row(children: [
        const SizedBox(width: 48),
        for (final part in circlePeriods) header(part),
      ]),
      const SizedBox(height: 6),
      for (final day in circleSlotGrid.keys)
        Row(children: [
          SizedBox(
              width: 48,
              child: Text(
                  t(circleDays[circleDayKeys.indexOf(day)]).substring(0, 3),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: circleNavy))),
          for (final part in circlePeriods) cell(day, part),
        ]),
    ]);
  }

  /// "None of these work?": a note to the organiser, who gets in touch.
  Widget _otherTimesRow() {
    final note = otherTimes.text.trim();
    if (note.isEmpty) {
      return Material(
          color: const Color(0xFFF2EFE8),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: busy ? null : _otherTimesDialog,
              child: const Padding(
                  padding: EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(children: [
                    Icon(Icons.schedule_rounded,
                        size: 20, color: Color(0xFF4F5D66)),
                    SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('None of these work?',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: circleNavy)),
                          Text('Tell the organiser when you’re free',
                              style: TextStyle(
                                  fontSize: 12.5, color: Color(0xFF4F5D66))),
                        ])),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFF66727C)),
                  ]))));
    }
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
            color: const Color(0xFFF2EFE8),
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('For the organiser',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: circleTealText)),
                const SizedBox(height: 2),
                Text('“$note”'),
              ])),
          TextButton(
              onPressed: busy ? null : _otherTimesDialog,
              child: const Text('Change')),
        ]));
  }

  Future<void> _otherTimesDialog() async {
    final box = TextEditingController(text: otherTimes.text);
    final result = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
                scrollable: true,
                title: const Text('When would work for you?'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: box,
                      autofocus: true,
                      maxLength: 300,
                      minLines: 2,
                      maxLines: 4,
                      decoration:
                          InputDecoration(hintText: t('e.g. Monday evenings'))),
                  const Text(
                      'The organiser reads this and gets in touch with you.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF4F5D66))),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, box.text.trim()),
                      child: const Text('Save')),
                ]));
    // After the dialog has finished closing, not while it animates out.
    Future.delayed(const Duration(milliseconds: 500), box.dispose);
    if (result != null && mounted) setState(() => otherTimes.text = result);
  }

  /// Private: for balanced groups, and for when one-to-one coffees happen.
  Widget _genderChoice() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _label('How do you describe yourself?')),
          const CircleInfoButton('Why we ask',
              'Private: never shown to your Circle. We use it only to balance groups, so nobody is the only man or the only woman, and to plan one-to-ones.'),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in circleGenders.entries)
            ChoiceChip(
                label: Text(e.value),
                selected: gender == e.key,
                onSelected:
                    busy ? null : (_) => setState(() => gender = e.key)),
        ]),
      ]);

  /// A few words for "Something else", optional, kept short.
  Widget _otherNote(TextEditingController controller) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
          controller: controller,
          enabled: !busy,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
              labelText: t('In a few words (optional)'), counterText: '')));

  Widget _choices(String label, List<String> options, Set<String> selected,
          {Widget? info}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label.isNotEmpty) ...[
          Row(children: [
            Expanded(child: _label(label)),
            if (info != null) info,
          ]),
          SizedBox(height: info == null ? 12 : 4),
        ],
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final value in options)
            FilterChip(
                label: Text(value),
                selected: selected.contains(value),
                onSelected: busy
                    ? null
                    : (v) => setState(
                        () => v ? selected.add(value) : selected.remove(value)))
        ])
      ]);
}

/// The one thing the whole application is actually asking for: six weeks of
/// one evening. It reads as the promise it is — the six weeks are drawn, the
/// fee sits apart as a fact rather than buried in the small print, and the
/// card confirms itself when ticked instead of staying inert.
class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard(
      {required this.checked,
      required this.enabled,
      required this.onChanged,
      this.period});
  final bool checked, enabled;

  /// 'morning', 'afternoon' or 'evening' when all chosen times match.
  final String? period;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFF8F5EE);
    return Semantics(
      checked: checked,
      label: t('I can make time for one meetup a week for six weeks'),
      child: Material(
        color: checked ? const Color(0xFFE4F0EB) : cream,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: enabled ? () => onChanged(!checked) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: checked ? circleTeal : Colors.transparent, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  for (var i = 0; i < 6; i++) ...[
                    // The connectors shrink on the narrowest phones (320px).
                    if (i > 0)
                      Flexible(
                          child: Container(
                              constraints: const BoxConstraints(maxWidth: 14),
                              height: 1.5,
                              color: circleTeal.withValues(alpha: .28))),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 180 + i * 40),
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: checked
                              ? circleTeal
                              : circleTeal.withValues(alpha: .3)),
                    ),
                  ],
                  const Spacer(),
                  Text('6 weeks',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: circleTealText.withValues(alpha: .9))),
                ]),
                const SizedBox(height: 16),
                Text(
                    period == null
                        ? 'One meetup a week.\nThe same five or six people.'
                        : 'One $period a week.\nThe same five or six people.',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(height: 1.3)),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // A plain icon rather than a Checkbox: the whole card is
                  // the target, and two tap targets in one card invites the
                  // miss where the tick does nothing.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                        checked
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        key: ValueKey(checked),
                        color: checked ? circleTeal : circleNavy,
                        size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text(
                          'I can make time for one meetup a week, for six weeks.',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, height: 1.35))),
                ]),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0x22062B55)),
                const SizedBox(height: 12),
                // What they're agreeing to, at a glance.
                for (final (icon, line) in const [
                  (Icons.place_outlined, 'In the centre of Alkmaar'),
                  (Icons.redeem_outlined, 'Two activities included'),
                  (
                    Icons.euro_rounded,
                    'No payment now: €39 once, when we’ve found your group'
                  ),
                ])
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 19, color: circleTeal),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(line,
                                    style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: circleNavy,
                                        height: 1.35))),
                          ])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How easy the chosen times make it to find a group. A group needs five or
/// six people free at the same moment, so one time a week is hard to match;
/// every extra day or time gives us more people to match with.
class _MatchChance extends StatelessWidget {
  const _MatchChance({required this.slots});
  final int slots;

  @override
  Widget build(BuildContext context) {
    final level = slots <= 1
        ? 0
        : slots <= 3
            ? 1
            : slots <= 5
                ? 2
                : 3;
    final (label, hint, color) = switch (level) {
      0 => (
          'Just one time',
          'One time a week can take a long while. Add another to be matched sooner.',
          circleCoral
        ),
      1 => (
          'A little flexible',
          'One or two more times make it much easier.',
          const Color(0xFFE0A63A)
        ),
      2 => ('Flexible', 'Good: more options, a sooner match.', circleTeal),
      _ => ('Very flexible', 'Plenty of options.', circleTeal),
    };
    return Semantics(
        label: '${t('Your flexibility')}: ${t(label)}',
        child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFF7F5EF),
                borderRadius: BorderRadius.circular(16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: '${t('Your flexibility')}: ',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: circleNavy)),
                TextSpan(
                    text: t(label),
                    style:
                        TextStyle(fontWeight: FontWeight.w800, color: color)),
              ])),
              const SizedBox(height: 8),
              Row(children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 6,
                          decoration: BoxDecoration(
                              color:
                                  i <= level ? color : const Color(0xFFE3E0D8),
                              borderRadius: BorderRadius.circular(3)))),
                ],
              ]),
              const SizedBox(height: 8),
              Text(hint,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF4F5D66))),
            ])));
  }
}
