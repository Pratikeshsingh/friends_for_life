import 'dart:async';

import 'package:flutter/material.dart';
import 'brand_mark_painter.dart';

/// Warm, honest status lines that rotate while the Circle loads.
const circleLoadingPhrases = <String>[
  'Putting the kettle on…',
  'Pulling up chairs…',
  'Checking who\'s around…',
  'Finding a table in Alkmaar…',
  'Saving you a seat…',
];

/// Three people gather into the logo. Never delays completion of real work.
class CircleLoading extends StatefulWidget {
  const CircleLoading({
    super.key,
    this.label = 'Opening your Circle…',
    this.phrases = circleLoadingPhrases,
  });

  /// Stable label for screen readers, and the visible text when motion is off.
  final String label;

  /// Visible status lines, rotated while loading.
  final List<String> phrases;
  @override
  State<CircleLoading> createState() => _CircleLoadingState();
}

class _CircleLoadingState extends State<CircleLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));
  Timer? phraseTimer;
  int phraseIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      animation.stop();
      phraseTimer?.cancel();
      phraseTimer = null;
    } else {
      if (!animation.isAnimating) animation.repeat();
      if (phraseTimer == null && widget.phrases.length > 1) {
        phraseTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
          if (!mounted) return;
          setState(
              () => phraseIndex = (phraseIndex + 1) % widget.phrases.length);
        });
      }
    }
  }

  @override
  void dispose() {
    phraseTimer?.cancel();
    animation.dispose();
    super.dispose();
  }

  // Ease in, hold the completed mark, then gently separate for a seamless loop.
  double together(double t, double start, double end) {
    if (t < start) return 0;
    if (t < end) {
      return Curves.easeInOutCubic.transform((t - start) / (end - start));
    }
    if (t <= .72) return 1;
    return 1 - Curves.easeInOutCubic.transform((t - .72) / .28);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(
            child: SizedBox.square(
              dimension: 240,
              child: Center(
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (_, child) {
                    final t = animation.value;
                    final center = t < .72
                        ? ((t - .24) / .18).clamp(0.0, 1.0)
                        : (1 - (t - .72) / .18).clamp(0.0, 1.0);
                    return CustomPaint(
                      size: const Size.square(140),
                      painter: VriendTimeMarkPainter(
                        top: still ? 0 : 300 * (1 - together(t, 0, .32)),
                        left: still ? 0 : 330 * (1 - together(t, .04, .36)),
                        right: still ? 0 : 330 * (1 - together(t, .08, .40)),
                        centerOpacity:
                            still ? 1 : Curves.easeInOut.transform(center),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
                still || widget.phrases.isEmpty
                    ? widget.label
                    : widget.phrases[phraseIndex % widget.phrases.length],
                key: ValueKey(still ? -1 : phraseIndex),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF66727C),
                    )),
          ),
        ]),
      ),
    );
  }
}
