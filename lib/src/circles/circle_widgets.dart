import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart' hide Text;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../core/i18n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/profile_photo_service.dart';
import '../widgets/section_card.dart';
import 'circle_repository.dart';

/// A confirmation that sits over the content rather than cutting a grey slab
/// across the bottom of it: floating, inset, rounded, and tinted from the
/// brand's own navy at partial opacity so the page stays visible behind it.
void showCircleToast(BuildContext context, String message,
        {IconData icon = Icons.check_circle_rounded}) =>
    showCircleToastOn(ScaffoldMessenger.maybeOf(context), message, icon: icon);

/// The same toast for a caller that captured its messenger before an await,
/// which is the safe way to report the result of something asynchronous from
/// a widget that has no `mounted` of its own.
void showCircleToastOn(ScaffoldMessengerState? messenger, String message,
    {IconData icon = Icons.check_circle_rounded}) {
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      // The glass is the content, not the SnackBar: a BackdropFilter only
      // blurs what is painted behind its own subtree, so the bar itself has
      // to be fully transparent for the page to show through at all.
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 3),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              // Dark enough that white text stays legible over a light page
              // or a photo, sheer enough to read as glass rather than paint.
              color: circleNavy.withValues(alpha: .58),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: .22), width: 1),
              boxShadow: [
                BoxShadow(
                    color: circleNavy.withValues(alpha: .22),
                    blurRadius: 24,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: const Color(0xFF8DF0DF), size: 20),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(message,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.35))),
            ]),
          ),
        ),
      ),
    ));
}

/// Mints a fresh signed URL for a stored photo path. A default rather than a
/// parameter threaded through every screen, because an avatar turns up at
/// arbitrary depth and the only thing it needs is the path it already has.
/// Throws in previews and tests, where there is no Supabase — callers treat
/// that as "keep the initial".
Future<String?> resignCirclePhoto(String path, {bool force = true}) =>
    ProfilePhotoService.createSignedPhotoUrl(
        supabase: Supabase.instance.client, path: path, forceRefresh: force);

const circleNavy = Color(0xFF062B55);
const circleTeal = Color(0xFF138B8A);
const circleCoral = Color(0xFFFF7759);

/// Text versions of the brand accents. The bright teal and coral are for
/// icons, fills and large graphics; small text needs these darker shades to
/// stay readable (at least 4.5:1 on every surface the app uses).
const circleTealText = Color(0xFF0D6E6D);
const circleCoralText = Color(0xFFB3412F);

class CirclePanel extends StatelessWidget {
  const CirclePanel({super.key, required this.children, this.tint = false});
  final List<Widget> children;
  final bool tint;
  @override
  Widget build(BuildContext context) => SectionCard(
      enableReveal: false,
      highlight: tint,
      child: Material(
          type: MaterialType.transparency,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children)));
}

class CircleHeading extends StatelessWidget {
  const CircleHeading(this.title, {super.key, this.eyebrow, this.subtitle});
  final String title;
  final String? eyebrow, subtitle;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (eyebrow != null) ...[
          Text(t(eyebrow!).toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  color: circleTealText)),
          const SizedBox(height: 12)
        ],
        // Already display-sized: at 200% text it would fill the first
        // screen, so it grows to at most 1.4 times.
        MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.4,
            child:
                Text(title, style: Theme.of(context).textTheme.displayMedium)),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge)
        ],
        const SizedBox(height: 24),
      ]);
}

class CirclePill extends StatelessWidget {
  const CirclePill(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFFEAF7F5),
          borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: circleTeal),
          const SizedBox(width: 6)
        ],
        Flexible(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: circleNavy)))
      ]));
}

/// Photo URLs here are signed for ten minutes. A form left open, a slow
/// network, or one failed refresh used to turn a real photo into a coloured
/// initial with no way back — which is why a photo that was definitely
/// uploaded was "not always visible". This re-signs once from the stored
/// path before giving up, and accepts a URL that arrives later.
class CircleMemberAvatar extends StatefulWidget {
  const CircleMemberAvatar(this.name,
      {super.key,
      this.index = 0,
      this.radius = 23,
      this.photoUrl,
      this.photoPath,
      this.resign});
  final String name;
  final int index;
  final double radius;
  final String? photoUrl;

