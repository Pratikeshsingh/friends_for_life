import 'package:flutter/material.dart';

import '../core/event_catalog.dart';
import 'motion.dart';

class GeneratedImageAssets {
  const GeneratedImageAssets._();

  static const _base = 'assets/generated';

  static const onboardingHero = '$_base/onboarding-hero.png';
  static const brunch = '$_base/meetup-brunch.png';
  static const dinner = '$_base/meetup-dinner.png';
  static const coffee = '$_base/meetup-coffee.png';
  static const games = '$_base/meetup-games.png';
  static const drinks = '$_base/meetup-drinks.png';
  static const museum = '$_base/meetup-museum.png';

  static String? forEvent(MeetupEvent? event) {
    switch (event?.id) {
      case 'day-brunch':
        return brunch;
      case 'eve-social':
        return dinner;
      case 'day-coffee':
        return coffee;
      default:
        return forActivity(event?.activityLabel);
    }
  }

  static String? forActivity(String? activityLabel) {
    final activity = activityLabel?.toLowerCase() ?? '';
    if (activity.contains('brunch') || activity.contains('lunch')) {
      return brunch;
    }
    if (activity.contains('dinner')) return dinner;
    if (activity.contains('coffee') || activity.contains('walk')) {
      return coffee;
    }
    if (activity.contains('game')) return games;
    if (activity.contains('drink')) return drinks;
    if (activity.contains('museum') || activity.contains('culture')) {
      return museum;
    }
    return onboardingHero;
  }
}

class MeetupArtwork extends StatelessWidget {
  const MeetupArtwork({
    super.key,
    this.event,
    this.height = 220,
    this.radius = 24,
    this.caption,
    this.secondaryCaption,
    this.assetName,
  });

  final MeetupEvent? event;
  final double height;
  final double radius;
  final String? caption;
  final String? secondaryCaption;
  final String? assetName;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForEvent(event);
    final theme = Theme.of(context);
    final resolvedAsset = assetName ??
        GeneratedImageAssets.forEvent(event) ??
        GeneratedImageAssets.onboardingHero;
    final resolvedImageUrl = event?.imageUrl;
    final hasImageUrl = resolvedImageUrl != null && resolvedImageUrl.isNotEmpty;

    return MotionPressable(
      hoverScale: 1.01,
      pressedScale: 0.996,
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: hasImageUrl
                    ? _RemoteArtworkBase(
                        imageUrl: resolvedImageUrl,
                        fallback: _GeneratedArtworkBase(
                          assetName: resolvedAsset,
                          fallback: _AbstractArtworkBase(
                            palette: palette,
                            height: height,
                          ),
                        ),
                      )
                    : _GeneratedArtworkBase(
                        assetName: resolvedAsset,
                        fallback: _AbstractArtworkBase(
                          palette: palette,
                          height: height,
                        ),
                      ),
              ),
              const Positioned.fill(child: _ArtworkSheen()),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x08000000),
                        Color(0x18000000),
                        Color(0xA0120C0A),
                      ],
                    ),
                  ),
                ),
              ),
              if (caption != null || secondaryCaption != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (secondaryCaption != null)
                        Text(
                          secondaryCaption!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFFFFE8D8),
                            letterSpacing: 0,
                          ),
                        ),
                      if (secondaryCaption != null) const SizedBox(height: 6),
                      if (caption != null)
                        Text(
                          caption!,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtworkSheen extends StatefulWidget {
  const _ArtworkSheen();

  @override
  State<_ArtworkSheen> createState() => _ArtworkSheenState();
}

class _ArtworkSheenState extends State<_ArtworkSheen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final x = (_controller.value * 2.4) - 1.2;
        return FractionalTranslation(
          translation: Offset(x, 0),
          child: child,
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.42, 0.5, 0.58],
          ),
        ),
      ),
    );
  }
}

class SeatMeter extends StatelessWidget {
  const SeatMeter({
    super.key,
    required this.filled,
    required this.total,
    this.color = const Color(0xFF36B8A5),
    this.background = const Color(0xFFDDE7E3),
    this.showLabel = true,
  });

  final int filled;
  final int total;
  final Color color;
  final Color background;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    final activeCount = filled.clamp(0, safeTotal);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            total - filled <= 0 ? 'Full' : '${total - filled} spots left',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            for (var index = 0; index < safeTotal; index++) ...[
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: index < activeCount ? color : background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (index < safeTotal - 1) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _GeneratedArtworkBase extends StatelessWidget {
  const _GeneratedArtworkBase({
    required this.assetName,
    required this.fallback,
  });

  final String assetName;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetName,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class _RemoteArtworkBase extends StatelessWidget {
  const _RemoteArtworkBase({
    required this.imageUrl,
    required this.fallback,
  });

  final String imageUrl;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class _AbstractArtworkBase extends StatelessWidget {
  const _AbstractArtworkBase({
    required this.palette,
    required this.height,
  });

  final _ArtworkPalette palette;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.dark,
            palette.base,
            palette.light,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: -32,
            top: 18,
            child: _GlowOrb(
              size: height * 0.58,
              colors: [
                palette.accent.withValues(alpha: 0.82),
                palette.accent.withValues(alpha: 0.0),
              ],
            ),
          ),
          Positioned(
            right: -16,
            top: 34,
            child: _GlassPanel(
              width: height * 0.52,
              height: height * 0.78,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            left: height * 0.24,
            bottom: -18,
            child: _GlowOrb(
              size: height * 0.52,
              colors: [
                Colors.white.withValues(alpha: 0.32),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: Container(
              width: height * 0.28,
              height: height * 0.28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.18,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
    );
  }
}

class _ArtworkPalette {
  const _ArtworkPalette({
    required this.dark,
    required this.base,
    required this.light,
    required this.accent,
  });

  final Color dark;
  final Color base;
  final Color light;
  final Color accent;
}

_ArtworkPalette _paletteForEvent(MeetupEvent? event) {
  final activity = event?.activityLabel.toLowerCase() ?? '';

  if (activity.contains('coffee')) {
    return const _ArtworkPalette(
      dark: Color(0xFF062B55),
      base: Color(0xFF138B8A),
      light: Color(0xFFB9E3DC),
      accent: Color(0xFFFFD5C8),
    );
  }
  if (activity.contains('dinner') || activity.contains('drinks')) {
    return const _ArtworkPalette(
      dark: Color(0xFF062B55),
      base: Color(0xFFFF7759),
      light: Color(0xFFFFD5C8),
      accent: Color(0xFFEAF7F5),
    );
  }
  if (activity.contains('walk')) {
    return const _ArtworkPalette(
      dark: Color(0xFF062B55),
      base: Color(0xFF36B8A5),
      light: Color(0xFFB9E3DC),
      accent: Color(0xFFFFFCF7),
    );
  }
  if (activity.contains('museum')) {
    return const _ArtworkPalette(
      dark: Color(0xFF062B55),
      base: Color(0xFF476B8D),
      light: Color(0xFFCBD9E6),
      accent: Color(0xFFEAF7F5),
    );
  }
  if (activity.contains('games')) {
    return const _ArtworkPalette(
      dark: Color(0xFF062B55),
      base: Color(0xFF476B8D),
      light: Color(0xFFCBD9E6),
      accent: Color(0xFFFFD5C8),
    );
  }

  return const _ArtworkPalette(
    dark: Color(0xFF062B55),
    base: Color(0xFF138B8A),
    light: Color(0xFFB9E3DC),
    accent: Color(0xFFFFD5C8),
  );
}
