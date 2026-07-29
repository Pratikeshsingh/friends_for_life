import 'package:flutter/material.dart';

import '../core/event_catalog.dart';
import 'meetup_media.dart';

class MeetupExplorerTile extends StatelessWidget {
  const MeetupExplorerTile({
    super.key,
    required this.event,
    required this.onOpenDetails,
    this.enabled = true,
    this.selected = false,
    this.keyPrefix = 'explore-meetup',
  });

  final MeetupEvent event;
  final VoidCallback onOpenDetails;
  final bool enabled;
  final bool selected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = _badgeColorForEvent(event);
    final badgeIcon = _iconForEvent(event);
    final unavailable = !selected && !event.isOpenForReservation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final imageSize = compact ? 88.0 : 136.0;
        final imageRadius = compact ? 18.0 : 24.0;
        final arrowSize = compact ? 38.0 : 52.0;
        final horizontalGap = compact ? 12.0 : 18.0;
        final arrowGap = compact ? 8.0 : 14.0;
        final titleStyle = theme.textTheme.headlineSmall?.copyWith(
          fontSize: compact ? 18 : 24,
          height: 1.08,
        );
        final availability =
            selected ? 'Reserved' : event.browseAvailabilityLabel;
        final availabilityColor = _availabilityColor(event, selected: selected);
        final artwork = ClipRRect(
          borderRadius: BorderRadius.circular(imageRadius),
          child: SizedBox(
            width: imageSize,
            height: imageSize,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MeetupArtwork(
                  event: event,
                  height: imageSize,
                  radius: imageRadius,
                  assetName: GeneratedImageAssets.compactCardForEvent(event),
                  preferFullBleed: true,
                ),
                Positioned(
                  left: 8,
                  right: compact ? 8 : null,
                  bottom: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 12,
                      vertical: compact ? 7 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            badgeIcon,
                            size: compact ? 14 : 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: compact ? 6 : 8),
                          Text(
                            event.activityLabel,
                            maxLines: 1,
                            softWrap: false,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontSize: compact ? 12 : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: _ArtworkCostMarker(
                    key: ValueKey('$keyPrefix-cost-${event.id}'),
                    compact: compact,
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 7,
                    left: 7,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3FBF9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x26062B55),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 19,
                        color: Color(0xFF138B8A),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        final arrow = Container(
          width: arrowSize,
          height: arrowSize,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDFF3EF) : const Color(0xFFEAF7F5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            selected
                ? Icons.check_rounded
                : unavailable
                    ? Icons.do_not_disturb_on_outlined
                    : Icons.arrow_forward_ios_rounded,
            size: compact ? 20 : 22,
            color: selected
                ? const Color(0xFF138B8A)
                : unavailable
                    ? const Color(0xFFD85F4D)
                    : const Color(0xFF60727A),
          ),
        );
        final infoLines = <Widget>[
          _InfoLine(
            icon: Icons.calendar_today_outlined,
            child: Text(
              _monthDayLabel(event),
              style: theme.textTheme.bodyMedium,
              key: ValueKey('$keyPrefix-date-${event.id}'),
            ),
          ),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.schedule_outlined,
            child: Text(
              event.detailTimeLabel,
              style: theme.textTheme.bodyMedium,
              key: ValueKey('$keyPrefix-time-${event.id}'),
            ),
          ),
          const SizedBox(height: 8),
          _InfoLine(
            icon: Icons.place_outlined,
            child: Text(
              event.city,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ];
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: event.relativeDayLabel,
                    style: const TextStyle(color: Color(0xFF138B8A)),
                  ),
                  const TextSpan(
                    text: ' · ',
                    style: TextStyle(color: Color(0xFF8A999D)),
                  ),
                  TextSpan(
                    text: availability,
                    style: TextStyle(color: availabilityColor),
                  ),
                ],
              ),
              key: ValueKey('$keyPrefix-summary-${event.id}'),
              maxLines: 2,
              overflow: TextOverflow.fade,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
            SizedBox(height: compact ? 12 : 16),
            ...infoLines,
          ],
        );
        return Semantics(
          button: true,
          enabled: enabled,
          selected: selected,
          label:
              '${event.title}. ${event.relativeDayLabel}. ${event.activityLabel}. ${_monthDayLabel(event)} at ${event.detailTimeLabel}. ${event.city}. $availability. $meetupCostSemantics',
          hint: enabled
              ? selected
                  ? 'Open reserved meetup details'
                  : 'Open meetup details'
              : 'Reservations are updating',
          child: ExcludeSemantics(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: enabled ? onOpenDetails : null,
                child: Ink(
                  padding: EdgeInsets.all(compact ? 14 : 16),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFF3FBF9)
                        : const Color(0xFFFFFCF7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF9ED6CC)
                          : const Color(0xFFDDE7E3),
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1206294A),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: compact
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            artwork,
                            SizedBox(width: horizontalGap),
                            Expanded(child: details),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            artwork,
                            SizedBox(width: horizontalGap),
                            Expanded(child: details),
                            SizedBox(width: arrowGap),
                            arrow,
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Color _availabilityColor(MeetupEvent event, {required bool selected}) {
  if (selected) return const Color(0xFF0B7474);
  if (event.spotsLeft == 1 || event.spotsLeft == 2) {
    return const Color(0xFF9A6518);
  }
  if (!event.isOpenForReservation) return const Color(0xFFC55243);
  return const Color(0xFF527079);
}

class _ArtworkCostMarker extends StatelessWidget {
  const _ArtworkCostMarker({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 32.0;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xF2FFFCF8),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xCFFFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26062B55),
            blurRadius: 9,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '€',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF355D64),
              fontWeight: FontWeight.w800,
              height: 1,
            ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
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
        Expanded(child: child),
      ],
    );
  }
}

IconData _iconForEvent(MeetupEvent event) {
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

Color _badgeColorForEvent(MeetupEvent event) {
  final activity = event.activityLabel.toLowerCase();
  if (activity.contains('lunch') || activity.contains('brunch')) {
    return const Color(0xCCCF9A54);
  }
  if (activity.contains('dinner')) {
    return const Color(0xCCCF7C58);
  }
  if (activity.contains('walk')) {
    return const Color(0xCC5F8D76);
  }
  return const Color(0xCC29322E);
}

String _monthDayLabel(MeetupEvent event) {
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
  final monthIndex = event.startsAt.month - 1;
  final month =
      monthIndex < 0 || monthIndex >= months.length ? '' : months[monthIndex];
  return '${event.startsAt.day} $month';
}