  /// The storage path, so a dead URL can be replaced rather than mourned.
  final String? photoPath;

  /// Mints a fresh signed URL for [photoPath]. Null in previews and tests,
  /// where there is nothing to sign against.
  final Future<String?> Function(String path)? resign;

  @override
  State<CircleMemberAvatar> createState() => _CircleMemberAvatarState();
}

class _CircleMemberAvatarState extends State<CircleMemberAvatar> {
  String? _url;
  bool _retried = false;

  @override
  void initState() {
    super.initState();
    _url = widget.photoUrl;
  }

  @override
  void didUpdateWidget(CircleMemberAvatar old) {
    super.didUpdateWidget(old);
    // A URL refreshed by a reload must reach an avatar already on screen.
    if (widget.photoUrl != old.photoUrl && widget.photoUrl != null) {
      _url = widget.photoUrl;
      _retried = false;
    }
  }

  /// [broken]: the link failed to load, so a brand-new one is needed. Without
  /// it the avatar only had no link yet, and shares the screen's own request.
  Future<void> _recover({bool broken = true}) async {
    final path = widget.photoPath;
    if (_retried || path == null || path.isEmpty) return;
    _retried = true;
    try {
      final fresh = widget.resign != null
          ? await widget.resign!(path)
          : await resignCirclePhoto(path, force: broken);
      if (mounted && fresh != null) setState(() => _url = fresh);
    } catch (_) {
      // The coloured initial is a perfectly good answer; never crash here.
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = CircleMemberAvatarBase(
        name: widget.name, index: widget.index, radius: widget.radius);
    final url = _url;
    if (url == null) {
      if (!_retried && widget.photoPath != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _recover(broken: false));
      }
      return fallback;
    }
    return ClipOval(
        child: Image.network(url,
            width: widget.radius * 2,
            height: widget.radius * 2,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            semanticLabel: t('${widget.name}’s profile photo'),
            errorBuilder: (_, error, stack) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
      return fallback;
    }));
  }
}

class CircleMemberAvatarBase extends StatelessWidget {
  const CircleMemberAvatarBase(
      {super.key,
      required this.name,
      required this.index,
      required this.radius});
  final String name;
  final int index;
  final double radius;
  @override
  Widget build(BuildContext context) {
    const colours = [
      Color(0xFFD8EEE8),
      Color(0xFFF5DCC9),
      Color(0xFFDCE5F0),
      Color(0xFFF5E9C8),
      Color(0xFFE8DEF0),
      Color(0xFFD8EAEF)
    ];
    return Container(
        width: radius * 2,
        height: radius * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: colours[index % colours.length],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2)),
        child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
            style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: radius,
                fontWeight: FontWeight.w700,
                color: circleNavy)));
  }
}

/// Someone's photo, large, for a closer look. Tap anywhere to close.
Future<void> showCirclePhoto(BuildContext context, String name,
        {String? photoUrl, String? photoPath}) =>
    showDialog<void>(
        context: context,
        barrierColor: circleNavy.withValues(alpha: .85),
        builder: (c) => GestureDetector(
            onTap: () => Navigator.pop(c),
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircleMemberAvatar(name,
                  photoUrl: photoUrl,
                  photoPath: photoPath,
                  radius: (MediaQuery.sizeOf(c).shortestSide * .4)
                      .clamp(80.0, 180.0)),
              const SizedBox(height: 16),
              Text(name,
                  style: Theme.of(c)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white)),
            ]))));

