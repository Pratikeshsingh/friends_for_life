import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import '../core/i18n.dart' as i18n show t;
import 'circle_repository.dart'
    show
        circleIncludedWeeks,
        circleMorningWeekShort,
        circleMorningWeekTitles,
        circleWeekShort,
        circleWeekTitles;
import 'circle_widgets.dart';

/// The six weeks as one vertical line, so the whole plan reads at a glance:
/// a first hello, two included activities, a meal, a week the group plans
/// itself and a graduation. Mornings have their own café version; a switch
/// shows either.
///
/// The full version (landing page) draws its line and reveals each week the
/// first time it scrolls into view. The compact version (inside the app) is
/// still, and can mark weeks that are done and the one coming up. Reduced
/// motion always gets the finished picture.
class CircleJourney extends StatefulWidget {
  const CircleJourney(
      {super.key,
      this.compact = false,
      this.completed = 0,
      this.current,
      this.morning = false});
  final bool compact;

  /// Starts on the morning version (cafés instead of games and a dinner).
  final bool morning;

  /// Weeks already behind the group, shown with a tick.
  final int completed;

  /// The next week (1–6), highlighted. Null shows the plan without progress.
  final int? current;
  @override
  State<CircleJourney> createState() => _CircleJourneyState();
}

const _coral = Color(0xFFE9806A);
const _soft = Color(0xFFDCE9ED);
const _handover = Color(0xFF92DACE);

