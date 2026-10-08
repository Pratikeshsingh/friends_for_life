import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/profile_photo_service.dart';
import '../widgets/section_card.dart';

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
Future<String?> resignCirclePhoto(String path) =>
    ProfilePhotoService.createSignedPhotoUrl(
        supabase: Supabase.instance.client, path: path, forceRefresh: true);

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
        Text(title, style: Theme.of(context).textTheme.displayMedium),
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

  Future<void> _recover() async {
    final path = widget.photoPath;
    final resign = widget.resign ?? resignCirclePhoto;
    if (_retried || path == null || path.isEmpty) return;
    _retried = true;
    try {
      final fresh = await resign(path);
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
        WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
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
