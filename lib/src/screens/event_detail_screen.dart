import 'package:flutter/material.dart';

import '../core/calendar_service.dart';
import '../core/event_catalog.dart';
import '../core/responsive.dart';
import '../widgets/brand_logo.dart';
import '../widgets/meetup_media.dart';
import '../widgets/motion.dart';
import '../widgets/section_card.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    this.focusedEventId,
    required this.allEvents,
    required this.pastEvents,
    required this.selectedEventIds,
    required this.isUpdatingSelection,
    required this.onSelectEvent,
    required this.onCancelEvent,
  });

  final MeetupEvent? event;
  final String? focusedEventId;
  final List<MeetupEvent> allEvents;
  final List<MeetupEvent> pastEvents;
  final Set<String> selectedEventIds;
  final bool isUpdatingSelection;
  final ValueChanged<MeetupEvent> onSelectEvent;
  final ValueChanged<MeetupEvent> onCancelEvent;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _eventKeys = <String, GlobalKey>{};

  GlobalKey _keyForEvent(String eventId) {
    return _eventKeys.putIfAbsent(eventId, GlobalKey.new);
  }

  @override
  void initState() {
    super.initState();
    _scheduleScrollToFocusedEvent();
  }

  @override
  void didUpdateWidget(covariant EventDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedEventId != widget.focusedEventId ||
        oldWidget.allEvents != widget.allEvents ||
        oldWidget.selectedEventIds != widget.selectedEventIds) {
      _scheduleScrollToFocusedEvent();
    }
  }

  void _scheduleScrollToFocusedEvent() {
    final focusedEventId = widget.focusedEventId;
    if (focusedEventId == null || focusedEventId.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _eventKeys[focusedEventId]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _confirmSpotSelection(
    BuildContext context,
    MeetupEvent meetup,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm your spot?',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  meetup.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF062B55),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${meetup.detailDateLabel} • ${meetup.detailTimeLabel}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF60727A),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Confirm spot'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.center,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Not now'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return result == true;
  }

  Future<bool> _confirmCancellation(
    BuildContext context,
    MeetupEvent meetup,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cancel reservation?',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  meetup.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF062B55),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${meetup.detailDateLabel} • ${meetup.detailTimeLabel}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF60727A),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Keep it'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD85F4D),
                      side: const BorderSide(color: Color(0xFFDDE7E3)),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Cancel reservation'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderedEvents = [...widget.allEvents]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final unreservedOpenEvents = orderedEvents
        .where((openEvent) => !widget.selectedEventIds.contains(openEvent.id))
        .toList();
    final reservedOpenEvents = orderedEvents
        .where((openEvent) => widget.selectedEventIds.contains(openEvent.id))
        .toList();
    final latestPastEvents = [...widget.pastEvents]
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    final visiblePastEvents = latestPastEvents.take(3).toList();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFCF7),
            Color(0xFFEAF7F5),
            Color(0xFFF7ECE4),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final horizontal = responsiveHorizontalPadding(width);
          final maxWidth = responsiveContentMaxWidth(width);

          return SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 140),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MotionReveal(
                      index: 0,
                      child: BrandLockup(
                        logoSize: 42,
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 18),
                    MotionReveal(
                      index: 1,
                      child: Text(
                        'Meetups',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    MotionReveal(
                      index: 2,
                      child: Text(
                        widget.event == null
                            ? 'Choose a meetup when the time works for you.'
                            : 'Your next meetup',
                        style: responsiveDisplayStyle(context),
                      ),
                    ),
                    if (widget.event == null) ...[
                      const SizedBox(height: 12),
                      MotionReveal(
                        index: 3,
                        child: Text(
                          'You can choose up to three meetups on different days.',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (widget.event != null) ...[
                      MotionReveal(
                          index: 4,
                          child: _CurrentMeetupHero(event: widget.event!)),
                      const SizedBox(height: 18),
                      SectionCard(
                        motionIndex: 5,
                        highlight: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('At a glance',
                                style: theme.textTheme.titleLarge),
                            const SizedBox(height: 16),
                            _DetailRow(
                              icon: Icons.event_outlined,
                              title: 'Date',
                              body:
                                  '${widget.event!.detailDateLabel} • ${widget.event!.detailTimeLabel}',
                            ),
                            const SizedBox(height: 14),
                            _DetailRow(
                              icon: Icons.location_on_outlined,
                              title: 'Area',
                              body:
                                  '${widget.event!.areaLabel}, ${widget.event!.city}',
                            ),
                            const SizedBox(height: 14),
                            _DetailRow(
                              icon: Icons.groups_2_outlined,
                              title: 'Your spot',
                              body: widget.event!.spotsLeft > 0
                                  ? 'Confirmed. ${widget.event!.spotsLeft} spots left'
                                  : 'Confirmed. This meetup is full.',
                            ),
                            const SizedBox(height: 14),
                            _DetailRow(
                              icon: Icons.translate_outlined,
                              title: 'Languages',
                              body: widget.event!.languages.join(' • '),
                            ),
                            const SizedBox(height: 16),
                            SeatMeter(
                              filled: widget.event!.seatsFilled,
                              total: widget.event!.seatsTotal,
                              showLabel: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SectionCard(
                        motionIndex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Before the meetup',
                                style: theme.textTheme.titleLarge),
                            const SizedBox(height: 16),
                            const _ExpectationLine(
                              title: 'Address',
                              body:
                                  'Shared 24 hours before - you will get a notification.',
                            ),
                            const SizedBox(height: 12),
                            _ExpectationLine(
                              title: 'The vibe',
                              body: 'Low pressure. Casual. Come as you are.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, innerConstraints) {
                          final calendarButton = ElevatedButton.icon(
                            onPressed: () async {
                              final added =
                                  await addMeetupToCalendar(widget.event!);
                              if (!context.mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    added
                                        ? 'Calendar opened for ${widget.event!.title}.'
                                        : 'We could not open your calendar.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: const Text('Add to calendar'),
                          );

                          return SizedBox(
                            width: double.infinity,
                            child: calendarButton,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: widget.isUpdatingSelection
                              ? null
                              : () async {
                                  final confirmed = await _confirmCancellation(
                                    context,
                                    widget.event!,
                                  );
                                  if (!context.mounted || !confirmed) return;
                                  widget.onCancelEvent(widget.event!);
                                },
                          icon: const Icon(Icons.event_busy_outlined),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD85F4D),
                          ),
                          label: Text(
                            widget.isUpdatingSelection
                                ? 'Updating...'
                                : 'Cancel reservation',
                          ),
                        ),
                      ),
                    ] else ...[
                      const MotionReveal(
                        index: 4,
                        child: _EmptySelectionCard(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SectionCard(
                      motionIndex: widget.event == null ? 5 : 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Available meetups',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            'Add another meetup on a different day. All meetups are small groups, and phones stay in your pocket.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          if (orderedEvents.isEmpty)
                            const _EmptyMeetupsCatalog()
                          else ...[
                            for (final otherEvent in unreservedOpenEvents) ...[
                              _ExploreMeetupCard(
                                event: otherEvent,
                                key: _keyForEvent(otherEvent.id),
                                isUpdatingSelection: widget.isUpdatingSelection,
                                onSelect: () async {
                                  final currentEvents =
                                      selectedMeetupEventsFromIds(
                                    widget.selectedEventIds.toList(),
                                    availableEvents: widget.allEvents,
                                  );
                                  final conflictMessage =
                                      reservationConflictMessage(
                                    currentEvents: currentEvents,
                                    candidate: otherEvent,
                                  );
                                  if (conflictMessage != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(conflictMessage),
                                      ),
                                    );
                                    return;
                                  }
                                  final confirmed = await _confirmSpotSelection(
                                    context,
                                    otherEvent,
                                  );
                                  if (!context.mounted || !confirmed) return;
                                  widget.onSelectEvent(otherEvent);
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ],
                      ),
                    ),
                    if (reservedOpenEvents.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      SectionCard(
                        motionIndex: widget.event == null ? 6 : 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reservedOpenEvents.length == 1
                                  ? 'Your upcoming meetup'
                                  : 'Your upcoming meetups',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            for (final reservedEvent in reservedOpenEvents) ...[
                              _ReservedOpenMeetupRow(
                                key: _keyForEvent(reservedEvent.id),
                                event: reservedEvent,
                                isUpdatingSelection: widget.isUpdatingSelection,
                                onCancel: () async {
                                  final confirmed = await _confirmCancellation(
                                    context,
                                    reservedEvent,
                                  );
                                  if (!context.mounted || !confirmed) return;
                                  widget.onCancelEvent(reservedEvent);
                                },
                                onAddToCalendar: () async {
                                  final added =
                                      await addMeetupToCalendar(reservedEvent);
                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        added
                                            ? 'Calendar opened for ${reservedEvent.title}.'
                                            : 'We could not open your calendar.',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (reservedEvent != reservedOpenEvents.last)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (visiblePastEvents.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      SectionCard(
                        motionIndex: widget.event == null ? 7 : 9,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Past meetups',
                                style: theme.textTheme.titleLarge),
                            const SizedBox(height: 16),
                            for (final pastEvent in visiblePastEvents) ...[
                              _PastMeetupCard(event: pastEvent),
                              if (pastEvent != visiblePastEvents.last)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CurrentMeetupHero extends StatelessWidget {
  const _CurrentMeetupHero({required this.event});

  final MeetupEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF062B55),
            Color(0xFF138B8A),
            Color(0xFFFF7759),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26150806),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MeetupArtwork(
            event: event,
            height: 220,
            radius: 26,
            secondaryCaption: event.areaLabel,
            caption: event.activityLabel,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              const _HeroTag(label: 'Address shared 24 hours before'),
              const _HeroTag(label: 'Phones stay in your pocket'),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            event.title,
            style: responsiveHeadlineStyle(
              context,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            event.subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFEAF7F5),
            ),
          ),
          const SizedBox(height: 20),
          _HeroLine(
            icon: Icons.schedule_outlined,
            label: '${event.detailDateLabel} • ${event.detailTimeLabel}',
          ),
          const SizedBox(height: 12),
          _HeroLine(
            icon: Icons.local_activity_outlined,
            label: '${event.activityLabel} • ${event.vibeLabel}',
          ),
        ],
      ),
    );
  }
}

class _EmptySelectionCard extends StatelessWidget {
  const _EmptySelectionCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF062B55),
            Color(0xFF138B8A),
            Color(0xFFFF7759),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26150806),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandLockup(logoSize: 52),
          const SizedBox(height: 18),
          const MeetupArtwork(
            height: 220,
            radius: 26,
            secondaryCaption: 'VriendTime',
            caption: 'Available meetups',
            assetName: GeneratedImageAssets.onboardingHero,
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroTag(label: 'No reservation yet'),
              _HeroTag(label: 'Small-group meetups'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Coffee, lunch, and dinner meetups.',
            style: responsiveHeadlineStyle(
              context,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Choose the one that works for you.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFEAF7F5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMeetupsCatalog extends StatelessWidget {
  const _EmptyMeetupsCatalog();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Text(
        'No available meetups yet. New meetups will appear here.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ExploreMeetupCard extends StatelessWidget {
  const _ExploreMeetupCard({
    super.key,
    required this.event,
    required this.isUpdatingSelection,
    required this.onSelect,
  });

  final MeetupEvent event;
  final bool isUpdatingSelection;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSelect = !isUpdatingSelection && !event.isFull;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: canSelect ? onSelect : null,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFDDE7E3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: double.infinity,
                  height: 144,
                  child: MeetupArtwork(
                    event: event,
                    height: 144,
                    radius: 18,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Badge(label: event.timeOfDayLabel, dark: true),
                  _Badge(label: event.availabilityLabel),
                ],
              ),
              const SizedBox(height: 14),
              Text(event.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(event.subtitle, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(
                      label:
                          '${event.detailDateLabel} • ${event.detailTimeLabel}'),
                  _MetaChip(label: '${event.areaLabel} • ${event.city}'),
                  _MetaChip(
                      label: '${event.activityLabel} • ${event.vibeLabel}'),
                ],
              ),
              const SizedBox(height: 14),
              SeatMeter(
                filled: event.seatsFilled,
                total: event.seatsTotal,
                showLabel: false,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canSelect ? onSelect : null,
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text(
                    isUpdatingSelection ? 'Updating...' : 'Choose this meetup',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservedOpenMeetupRow extends StatelessWidget {
  const _ReservedOpenMeetupRow({
    super.key,
    required this.event,
    required this.isUpdatingSelection,
    required this.onCancel,
    required this.onAddToCalendar,
  });

  final MeetupEvent event;
  final bool isUpdatingSelection;
  final Future<void> Function() onCancel;
  final VoidCallback onAddToCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFB9E3DC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: MeetupArtwork(
              event: event,
              height: 86,
              radius: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const _Badge(label: 'Your spot is confirmed'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(event.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(event.subtitle, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(
                        label: '${event.activityLabel} • ${event.areaLabel}'),
                    _MetaChip(label: event.detailDateLabel),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 360;
                    final calendarButton = OutlinedButton.icon(
                      onPressed: isUpdatingSelection ? null : onAddToCalendar,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Add to calendar'),
                    );
                    final cancelButton = OutlinedButton.icon(
                      onPressed: isUpdatingSelection ? null : () => onCancel(),
                      icon: const Icon(Icons.event_busy_outlined),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD85F4D),
                      ),
                      label: Text(isUpdatingSelection
                          ? 'Updating...'
                          : 'Cancel reservation'),
                    );

                    if (stacked) {
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: calendarButton,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: cancelButton,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: calendarButton),
                        const SizedBox(width: 8),
                        Expanded(child: cancelButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PastMeetupCard extends StatelessWidget {
  const _PastMeetupCard({required this.event});

  final MeetupEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: MeetupArtwork(
              event: event,
              height: 86,
              radius: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(label: event.detailDateLabel),
                    _MetaChip(label: '${event.activityLabel} • ${event.city}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F4F2),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: const Color(0xFF138B8A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpectationLine extends StatelessWidget {
  const _ExpectationLine({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: Color(0xFFFF7759),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$title: ',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                      ),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth = responsiveChipMaxWidth(MediaQuery.sizeOf(context).width);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
              ),
        ),
      ),
    );
  }
}

class _HeroLine extends StatelessWidget {
  const _HeroLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFEAF7F5),
                ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    this.dark = false,
  });

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF062B55) : const Color(0xFFE7F4F2);
    final maxWidth = responsiveChipMaxWidth(MediaQuery.sizeOf(context).width);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: dark ? Colors.white : const Color(0xFF138B8A),
              ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth = responsiveChipMaxWidth(MediaQuery.sizeOf(context).width);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7F5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFDDE7E3)),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