/// Each week's kind of meetup at a glance, in one of the brand's soft
/// colours. A photo of the place can take its spot later.
({IconData icon, Color background, Color foreground}) circleMeetupLook(
    Json meetup) {
  final hour = circleMeetupHour(meetup);
  return switch (meetup['week']) {
    1 => (
        icon: Icons.waving_hand_rounded,
        background: const Color(0xFFFFE6DD),
        foreground: circleCoralText
      ),
    2 || 4 when hour >= 12 => (
        icon: Icons.emoji_events_rounded,
        background: const Color(0xFFDDF0EC),
        foreground: circleTealText
      ),
    2 => (
        icon: Icons.extension_rounded,
        background: const Color(0xFFDDF0EC),
        foreground: circleTealText
      ),
    3 => (
        icon:
            hour < 12 ? Icons.brunch_dining_rounded : Icons.restaurant_rounded,
        background: const Color(0xFFFBEED3),
        foreground: const Color(0xFF8A5A12)
      ),
    4 => (
        icon: Icons.museum_rounded,
        background: const Color(0xFFECE7F6),
        foreground: const Color(0xFF5B4A8B)
      ),
    5 => (
        icon: Icons.groups_rounded,
        background: const Color(0xFFE2EEF8),
        foreground: circleNavy
      ),
    6 => (
        icon: Icons.celebration_rounded,
        background: const Color(0xFFFBE3E8),
        foreground: const Color(0xFF9B3550)
      ),
    _ => (
        icon: Icons.event_rounded,
        background: const Color(0xFFE2EEF8),
        foreground: circleNavy
      ),
  };
}

/// Which illustration a meetup gets (see docs/ui-ux/meetup-illustrations-brief.md).
String circleMeetupArtName(Json meetup) {
  final hour = circleMeetupHour(meetup);
  final morning = hour < 12, evening = hour >= 17;
  return switch (meetup['week']) {
    1 => evening ? 'meetup-hello-evening' : 'meetup-hello-day',
    2 => evening ? 'meetup-boules' : 'meetup-games',
    3 => morning
        ? 'meetup-brunch'
        : evening
            ? 'meetup-dinner'
            : 'meetup-lunch',
    4 => morning ? 'meetup-cheese' : 'meetup-rematch',
    5 => 'meetup-your-call',
    6 => morning ? 'meetup-brunch' : 'meetup-graduation',
    _ => '',
  };
}

/// Illustrations that have arrived, as `assets/generated/meetups/NAME.webp`.
/// A week without one shows its icon tile, so they can come one by one.
const circleMeetupArtReady = <String>{
  'meetup-hello-evening',
  'meetup-hello-day',
  'meetup-boules',
  'meetup-games',
  'meetup-dinner',
  'meetup-lunch',
  'meetup-brunch',
  'meetup-rematch',
  'meetup-cheese',
  'meetup-your-call',
  'meetup-graduation',
};

/// The meetup's picture: its illustration once there is one, otherwise a
/// rounded tile with its icon.
class CircleMeetupTile extends StatelessWidget {
  const CircleMeetupTile(this.meetup, {super.key, this.size = 52});
  final Json meetup;
  final double size;
  @override
  Widget build(BuildContext context) {
    final look = circleMeetupLook(meetup);
    final art = circleMeetupArtName(meetup);
    final radius = BorderRadius.circular(size * .32);
    return ExcludeSemantics(
        child: circleMeetupArtReady.contains(art)
            ? ClipRRect(
                borderRadius: radius,
                child: Image.asset('assets/generated/meetups/$art.webp',
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    cacheWidth: (size * 3).round()))
            : Container(
                width: size,
                height: size,
                decoration:
                    BoxDecoration(color: look.background, borderRadius: radius),
                child:
                    Icon(look.icon, color: look.foreground, size: size * .5)));
  }
}

/// A compact action for cards: the main one navy, the rest in the teal
/// tint. Buttons come in three kinds across the app: navy for the one
/// thing to do, tinted (or white with a hairline) for the alternatives,
/// and teal text links for the rest; red only for destructive ones.
class CircleQuickAction extends StatelessWidget {
  const CircleQuickAction(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed,
      this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    final style = (primary
            ? FilledButton.styleFrom(
                backgroundColor: circleNavy, foregroundColor: Colors.white)
            : FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE4F1EE),
                foregroundColor: circleNavy))
        .copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16)),
            // The theme's label font, only smaller: a bare TextStyle would
            // drop the app's typeface.
            textStyle: WidgetStatePropertyAll(Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
            // Rounded like every other button and the action tiles.
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))));
    return FilledButton.icon(
        style: style,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label));
  }
}

