import 'package:flutter/material.dart';
import 'circle_repository.dart';
import 'circle_preferences.dart';
import 'circle_widgets.dart';

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
      this.initialStep = 0,
      this.focusedEdit = false});
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

  /// Which step to open on, so "edit my availability" from the profile
  /// doesn't drop people back on the name and date-of-birth step.
  final int initialStep;

  /// Editing one answer, not filling in an application. The step indicator,
  /// the "2 of 4" counter and the walk to the end all belong to the first
  /// run; someone changing their availability wants to change it and leave.
  final bool focusedEdit;
  @override
  State<CircleApplication> createState() => _CircleApplicationState();
}

class _CircleApplicationState extends State<CircleApplication> {
  late final TextEditingController name, intro, phone, address;
  late Set<String> languages, interests, activities, goals, lifeContext;
  late Map<String, Set<String>> slots;
  final selectedDays = <String>{};
  final commonPeriods = <String>{};
  DateTime? birthday;
  String? photoPath, photoUrl;
  int style = 1, step = 0;
  bool commitment = false, customTimes = false, saving = false;
  String? error, saved;
  bool get busy => widget.busy || saving;
  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    name = TextEditingController(text: d['name'] as String? ?? '');
    intro = TextEditingController(text: d['intro'] as String? ?? '');
    phone = TextEditingController(text: d['phone'] as String? ?? '');
    address = TextEditingController(text: d['address'] as String? ?? '');
    birthday = DateTime.tryParse(d['date_of_birth']?.toString() ?? '');
    photoPath = d['photo_path'] as String?;
    photoUrl = d['photo_url'] as String?;
    languages = strings(d['languages']).where(circleLanguages.contains).toSet();
    interests = strings(d['interests']).toSet();
    activities = strings(d['activities']).toSet();
    goals = strings(d['goals']).where(circleGoals.contains).toSet();
    lifeContext =
        strings(d['life_context']).where(circleContexts.contains).toSet();
    slots = circleSlots(d);
    selectedDays.addAll(slots.keys);
    if (slots.isNotEmpty) {
      commonPeriods.addAll(slots.values.first);
      customTimes = slots.values.any((v) =>
          v.length != commonPeriods.length || !v.containsAll(commonPeriods));
    }
    style = (((d['energy'] as num?)?.toDouble() ?? 2) / 2).round().clamp(0, 2);
    commitment = d['commitment'] == true;
    step = widget.initialStep.clamp(0, 3);
  }

  @override
  void dispose() {
    name.dispose();
    intro.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Map<String, Set<String>> get currentSlots => {
        for (final day in circleDayKeys)
          if (selectedDays.contains(day))
            day: customTimes ? (slots[day] ?? {}) : {...commonPeriods}
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
        'interests': interests.toList(),
        'activities': activities.toList(),
        'energy': style * 2,
        'goals': goals.toList(),
        'life_context': lifeContext.toList(),
        'intro': intro.text.trim(),
        'commitment': commitment,
        'phone': normalisePhone(phone.text),
        'address': address.text.trim(),
      };
  String? validate() {
    if (step == 0) {
      if (name.text.trim().isEmpty) return 'Add your first name.';
      final age = circleAge(data['date_of_birth'] as String?);
      if (age == null || age < 18 || age > 120) {
        return 'Add your date of birth. Circles are for adults 18+.';
      }
      if (phone.text.trim().isEmpty) {
        return 'Add your WhatsApp number so we can send your payment link and meetup updates.';
      }
      if (!isValidPhone(phone.text)) {
        return 'Check your WhatsApp number, for example 06 12345678.';
      }
      if (languages.isEmpty) return 'Choose English, Dutch, or both.';
    }
    if (step == 1 &&
        (selectedDays.isEmpty || currentSlots.values.any((v) => v.isEmpty))) {
      return 'Choose at least one day and a time for each selected day.';
    }
    if (step == 2 &&
        (interests.isEmpty || activities.isEmpty || goals.isEmpty)) {
      return 'Pick an interest, an activity, and what you’re looking for.';
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

  Future<void> chooseBirthday() async {
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        helpText: 'Your date of birth',
        // Open on the calendar, starting at the year list — typing a
        // birthday into a text field invites nonsense like "123456" and
        // means nobody sees a calendar when they tap the field.
        initialDatePickerMode: DatePickerMode.year,
        initialEntryMode: DatePickerEntryMode.calendar,
        initialDate: birthday ?? DateTime(now.year - 30, 1, 1),
        firstDate: DateTime(now.year - 120, now.month, now.day),
        lastDate: now,
        fieldHintText: MaterialLocalizations.of(context).dateHelpText);
    if (date != null && mounted) setState(() => birthday = date);
  }

  /// A rectangular upload gets cropped to a circle everywhere it appears,
  /// so show it that way rather than as the original rectangle.
  Future<void> _previewPhoto() async {
    await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
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
              'A few basics. Your birthday, number and address stay private.',
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
                decoration: const InputDecoration(
                    labelText: 'First name', counterText: '')),
            const SizedBox(height: 20),
            OutlinedButton.icon(
                onPressed: busy ? null : chooseBirthday,
                icon: const Icon(Icons.cake_outlined),
                label: Text(birthday == null
                    ? 'Date of birth'
                    : '${birthday!.day} ${MaterialLocalizations.of(context).formatMonthYear(birthday!)}')),
            const SizedBox(height: 20),
            TextField(
                controller: phone,
                enabled: !busy,
                maxLength: 20,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                    labelText: 'WhatsApp number',
                    hintText: '06 12345678',
                    helperText:
                        'We send your payment link and meetup updates here.',
                    helperMaxLines: 2,
                    counterText: '')),
            const SizedBox(height: 16),
            TextField(
                controller: address,
                enabled: !busy,
                maxLength: 200,
                keyboardType: TextInputType.streetAddress,
                autofillHints: const [AutofillHints.fullStreetAddress],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'Home address (optional)',
                    hintText: 'Street and number, or just your postcode',
                    helperText:
                        'Only used to plan meetups near you. Never shown to your Circle.',
                    helperMaxLines: 2,
                    counterText: '')),
            if (address.text.trim().isEmpty) ...[
              const SizedBox(height: 8),
              const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Color(0xFF66727C)),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'Without an address, your meetups may be a little further from home, because we can’t plan around where you live.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF66727C)))),
                  ]),
            ],
            const SizedBox(height: 20),
            const CirclePill('Alkmaar & nearby', icon: Icons.place_outlined),
            const SizedBox(height: 24),
            _choices('Let’s talk in…', circleLanguages, languages),
            const SizedBox(height: 10),
            const Text('Our first Circles run in English and Dutch.',
                style: TextStyle(fontSize: 12)),
          ],
          if (step == 1) ...[
            _label('Which days work?'),
            const SizedBox(height: 12),
            Row(children: [for (var i = 0; i < 7; i++) _dayButton(i)]),
            Wrap(spacing: 8, children: [
              TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(
                          () => selectedDays.addAll(circleDayKeys.take(5))),
                  child: const Text('Weekdays')),
              TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(
                          () => selectedDays.addAll(circleDayKeys.skip(5))),
                  child: const Text('Weekends')),
              TextButton(
                  onPressed:
                      busy ? null : () => setState(() => selectedDays.clear()),
                  child: const Text('Clear'))
            ]),
            const SizedBox(height: 16),
            if (!customTimes) ...[
              _label('What time of day?'),
              const SizedBox(height: 12),
              _periodPicker(commonPeriods),
              const SizedBox(height: 8),
              const Text('Applies to each selected day · Netherlands time',
                  style: TextStyle(fontSize: 12))
            ] else
              for (var i = 0; i < 7; i++)
                if (selectedDays.contains(circleDayKeys[i]))
                  Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label(circleDays[i]),
                            const SizedBox(height: 8),
                            _periodPicker(slots.putIfAbsent(
                                circleDayKeys[i], () => {...commonPeriods})),
                          ])),
            // Both directions. Switching to per-day times used to be a
            // one-way door: the button that set it lived inside the branch
            // it hid, so there was no way back short of reloading.
            TextButton.icon(
                onPressed: busy
                    ? null
                    : () => setState(() {
                          if (customTimes) {
                            // Keep the widest set anyone picked, so coming
                            // back never silently drops a time.
                            final union = <String>{
                              for (final day in selectedDays) ...?slots[day],
                            };
                            commonPeriods
                              ..clear()
                              ..addAll(
                                  union.isEmpty ? const {'evening'} : union);
                            customTimes = false;
                          } else {
                            slots = currentSlots;
                            customTimes = true;
                          }
                        }),
                icon: Icon(
                    customTimes ? Icons.link_rounded : Icons.call_split_rounded,
                    size: 18),
                label: Text(customTimes
                    ? 'Use the same times every day'
                    : 'Different times on different days')),
            const SizedBox(height: 16),
            const CirclePill('You approve the exact schedule before joining',
                icon: Icons.check_circle_outline),
          ],
          if (step == 2) ...[
            // Interests, not formats. Coffee and walking used to live here
            // too, which made this question a near-duplicate of the plan
            // question below it.
            _choices(
                'What are you into?',
                const [
                  'Food',
                  'Books',
                  'Music',
                  'Art',
                  'Films',
                  'Games',
                  'Cooking',
                  'Cycling',
                  'Nature',
                  'Sport',
                  'Travel',
                  'Photography'
                ],
                interests),
            const SizedBox(height: 24),
            _choices(
                'A plan you’d say yes to',
                const [
                  'Coffee & conversation',
                  'Dinner',
                  'Bowling',
                  'A walk',
                  'Board games',
                  'A museum',
                  'Something new'
                ],
                activities),
            const SizedBox(height: 24),
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
            const SizedBox(height: 20),
            _choices('I’d love to find…', circleGoals, goals),
            const SizedBox(height: 10),
            const Text('Helps us match shared expectations.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 20),
            // This was hidden behind a collapsed "(optional)" disclosure,
            // which is why almost nobody filled it in — and it is one of the
            // better matching signals we have. People who arrived in the
            // city the same way tend to have the same week.
            _choices('What brings you here?', circleContexts, lifeContext),
            const SizedBox(height: 10),
            const Text(
                'Private. Never shown to your Circle — we use it to put you with people in a similar moment.',
                style: TextStyle(fontSize: 12)),
          ],
          if (step == 3) ...[
            Center(
                child: Column(children: [
              Semantics(
                  button: photoUrl != null,
                  label: photoUrl == null
                      ? null
                      : 'See how your photo looks to your Circle',
                  child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: photoUrl == null ? null : _previewPhoto,
                      child: CircleMemberAvatar(capitaliseName(name.text),
                          radius: 48,
                          photoUrl: photoUrl,
                          photoPath: photoPath))),
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
                decoration: const InputDecoration(
                    labelText: 'My kind of afternoon… (optional)',
                    hintText: 'A long walk, a good coffee, no rush.')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final interest in interests) CirclePill(interest)
            ]),
            const SizedBox(height: 16),
            const Text(
                'Shared with your Circle: name, photo, interests and introduction. Photos help recognition, not identity verification.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 24),
            _CommitmentCard(
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
                child: Text(saved!, style: const TextStyle(color: circleTeal))),
          const SizedBox(height: 24),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: busy ? null : () => next(),
                  child: Text(busy
                      ? 'Saving your answers…'
                      : widget.focusedEdit
                          ? 'Save changes'
                          : step == 3
                              ? 'Find my Circle'
                              : 'Continue'))),
          const SizedBox(height: 4),
          // A focused edit has one way out that isn't saving: discard. The
          // first run instead offers Back and a way to stop without losing
          // the answers already given.
          if (widget.focusedEdit)
            Center(
                child: TextButton(
                    onPressed: busy ? null : widget.onDone,
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
  Widget _dayButton(int i) {
    final day = circleDayKeys[i];
    final selected = selectedDays.contains(day);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
          label: circleDays[i],
          selected: selected,
          child: SizedBox(
            height: 44,
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                backgroundColor:
                    selected ? circleTeal : const Color(0xFFF7F5EF),
                foregroundColor: selected ? Colors.white : circleNavy,
                shape: const CircleBorder(),
              ),
              onPressed: busy
                  ? null
                  : () => setState(() {
                        if (selected) {
                          selectedDays.remove(day);
                        } else {
                          selectedDays.add(day);
                          slots.putIfAbsent(day, () => {...commonPeriods});
                        }
                      }),
              child: Text(circleDays[i].substring(0, 3),
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String value) => Text(value,
      style: const TextStyle(fontWeight: FontWeight.w800, color: circleNavy));
  Widget _choices(String label, List<String> options, Set<String> selected) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label.isNotEmpty) ...[_label(label), const SizedBox(height: 12)],
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
  Widget _periodPicker(Set<String> selected) =>
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < 3; i++)
          FilterChip(
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              avatar: Icon(
                  [
                    Icons.wb_sunny_outlined,
                    Icons.light_mode_outlined,
                    Icons.nights_stay_outlined
                  ][i],
                  size: 20),
              label: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(['Morning', 'Afternoon', 'Evening'][i],
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(circlePeriodTimes[i],
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500))
                  ]),
              selected: selected.contains(circlePeriods[i]),
              onSelected: busy
                  ? null
                  : (v) => setState(() => v
                      ? selected.add(circlePeriods[i])
                      : selected.remove(circlePeriods[i])))
      ]);
}

/// The one thing the whole application is actually asking for: six weeks of
/// one evening. It reads as the promise it is — the six weeks are drawn, the
/// fee sits apart as a fact rather than buried in the small print, and the
/// card confirms itself when ticked instead of staying inert.
class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard(
      {required this.checked, required this.enabled, required this.onChanged});
  final bool checked, enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const peach = Color(0xFFF8DDCD);
    return Semantics(
      checked: checked,
      label: 'I can make time for one meetup a week for six weeks',
      child: Material(
        color: checked ? const Color(0xFFE4F0EB) : peach,
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
                    if (i > 0)
                      Container(
                          width: 14,
                          height: 1.5,
                          color: circleTeal.withValues(alpha: .28)),
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
                          color: circleTeal.withValues(alpha: .9))),
                ]),
                const SizedBox(height: 16),
                Text('One evening a week.\nThe same six people.',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(height: 1.25)),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // A plain icon rather than a Checkbox: the whole card is
                  // the target, and two tap targets in one card invites the
                  // miss where the tick does nothing.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                        checked
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
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
                const Text(
                    '€19 once, when you accept a Circle. Food, drinks and activities are paid at the venue.',
                    style: TextStyle(fontSize: 12, height: 1.45)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
