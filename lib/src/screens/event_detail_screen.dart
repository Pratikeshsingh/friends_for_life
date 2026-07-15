import 'package:flutter/material.dart';

import '../core/calendar_service.dart';
import '../core/event_catalog.dart';
import '../core/responsive.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/continuous_immersive_scene.dart';
import '../widgets/meetup_explorer_tile.dart';
import '../widgets/meetup_media.dart';
import '../widgets/motion.dart';
import '../widgets/section_card.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    this.focusedEventId,
    required this.scrollToTopVersion,
    required this.allEvents,
    required this.pastEvents,
    required this.selectedEventIds,
    this.revealedLocationsByEventId = const <String, String>{},
    required this.isUpdatingSelection,
    this.hasEventLoadError = false,
    this.onRetryEvents,
    required this.onSelectEvent,
    required this.onCancelEvent,
    required this.unreadNotificationCount,
    required this.onOpenNotifications,
    required this.onFocusHandled,
  });

  final MeetupEvent? event;
  final String? focusedEventId;
  final int scrollToTopVersion;
  final List<MeetupEvent> allEvents;
  final List<MeetupEvent> pastEvents;
  final Set<String> selectedEventIds;
  final Map<String, String> revealedLocationsByEventId;
  final bool isUpdatingSelection;
  final bool hasEventLoadError;
  final VoidCallback? onRetryEvents;
  final ValueChanged<MeetupEvent> onSelectEvent;
  final ValueChanged<MeetupEvent> onCancelEvent;
  final int unreadNotificationCount;
  final VoidCallback onOpenNotifications;
  final VoidCallback onFocusHandled;

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
    if (oldWidget.scrollToTopVersion != widget.scrollToTopVersion) {
      _scrollToTop();
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
      widget.onFocusHandled();
    });
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _hasRevealedLocation(MeetupEvent event) {
    return _hasRevealedLocationForEvent(
      event,
      widget.revealedLocationsByEventId,
    );
  }

  String _resolvedLocationLabel(MeetupEvent event) {
    return _resolvedLocationLabelForEvent(
      event,
      widget.revealedLocationsByEventId,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
                  'Cancel your reservation?',
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
                const SizedBox(height: 12),
                Text(
                  'Your seat will become available for someone else.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Keep my seat'),
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
                    child: const Text('Cancel my reservation'),
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

  Future<void> _openMeetupPreviewSheet({
    required BuildContext context,
    required MeetupEvent event,
    required bool isUpdatingSelection,
    required Future<void> Function() onChoose,
  }) async {
    final canChoose = !isUpdatingSelection && event.isOpenForReservation;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _MeetupPreviewSheet(
          event: event,
          revealedLocationLabel: _resolvedLocationLabel(event),
          hasRevealedLocation: _hasRevealedLocation(event),
          isUpdatingSelection: isUpdatingSelection,
          onChoose: canChoose ? onChoose : null,
        );
      },
    );
  }

  Future<void> _openReservedMeetupSheet({
    required BuildContext context,
    required MeetupEvent event,
  }) async {
    final canCancel = canCancelMeetupReservation(event);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ReservedMeetupSheet(
          event: event,
          revealedLocationLabel: _resolvedLocationLabel(event),
          hasRevealedLocation: _hasRevealedLocation(event),
          isUpdatingSelection: widget.isUpdatingSelection,
          onAddToCalendar: () async {
            final added = await addMeetupToCalendar(event);
            if (!context.mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  added
                      ? 'Calendar opened for ${event.title}.'
                      : "We couldn't open your calendar. Add this meetup manually from your calendar app.",
                ),
              ),
            );
          },
          onCancel: widget.isUpdatingSelection || !canCancel
              ? null
              : () async {
                  final confirmed = await _confirmCancellation(context, event);
                  if (!context.mounted || !confirmed) return;
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                  widget.onCancelEvent(event);
                },
        );
      },
    );
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

    return ContinuousImmersiveScene(
      assetName: GeneratedImageAssets.meetupsContinuousScene,
      semanticLabel: 'People meeting beside a welcoming canal-side cafe',
      alignment: Alignment.topRight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final horizontal = responsiveHorizontalPadding(width);
          final maxWidth = responsiveContentMaxWidth(width);
          final wideMeetups = isWideContentWidth(width);

          return ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              0,
              MediaQuery.paddingOf(context).top + 12,
              0,
              112,
            ),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShellHeader(
                          unreadCount: widget.unreadNotificationCount,
                          onOpenNotifications: widget.onOpenNotifications,
                          logoSize: 42,
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(height: 24),
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
                                ? 'Find a meetup that fits your week'
                                : 'Your next meetup',
                            style: responsiveDisplayStyle(context),
                          ),
                        ),
                        if (widget.event == null) ...[
                          const SizedBox(height: 12),
                          MotionReveal(
                            index: 3,
                            child: Text(
                              'Pick up to three meetups—one on each day.',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        if (widget.event != null) ...[
                          if (wideMeetups)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: MotionReveal(
                                    index: 4,
                                    child: _CurrentMeetupHero(
                                      event: widget.event!,
                                      revealedLocationLabel:
                                          _resolvedLocationLabel(widget.event!),
                                      hasRevealedLocation:
                                          _hasRevealedLocation(widget.event!),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  flex: 5,
                                  child: _CurrentMeetupAtGlanceCard(
                                    motionIndex: 5,
                                    event: widget.event!,
                                    revealedLocationLabel:
                                        _resolvedLocationLabel(widget.event!),
                                    hasRevealedLocation:
                                        _hasRevealedLocation(widget.event!),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            MotionReveal(
                              index: 4,
                              child: _CurrentMeetupHero(
                                event: widget.event!,
                                revealedLocationLabel:
                                    _resolvedLocationLabel(widget.event!),
                                hasRevealedLocation:
                                    _hasRevealedLocation(widget.event!),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _CurrentMeetupAtGlanceCard(
                              motionIndex: 5,
                              event: widget.event!,
                              revealedLocationLabel:
                                  _resolvedLocationLabel(widget.event!),
                              hasRevealedLocation:
                                  _hasRevealedLocation(widget.event!),
                            ),
                          ],
                        ],
                        const SizedBox(height: 18),
                        SectionCard(
                          motionIndex: widget.event == null ? 5 : 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.event == null
                                    ? 'Available meetups'
                                    : 'More meetups',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.event == null
                                    ? 'Choose a time that feels right. You can reserve one meetup per day.'
                                    : 'Want to meet on another day? You can reserve one meetup per day.',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              if (unreservedOpenEvents.isEmpty)
                                _EmptyMeetupsCatalog(
                                  allCurrentMeetupsReserved:
                                      orderedEvents.isNotEmpty,
                                  loadFailed: widget.hasEventLoadError,
                                  onRetry: widget.onRetryEvents,
                                )
                              else ...[
                                for (final otherEvent
                                    in unreservedOpenEvents) ...[
                                  MeetupExplorerTile(
                                    event: otherEvent,
                                    key: _keyForEvent(otherEvent.id),
                                    enabled: !widget.isUpdatingSelection,
                                    onOpenDetails: () async {
                                      await _openMeetupPreviewSheet(
                                        context: context,
                                        event: otherEvent,
                                        isUpdatingSelection:
                                            widget.isUpdatingSelection,
                                        onChoose: () async {
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
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(conflictMessage),
                                              ),
                                            );
                                            return;
                                          }
                                          if (!context.mounted) return;
                                          widget.onSelectEvent(otherEvent);
                                        },
                                      );
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
                            motionIndex: widget.event == null ? 6 : 7,
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
                                for (final reservedEvent
                                    in reservedOpenEvents) ...[
                                  _ReservedOpenMeetupRow(
                                    key: _keyForEvent(reservedEvent.id),
                                    event: reservedEvent,
                                    isUpdatingSelection:
                                        widget.isUpdatingSelection,
                                    onOpenDetails: () async {
                                      await _openReservedMeetupSheet(
                                        context: context,
                                        event: reservedEvent,
                                      );
                                    },
                                    onAddToCalendar: () async {
                                      final added = await addMeetupToCalendar(
                                          reservedEvent);
                                      if (!context.mounted) return;

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            added
                                                ? 'Calendar opened for ${reservedEvent.title}.'
                                                : "We couldn't open your calendar. Add this meetup manually from your calendar app.",
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
                            motionIndex: widget.event == null ? 7 : 8,
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
              ),
            ],
          );
        },
      ),
    );
  }
}

bool _hasRevealedLocationForEvent(
  MeetupEvent event,
  Map<String, String> revealedLocationsByEventId,
) {
  final override = revealedLocationsByEventId[event.id];
  return (override != null && override.trim().isNotEmpty) ||
      event.shouldRevealExactAddress;
}

String _resolvedLocationLabelForEvent(
  MeetupEvent event,
  Map<String, String> revealedLocationsByEventId,
) {
  final override = revealedLocationsByEventId[event.id];
  if (override != null && override.trim().isNotEmpty) {
    return override.trim();
  }
  return event.locationDetailLabel;
}

class _CurrentMeetupHero extends StatelessWidget {
  const _CurrentMeetupHero({
    required this.event,
    required this.revealedLocationLabel,
    required this.hasRevealedLocation,
  });

  final MeetupEvent event;
  final String revealedLocationLabel;
  final bool hasRevealedLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFFFFFCF7).withValues(alpha: 0.94),
            const Color(0xFFFFFCF7).withValues(alpha: 0.74),
            const Color(0xFFFFFCF7).withValues(alpha: 0.28),
          ],
          stops: const [0, 0.60, 1],
        ),
        border: Border.all(color: const Color(0x99CFE8E2)),
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
          const _HeroTag(
            label: 'Upcoming',
            light: true,
          ),
          const SizedBox(height: 18),
          Text(
            event.title,
            style: responsiveHeadlineStyle(
              context,
              color: const Color(0xFF062B55),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            event.subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF385866),
            ),
          ),
          const SizedBox(height: 20),
          _HeroLine(
            icon: Icons.schedule_outlined,
            label: '${event.detailDateLabel} • ${event.detailTimeLabel}',
            light: true,
          ),
          const SizedBox(height: 12),
          _HeroLine(
            icon: Icons.location_on_outlined,
            label: revealedLocationLabel,
            light: true,
          ),
          const SizedBox(height: 12),
          _HeroLine(
            icon: Icons.local_activity_outlined,
            label: '${event.activityLabel} • ${event.vibeLabel}',
            light: true,
          ),
          if (!hasRevealedLocation) ...[
            const SizedBox(height: 14),
            Text(
              event.addressReleaseSentence,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF60727A),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentMeetupAtGlanceCard extends StatelessWidget {
  const _CurrentMeetupAtGlanceCard({
    required this.motionIndex,
    required this.event,
    required this.revealedLocationLabel,
    required this.hasRevealedLocation,
  });

  final int motionIndex;
  final MeetupEvent event;
  final String revealedLocationLabel;
  final bool hasRevealedLocation;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      motionIndex: motionIndex,
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('At a glance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.event_outlined,
            title: 'Date',
            body: '${event.detailDateLabel} • ${event.detailTimeLabel}',
          ),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.location_on_outlined,
            title: hasRevealedLocation ? 'Location' : 'Area',
            body: revealedLocationLabel,
          ),
          const SizedBox(height: 14),
          const _DetailRow(
            icon: Icons.groups_2_outlined,
            title: 'Your seat',
            body: 'Confirmed',
          ),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.translate_outlined,
            title: 'Languages',
            body: event.languages.join(' • '),
          ),
        ],
      ),
    );
  }
}

