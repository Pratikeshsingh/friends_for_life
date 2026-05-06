import 'package:flutter/material.dart';

import '../core/calendar_service.dart';
import '../core/event_catalog.dart';
import '../core/responsive.dart';
import '../widgets/brand_logo.dart';
import '../widgets/meetup_media.dart';
import '../widgets/motion.dart';
import '../widgets/section_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenEvent,
    this.userEmail,
    this.firstName,
    required this.selectedEvent,
    required this.selectedEvents,
    required this.availableEvents,
  });

  final ValueChanged<MeetupEvent?> onOpenEvent;
  final String? userEmail;
  final String? firstName;
  final MeetupEvent? selectedEvent;
  final List<MeetupEvent> selectedEvents;
  final List<MeetupEvent> availableEvents;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = _timeOfDayGreeting();
    final greetingName =
        (widget.firstName != null && widget.firstName!.trim().isNotEmpty)
            ? widget.firstName!.trim()
            : (widget.userEmail?.split('@').first ?? 'there');
    final browseEvents = [...widget.availableEvents]
      ..removeWhere(
          (event) => widget.selectedEvents.any((saved) => saved.id == event.id))
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

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
                        '$greeting, $greetingName',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MotionReveal(
                      index: 2,
                      child: Text(
                        widget.selectedEvent == null
                            ? 'Find a small meetup\nnear you.'
                            : 'Your next meetup',
                        style: responsiveDisplayStyle(context),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (widget.selectedEvent != null)
                      _NextMeetupReminder(
                        event: widget.selectedEvent!,
                        onOpenEvent: () => widget.onOpenEvent(null),
                        motionIndex: 3,
                      )
                    else
                      _FindMeetupPrompt(
                        onOpenEvent: () => widget.onOpenEvent(null),
                        motionIndex: 3,
                      ),
                    if (browseEvents.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      SectionCard(
                        motionIndex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.selectedEvent == null
                                  ? 'Coming up in Alkmaar'
                                  : 'Also coming up',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            for (final event in browseEvents) ...[
                              _SavedMeetupRow(
                                event: event,
                                onTap: () => widget.onOpenEvent(event),
                              ),
                              const SizedBox(height: 10),
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

  String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 18) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }
}

class _NextMeetupReminder extends StatelessWidget {
  const _NextMeetupReminder({
    required this.event,
    required this.onOpenEvent,
    required this.motionIndex,
  });

  final MeetupEvent event;
  final VoidCallback onOpenEvent;
  final int motionIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MotionReveal(
      index: motionIndex,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
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
              blurRadius: 26,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: _InsightChip(
                label: 'Your spot is confirmed',
                dark: true,
                onGradient: true,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              event.title,
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              event.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFEAF7F5),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InsightChip(
                  label: '${event.detailDateLabel} • ${event.detailTimeLabel}',
                  onGradient: true,
                ),
                _InsightChip(
                  label: '${event.areaLabel} • ${event.city}',
                  onGradient: true,
                ),
                _InsightChip(label: event.groupSizeLabel, onGradient: true),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = isCompactWidth(constraints.maxWidth);
                final viewButton = ElevatedButton(
                  onPressed: onOpenEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF062B55),
                  ),
                  child: const Text('View meetup'),
                );
                final calendarButton = OutlinedButton.icon(
                  onPressed: () async {
                    final added = await addMeetupToCalendar(event);
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          added
                              ? 'Calendar opened for ${event.title}.'
                              : 'We could not open your calendar.',
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Add to calendar'),
                );

                if (stacked) {
                  return Column(
                    children: [
                      SizedBox(width: double.infinity, child: viewButton),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: calendarButton),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: viewButton),
                    const SizedBox(width: 12),
                    Expanded(child: calendarButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FindMeetupPrompt extends StatelessWidget {
  const _FindMeetupPrompt({
    required this.onOpenEvent,
    required this.motionIndex,
  });

  final VoidCallback onOpenEvent;
  final int motionIndex;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      motionIndex: motionIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a coffee, lunch, or dinner when you are ready.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenEvent,
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Find a meetup'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedMeetupRow extends StatelessWidget {
  const _SavedMeetupRow({
    required this.event,
    required this.onTap,
  });

  final MeetupEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDDE7E3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 54,
                height: 54,
                child: MeetupArtwork(
                  event: event,
                  height: 54,
                  radius: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(event.dateLabel,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  const _InsightChip({
    required this.label,
    this.dark = false,
    this.onGradient = false,
  });

  final String label;
  final bool dark;
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dark
            ? (onGradient
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xFF062B55))
            : (onGradient
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0xFFEAF7F5)),
        borderRadius: BorderRadius.circular(999),
        border: onGradient
            ? Border.all(color: Colors.white.withValues(alpha: 0.16))
            : dark
                ? null
                : Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: onGradient
                  ? Colors.white
                  : dark
                      ? Colors.white
                      : const Color(0xFF4F6671),
            ),
      ),
    );
  }
}