class _CircleJourneyState extends State<CircleJourney>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  ScrollPosition? _scroll;
  bool _started = false;
  late bool _morning = widget.morning;

  @override
  void didUpdateWidget(CircleJourney old) {
    super.didUpdateWidget(old);
    if (old.morning != widget.morning) _morning = widget.morning;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context) || widget.compact;
    if (still) {
      _reveal.value = 1;
      _started = true;
      return;
    }
    if (_started) return;
    _scroll?.removeListener(_check);
    _scroll = Scrollable.maybeOf(context)?.position;
    _scroll?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  /// Starts the reveal once the top of the plan is well inside the screen.
  void _check() {
    if (_started || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height * .85) {
      _started = true;
      _scroll?.removeListener(_check);
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_check);
    _reveal.dispose();
    super.dispose();
  }

  /// 0→1 progress for one slot of the timeline (weeks and handover labels).
  double _at(int slot, int slots) {
    final start = slot / slots * .8;
    return Curves.easeOutCubic
        .transform(((_reveal.value - start) / .28).clamp(0.0, 1.0));
  }

  /// Two columns: the words on the left, the weeks on the right.
  bool _wide = false;

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final theme = Theme.of(context);
    // The card's width: the page's reading column, less its padding.
    _wide = !compact &&
        (MediaQuery.sizeOf(context).width.clamp(0, 1100) - 80 - 60) >= 720;
    final header =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Same people.',
          style: theme.textTheme.displayMedium?.copyWith(
              color: Colors.white,
              height: 1.05,
              fontSize: compact ? 30 : null)),
      Text('Six weeks.',
          style: theme.textTheme.displayMedium?.copyWith(
              color: _coral, height: 1.05, fontSize: compact ? 30 : null)),
      const SizedBox(height: 12),
      const Text(
          'Two activities included, a meal together, and a week your group plans itself. With one-to-ones in between: optional, but recommended.',
          style: TextStyle(color: _soft, height: 1.45)),
      if (widget.current == null) ...[
        const SizedBox(height: 16),
        // One switch on one line: the chosen half filled.
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(24)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _variant('Afternoons & evenings', false),
                  _variant('Mornings', true),
                ]))),
      ],
      if (_wide) ...[
        const SizedBox(height: 30),
        // The offer in three lines, where the wide layout has room.
        for (final (icon, line) in const [
          (Icons.groups_rounded, 'Six meetups, the same people'),
          (Icons.redeem_rounded, 'Two activities included'),
          (Icons.euro_rounded, '€39 once, no subscription'),
        ])
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 19, color: _handover)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(line,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700))),
              ])),
      ],
    ]);
    final timeline = AnimatedBuilder(
        animation: _reveal,
        builder: (context, _) {
          // Slots: handover, weeks 1–4, handover, week 5, handover, week 6.
          const slots = 9;
          const handovers = {
            0: 'We plan weeks 1 to 4',
            4: 'Week 5 is your call',
            5: 'We plan your graduation',
          };
          final rows = <Widget>[];
          var slot = 0;
          for (var i = 0; i < 6; i++) {
            if (handovers[i] case final label?) {
              rows.add(_handoverRow(label, _at(slot++, slots), first: i == 0));
            }
            rows.add(_weekRow(i, _at(slot++, slots), last: i == 5));
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: rows);
        });
    return Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 22 : 30),
        decoration: BoxDecoration(
            color: circleNavy, borderRadius: BorderRadius.circular(30)),
        child: LayoutBuilder(builder: (context, box) {
          if (_wide) {
            // The words sit level with the middle of the weeks, so no empty
            // navy is left under them.
            return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 2, child: header),
                  const SizedBox(width: 40),
                  Expanded(flex: 3, child: timeline),
                ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                SizedBox(height: compact ? 20 : 28),
                timeline,
              ]);
        }));
  }

  /// The left rail: a line segment that grows with [t], so the line draws
  /// downwards as the plan reveals.
  Widget _rail(
      {required double t, Widget? node, bool upper = true, bool lower = true}) {
    final grow = Align(
        alignment: Alignment.topCenter,
        child: FractionallySizedBox(
            heightFactor: t,
            child: Container(width: 3, color: _coral.withValues(alpha: .9))));
    return SizedBox(
        width: 48,
        child: Column(children: [
          if (node == null)
            Expanded(child: grow)
          else ...[
            Container(
                width: 3,
                height: 6,
                color: upper ? _coral.withValues(alpha: .9) : null),
            node,
            Expanded(child: lower ? grow : const SizedBox.shrink()),
          ],
        ]));
  }

  Widget _handoverRow(String label, double p, {bool first = false}) => _railRow(
      first ? const SizedBox(width: 48) : _rail(t: p),
      Opacity(
          opacity: p,
          child: Padding(
              padding: const EdgeInsets.only(bottom: 14, top: 2),
              child: Text(t(label).toUpperCase(),
                  style: const TextStyle(
                      color: _handover,
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800)))));

  Widget _weekRow(int i, double t, {required bool last}) {
    final done = i < widget.completed;
    final next = widget.current == i + 1;
    final dim = widget.current != null && !done && !next;
    final circle = Transform.scale(
        scale: .6 + .4 * t,
        child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? circleTeal
                    : dim
                        ? _coral.withValues(alpha: .45)
                        : _coral,
                border:
                    next ? Border.all(color: Colors.white, width: 3) : null),
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                : Icon(
                    circleMeetupLook({
                      'week': i + 1,
                      'time': _morning ? '10:30' : '20:00'
                    }).icon,
                    color: circleNavy,
                    size: 21)));
    return _railRow(
        _rail(t: t, node: circle, upper: i != 0, lower: !last),
        Opacity(
            opacity: dim ? .55 * t : t,
            child: Transform.translate(
                offset: Offset(0, 14 * (1 - t)),
                child: Padding(
                    padding: EdgeInsets.only(top: 6, bottom: last ? 0 : 14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i18n.t('Week ${i + 1}').toUpperCase(),
                              style: const TextStyle(
                                  color: _handover,
                                  fontSize: 10.5,
                                  letterSpacing: 1.3,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Row(children: [
                            Flexible(
                                child: Text(
                                    (_morning
                                        ? circleMorningWeekTitles
                                        : circleWeekTitles)[i],
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: widget.compact ? 16 : 18,
                                        fontWeight: FontWeight.w700))),
                            if (next) ...[
                              const SizedBox(width: 8),
                              const _NextTag(),
                            ],
                          ]),
                          if (circleIncludedWeeks.contains(i + 1)) ...[
                            const SizedBox(height: 6),
                            const _IncludedTag(),
                          ],
                          const SizedBox(height: 4),
                          Text(
                              (_morning
                                  ? circleMorningWeekShort
                                  : circleWeekShort)[i],
                              style:
                                  const TextStyle(color: _soft, height: 1.4)),
                        ])))));
  }

  /// The two versions of the plan: a pill each, the chosen one filled.
  Widget _variant(String label, bool morning) {
    final on = _morning == morning;
    return Semantics(
        button: true,
        selected: on,
        child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _morning = morning),
            child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: on ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(label,
                    style: TextStyle(
                        color: on ? circleNavy : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)))));
  }

  /// The rail takes the full height of the text beside it, so the line runs
  /// unbroken from one week to the next.
  Widget _railRow(Widget rail, Widget content) => Stack(children: [
        Positioned(left: 0, top: 0, bottom: 0, width: 48, child: rail),
        Padding(
            padding: const EdgeInsets.only(left: 62),
            child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: content)),
      ]);
}

