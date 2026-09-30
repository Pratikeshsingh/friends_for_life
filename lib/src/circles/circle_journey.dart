import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import 'circle_repository.dart' show circleWeekTitles, circleWeekShort;
import 'circle_widgets.dart';

/// An illustration of the programme, never a representation of actual members.
class CircleJourney extends StatefulWidget {
  const CircleJourney({super.key, this.compact = false});
  final bool compact;
  @override
  State<CircleJourney> createState() => _CircleJourneyState();
}

class _CircleJourneyState extends State<CircleJourney> {
  int week = 0;
  static const titles = circleWeekTitles;
  static const captions = circleWeekShort;
  static const icons = [
    Icons.restaurant_rounded,
    Icons.local_activity_rounded,
    Icons.park_rounded,
    Icons.lightbulb_outline_rounded,
    Icons.calendar_month_rounded,
    Icons.favorite_rounded
  ];
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(widget.compact ? 22 : 28),
        decoration: BoxDecoration(
            color: circleNavy, borderRadius: BorderRadius.circular(30)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SAME PEOPLE. SIX WEEKS.',
              style: TextStyle(
                  color: Color(0xFF92DACE),
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 22),
          Row(children: [
            for (var i = 0; i < 6; i++)
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                          selected: week == i,
                          label: t('Week ${i + 1}'),
                          button: true,
                          child: InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: () => setState(() => week = i),
                              child: AnimatedContainer(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 220),
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: week == i
                                          ? circleCoral
                                          : Colors.white.withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(24)),
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          color: week == i
                                              ? circleNavy
                                              : Colors.white,
                                          fontWeight: FontWeight.w800)))))))
          ]),
          const SizedBox(height: 24),
          AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              child: Row(
                  key: ValueKey(week),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                            color: const Color(0xFFF8D9B5),
                            borderRadius: BorderRadius.circular(18)),
                        child: Icon(icons[week], color: circleNavy, size: 28)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(titles[week],
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(color: Colors.white)),
                          const SizedBox(height: 6),
                          Text(captions[week],
                              style: const TextStyle(
                                  color: Color(0xFFDCE9ED), height: 1.5)),
                        ])),
                  ])),
          const SizedBox(height: 16),
          const Text(
              'Tap a week to see the plan. We plan weeks 1 to 3. From week 4, your group plans together.',
              style: TextStyle(
                  color: Color(0xFFDCE9ED), fontSize: 13, height: 1.45)),
        ]),
      );
}

class CircleStoryCard extends StatelessWidget {
  const CircleStoryCard({super.key, required this.index});
  final int index;
  @override
  Widget build(BuildContext context) {
    const backgrounds = [
      Color(0xFFDFEEE7),
      Color(0xFFF8DDCD),
      Color(0xFFE6E2F2)
    ];
    const titles = [
      'People who fit.',
      'Same faces. Every week.',
      'Friends beyond week six.'
    ];
    const captions = [
      'A shared language. A time that works.',
      'We plan the start. You show up.',
      'Keep the chat. Make your own plans.'
    ];
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: backgrounds[index], borderRadius: BorderRadius.circular(28)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              height: 136,
              width: double.infinity,
              child: CustomPaint(painter: _StoryPainter(index))),
          const SizedBox(height: 18),
          Text(titles[index], style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(captions[index]),
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
                  color: circleTeal,
                  fontFamily: icon.fontFamily)),
          textDirection: TextDirection.ltr)
        ..layout();
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(_StoryPainter oldDelegate) => oldDelegate.scene != scene;
}