class _EmptyMeetupsCatalog extends StatelessWidget {
  const _EmptyMeetupsCatalog({
    required this.allCurrentMeetupsReserved,
    required this.loadFailed,
    this.onRetry,
  });

  final bool allCurrentMeetupsReserved;
  final bool loadFailed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F5),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(
              loadFailed ? Icons.wifi_off_rounded : Icons.event_busy_outlined,
              color: const Color(0xFF138B8A),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allCurrentMeetupsReserved
                      ? "You're all set for now"
                      : loadFailed
                          ? "We couldn’t load meetups"
                          : 'No meetups are open right now',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  allCurrentMeetupsReserved
                      ? "You've reserved every meetup currently available."
                      : loadFailed
                          ? 'Check your connection, then try again.'
                          : 'New meetup times will appear here as soon as they open.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF60727A),
                  ),
                ),
                if (loadFailed && onRetry != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactInfoLine extends StatelessWidget {
  const _CompactInfoLine({
    required this.icon,
    required this.child,
  });

  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          child: Icon(icon, size: 18, color: const Color(0xFF60727A)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: child,
        ),
      ],
    );
  }
}

IconData _compactIconForEvent(MeetupEvent event) {
  final activity = event.activityLabel.toLowerCase();
  if (activity.contains('lunch') || activity.contains('brunch')) {
    return Icons.restaurant_outlined;
  }
  if (activity.contains('dinner')) {
    return Icons.restaurant_menu_outlined;
  }
  if (activity.contains('walk')) {
    return Icons.directions_walk_outlined;
  }
  return Icons.local_cafe_outlined;
}