/// Weeks 2 and 4: paid for by the fee.
class _IncludedTag extends StatelessWidget {
  const _IncludedTag();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: _handover, borderRadius: BorderRadius.circular(20)),
      child: const Text('Included in the price',
          style: TextStyle(
              color: circleNavy, fontSize: 11, fontWeight: FontWeight.w800)));
}

class _NextTag extends StatelessWidget {
  const _NextTag();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: const Text('Next',
          style: TextStyle(
              color: circleNavy, fontSize: 11, fontWeight: FontWeight.w800)));
}

class CircleStoryCard extends StatelessWidget {
  const CircleStoryCard({super.key, required this.index, this.compact = false});
  final int index;

  /// On a phone: the picture beside the words, so three cards don't take
  /// three screens.
  final bool compact;
  @override
  Widget build(BuildContext context) {
    const backgrounds = [
      Color(0xFFDFEEE7),
      Color(0xFFF8DDCD),
      Color(0xFFFBEED3)
    ];
    const titles = [
      'People who fit.',
      'Same faces. Every week.',
      'Friends beyond week six.'
    ];
    const captions = [
      'A shared language. A time that works.',
      'We plan and book. You show up.',
      'Keep the chat. Make your own plans.'
    ];
    final words = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(titles[index],
              style: compact
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(captions[index],
              style: const TextStyle(color: Color(0xFF4F5D66), height: 1.4)),
        ]);
    return Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 16 : 24),
        decoration: BoxDecoration(
            color: backgrounds[index],
            borderRadius: BorderRadius.circular(compact ? 22 : 28)),
        child: compact
            ? Row(children: [
                // The drawing has a fixed size; scaled down to fit here.
                SizedBox(
                    width: 96,
                    height: 80,
                    child: FittedBox(
                        child: SizedBox(
                            width: 176,
                            height: 140,
                            child:
                                CustomPaint(painter: _StoryPainter(index))))),
                const SizedBox(width: 14),
                Expanded(child: words),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    height: 136,
                    width: double.infinity,
                    child: CustomPaint(painter: _StoryPainter(index))),
                const SizedBox(height: 18),
                words,
              ]));
  }
}

class _StoryPainter extends CustomPainter {
  const _StoryPainter(this.scene);
  final int scene;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint();
    const colors = [
      circleNavy,
      circleTeal,
      circleCoral,
      Color(0xFFD7AB67),
      Color(0xFF8886AA),
      Color(0xFF479699)
    ];
    if (scene == 1) {
      final rect = Rect.fromCenter(center: center, width: 166, height: 118);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)),
          paint..color = Colors.white.withValues(alpha: .8));
      canvas.drawLine(
          Offset(rect.left + 12, rect.top + 30),
          Offset(rect.right - 12, rect.top + 30),
          paint
            ..color = circleCoral
            ..strokeWidth = 3);
      for (var i = 0; i < 6; i++) {
        final point = Offset(
            rect.left + 33 + (i % 3) * 50, rect.top + 54 + (i ~/ 3) * 39);
        canvas.drawCircle(point, 13, paint..color = colors[i]);
        canvas.drawLine(
            point + const Offset(-5, 0),
            point + const Offset(-1, 4),
            paint
              ..color = Colors.white
              ..strokeWidth = 2.5);
        canvas.drawLine(
            point + const Offset(-1, 4), point + const Offset(6, -5), paint);
      }
    } else {
      final path = Path();
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 - math.pi / 2;
        final point = center + Offset(math.cos(a) * 64, math.sin(a) * 46);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(
          path,
          paint
            ..color = circleTeal.withValues(alpha: .3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      paint.style = PaintingStyle.fill;
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 - math.pi / 2;
        final point = center + Offset(math.cos(a) * 64, math.sin(a) * 46);
        canvas.drawCircle(
            point, 18, paint..color = Colors.white.withValues(alpha: .8));
        canvas.drawCircle(
            point + const Offset(0, -4), 5, paint..color = colors[i]);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: point + const Offset(0, 7), width: 17, height: 11),
                const Radius.circular(6)),
            paint);
      }
      final icon = scene == 0 ? Icons.favorite_outline : Icons.all_inclusive;
      final text = TextPainter(
          text: TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(
                  fontSize: 34,
                  color: circleTealText,
                  fontFamily: icon.fontFamily)),
          textDirection: TextDirection.ltr)
        ..layout();
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(_StoryPainter oldDelegate) => oldDelegate.scene != scene;
}