/// One of a card's everyday actions.
/// [icon] is a Material icon, or WhatsApp's ([circleWhatsAppIcon]).
typedef CircleCardAction = ({Object icon, String label, VoidCallback? onTap});

/// A Material icon or a brand icon (WhatsApp), drawn the same way.
Widget circleIcon(Object icon, {double size = 20, Color? color}) =>
    icon is FaIconData
        ? FaIcon(icon, size: size, color: color)
        : Icon(icon as IconData, size: size, color: color);

/// A card's everyday actions as equal tiles, icon over label, so three fit
/// side by side on the narrowest phone, like the actions on a place card in
/// a maps app.
class CircleActionRow extends StatelessWidget {
  const CircleActionRow(this.actions, {super.key});
  final List<CircleCardAction> actions;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
              child: Semantics(
                  button: true,
                  enabled: actions[i].onTap != null,
                  child: Material(
                      color: const Color(0xFFE4F1EE),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: actions[i].onTap,
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 4),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    circleIcon(actions[i].icon,
                                        size: 20, color: circleNavy),
                                    const SizedBox(height: 4),
                                    // Shrinks a long label rather than
                                    // cutting it off.
                                    FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(actions[i].label,
                                            maxLines: 1,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: circleNavy))),
                                  ])))))),
        ],
      ]);
}

/// A small solid label on a card: "Included in your fee", "Your call".
class CircleBadge extends StatelessWidget {
  const CircleBadge(this.text,
      {super.key,
      required this.icon,
      this.background = const Color(0xFFDDF3E6),
      this.foreground = const Color(0xFF1B6B4A)});
  final String text;
  final IconData icon;
  final Color background, foreground;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: foreground),
        const SizedBox(width: 6),
        Flexible(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: foreground))),
      ]));
}

/// The top of a Home screen: a small label, a title and one line, so the
/// first thing below it (the card that matters) is on the first screen.
class CircleHomeHeader extends StatelessWidget {
  const CircleHomeHeader(
      {super.key, this.eyebrow, required this.title, this.subtitle});
  final String title;
  final String? eyebrow;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (eyebrow != null) ...[
          Text(t(eyebrow!).toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  color: circleTealText)),
          const SizedBox(height: 8),
        ],
        MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.4,
            child:
                Text(title, style: Theme.of(context).textTheme.headlineMedium)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!,
              style: const TextStyle(
                  fontSize: 15, color: Color(0xFF4F5D66), height: 1.4)),
        ],
      ]));
}

/// WhatsApp's own icon, in its green, wherever WhatsApp is meant.
const circleWhatsAppIcon = FontAwesomeIcons.whatsapp;
const circleWhatsAppGreen = Color(0xFF1FA855);

class CircleWhatsAppIcon extends StatelessWidget {
  const CircleWhatsAppIcon({super.key, this.size = 20, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: FaIcon(circleWhatsAppIcon,
          size: size, color: color ?? circleWhatsAppGreen));
}

/// A small ⓘ for the "why we ask" behind a question: there for the curious,
/// out of the way for everyone who just fills it in.
class CircleInfoButton extends StatelessWidget {
  const CircleInfoButton(this.title, this.text, {super.key});
  final String title, text;
  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: t('More about this'),
      visualDensity: VisualDensity.compact,
      iconSize: 19,
      // Quiet slate, not teal: it explains, it doesn't act.
      color: const Color(0xFF6B7A84),
      icon: const Icon(Icons.info_outline_rounded),
      onPressed: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (c) => SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(text, style: const TextStyle(height: 1.45)),
                      ])))));
}