class _MeetupPreviewSheet extends StatelessWidget {
  const _MeetupPreviewSheet({
    required this.event,
    required this.revealedLocationLabel,
    required this.hasRevealedLocation,
    required this.isUpdatingSelection,
    required this.onChoose,
  });

  final MeetupEvent event;
  final String revealedLocationLabel;
  final bool hasRevealedLocation;
  final bool isUpdatingSelection;
  final Future<void> Function()? onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: maxSheetHeight,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFCF7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: SizedBox(
                    width: double.infinity,
                    height: 220,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MeetupArtwork(
                          event: event,
                          height: 220,
                          radius: 26,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x7AFFF9F0),
                                Color(0x3DFFF9F0),
                                Color(0x2006294A),
                                Color(0xC0062B55),
                              ],
                              stops: [0, 0.34, 0.54, 1],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _Badge(
                                      label: event.timeOfDayLabel, dark: true),
                                  _Badge(label: event.languageLabel),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                event.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                event.subtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFF7F0E8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(
                        label: '${event.activityLabel} • ${event.vibeLabel}'),
                    _MetaChip(label: event.groupSizeLabel),
                  ],
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  icon: Icons.event_outlined,
                  title: 'Date',
                  body: '${event.detailDateLabel} • ${event.detailTimeLabel}',
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  title: 'Area',
                  body: '${event.areaLabel}, ${event.city}',
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.groups_2_outlined,
                  title: 'Group size',
                  body: event.groupSizeLabel,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.translate_outlined,
                  title: 'Languages',
                  body: event.languages.join(' • '),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onChoose == null
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await onChoose!();
                          },
                    icon: Icon(
                      !event.isOpenForReservation
                          ? Icons.do_not_disturb_on_outlined
                          : Icons.event_available_outlined,
                    ),
                    label: Text(
                      !event.isOpenForReservation
                          ? event.statusLabel
                          : (isUpdatingSelection
                              ? 'Updating...'
                              : 'Reserve meetup'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
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
    required this.onOpenDetails,
    required this.onAddToCalendar,
  });

  final MeetupEvent event;
  final bool isUpdatingSelection;
  final VoidCallback onOpenDetails;
  final VoidCallback onAddToCalendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    final artworkSize = compact ? 88.0 : 120.0;
    final artwork = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: artworkSize,
        height: artworkSize,
        child: MeetupArtwork(
          event: event,
          height: artworkSize,
          radius: 22,
          assetName: GeneratedImageAssets.compactCardForEvent(event),
          preferFullBleed: true,
        ),
      ),
    );
    final infoLines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CompactInfoLine(
          icon: Icons.calendar_today_outlined,
          child: Text(
            _monthDayLabel(event),
            style: theme.textTheme.bodyMedium,
            key: ValueKey('reserved-meetup-date-${event.id}'),
          ),
        ),
        const SizedBox(height: 8),
        _CompactInfoLine(
          icon: Icons.schedule_outlined,
          child: Text(
            event.detailTimeLabel,
            style: theme.textTheme.bodyMedium,
            key: ValueKey('reserved-meetup-time-${event.id}'),
          ),
        ),
        const SizedBox(height: 8),
        _CompactInfoLine(
          icon: Icons.place_outlined,
          child: Text(
            event.city,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
    final arrow = Container(
      width: compact ? 44 : 48,
      height: compact ? 44 : 48,
      decoration: const BoxDecoration(
        color: Color(0xFFEAF7F5),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 20,
        color: Color(0xFF60727A),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFCFE8E2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              enabled: !isUpdatingSelection,
              label:
                  'Open details for ${event.title}, ${event.detailDateLabel} at ${event.detailTimeLabel}, ${event.city}. Seat confirmed.',
              child: InkWell(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                onTap: isUpdatingSelection ? null : onOpenDetails,
                child: ExcludeSemantics(
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 14 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDFF3EF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Seat confirmed',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF138B8A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          event.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontSize: compact ? 20 : 22,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            artwork,
                            SizedBox(width: compact ? 12 : 18),
                            Expanded(child: infoLines),
                            if (!compact) ...[
                              const SizedBox(width: 14),
                              arrow,
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 16,
                0,
                compact ? 14 : 16,
                compact ? 14 : 16,
              ),
              child: ElevatedButton.icon(
                onPressed: isUpdatingSelection ? null : onAddToCalendar,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Add to calendar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF062B55),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservedMeetupSheet extends StatelessWidget {
  const _ReservedMeetupSheet({
    required this.event,
    required this.revealedLocationLabel,
    required this.hasRevealedLocation,
    required this.isUpdatingSelection,
    required this.onAddToCalendar,
    required this.onCancel,
  });

  final MeetupEvent event;
  final String revealedLocationLabel;
  final bool hasRevealedLocation;
  final bool isUpdatingSelection;
  final Future<void> Function() onAddToCalendar;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancellationWindowOpen = canCancelMeetupReservation(event);
    final canSubmitCancellation =
        cancellationWindowOpen && !isUpdatingSelection && onCancel != null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFCF7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: SizedBox(
                    width: double.infinity,
                    height: 220,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MeetupArtwork(
                          event: event,
                          height: 220,
                          radius: 26,
                          assetName: GeneratedImageAssets.reservedCardForEvent(
                            event,
                          ),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x4AFFF9F0),
                                Color(0x2806294A),
                                Color(0xB0062B55),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          top: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDFF3EF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Seat confirmed',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: const Color(0xFF138B8A),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Text(
                            event.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _DetailRow(
                  icon: Icons.event_outlined,
                  title: 'Date',
                  body: '${event.detailDateLabel} • ${event.detailTimeLabel}',
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  title: hasRevealedLocation ? 'Location' : 'Area',
                  body: revealedLocationLabel,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.groups_2_outlined,
                  title: 'Group size',
                  body: event.groupSizeLabel,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: Icons.translate_outlined,
                  title: 'Languages',
                  body: event.languages.join(' • '),
                ),
                const SizedBox(height: 18),
                Text(
                  event.subtitle,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isUpdatingSelection
                        ? null
                        : () async {
                            await onAddToCalendar();
                          },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Add to calendar'),
                  ),
                ),
                const SizedBox(height: 10),
                if (cancellationWindowOpen)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: canSubmitCancellation
                          ? () async {
                              await onCancel!();
                            }
                          : null,
                      icon: const Icon(Icons.event_busy_outlined),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD85F4D),
                      ),
                      label: Text(
                        isUpdatingSelection
                            ? 'Updating reservation...'
                            : 'Cancel my reservation',
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EF),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF3CFC5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          size: 20,
                          color: Color(0xFFD85F4D),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This meetup can no longer be cancelled. The cancellation window closes 12 hours before it starts.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF60727A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: Container(
          width: 46,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFD6E3E0),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
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
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              _compactIconForEvent(event),
              size: 36,
              color: const Color(0xFF138B8A),
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
                    _MetaChip(label: _monthDayLabel(event)),
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

String _monthDayLabel(MeetupEvent event) {
  return '${event.startsAt.day} ${_monthLabel(event.startsAt.month)}';
}

String _monthLabel(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final index = month - 1;
  if (index < 0 || index >= months.length) return '';
  return months[index];
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

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label, this.light = false});

  final String label;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final maxWidth = responsiveChipMaxWidth(MediaQuery.sizeOf(context).width);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: light
              ? const Color(0xFFEAF7F5).withValues(alpha: 0.88)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: light
                ? const Color(0xFFCFE8E2)
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: light ? const Color(0xFF138B8A) : Colors.white,
              ),
        ),
      ),
    );
  }
}

class _HeroLine extends StatelessWidget {
  const _HeroLine({
    required this.icon,
    required this.label,
    this.light = false,
  });

  final IconData icon;
  final String label;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: light ? const Color(0xFF062B55) : Colors.white,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      light ? const Color(0xFF062B55) : const Color(0xFFEAF7F5),
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
