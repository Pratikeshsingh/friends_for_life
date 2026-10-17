import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'circle_widgets.dart' show circleCoral, circleNavy, circleTeal;

/// A short burst of confetti, once per [onceKey] on this device, for the
/// moments worth marking, like finishing the six weeks. Nothing when the
/// device asks for less motion, or when it can't remember it played.
class CircleConfetti extends StatefulWidget {
  const CircleConfetti({super.key, required this.onceKey});
  final String onceKey;

  @override
  State<CircleConfetti> createState() => _CircleConfettiState();
}

class _CircleConfettiState extends State<CircleConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run;
  final _pieces = List.generate(44, (i) => _Piece(Random(i * 7919)));
  bool _play = false;

  @override
  void initState() {
    super.initState();
    _run = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    _decide();
  }

  Future<void> _decide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'vriendtime.celebrated.${widget.onceKey}';
      if (prefs.getBool(key) == true) return;
      await prefs.setBool(key, true);
    } catch (_) {
      return;
    }
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    setState(() => _play = true);
    await _run.forward();
    if (mounted) setState(() => _play = false);
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_play
      ? const SizedBox.shrink()
      : IgnorePointer(
          child: ExcludeSemantics(
              child: AnimatedBuilder(
                  animation: _run,
                  builder: (context, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _ConfettiPainter(_pieces, _run.value)))));
}

class _Piece {
  _Piece(Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * .3,
        fall = .8 + r.nextDouble() * .5,
        drift = (r.nextDouble() - .5) * .12,
        spin = (r.nextDouble() - .5) * 10,
        size = 6 + r.nextDouble() * 6,
        round = r.nextBool(),
        color = const [
          circleTeal,
          circleCoral,
          circleNavy,
          Color(0xFFF2B84B),
          Color(0xFF8FD3C7),
        ][r.nextInt(5)];
  final double x, delay, fall, drift, spin, size;
  final bool round;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.progress);
  final List<_Piece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final dx = (p.x + p.drift * sin(t * pi * 3)) * size.width;
      final dy = (-0.08 + t * p.fall) * size.height;
      final paint = Paint()
        ..color = p.color.withValues(alpha: t > .75 ? (1 - t) / .25 : 1);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(t * p.spin);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2.4, paint);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset.zero, width: p.size, height: p.size * .5),
                const Radius.circular(1.5)),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
