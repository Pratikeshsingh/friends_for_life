import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

bool prefersReducedMotion(BuildContext context) {
  return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

class MotionReveal extends StatefulWidget {
  const MotionReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 560),
    this.offset = const Offset(0, 0.05),
    this.beginScale = 0.985,
  });

  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double beginScale;

  @override
  State<MotionReveal> createState() => _MotionRevealState();
}

class _MotionRevealState extends State<MotionReveal> {
  bool _visible = false;
  bool _scheduled = false;
  bool _frameCheckQueued = false;
  Timer? _timer;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final reduceMotion = prefersReducedMotion(context);
    if (reduceMotion) {
      _visible = true;
      return;
    }

    final scrollable = Scrollable.maybeOf(context);
    final nextPosition = scrollable?.position;
    if (_position != nextPosition) {
      _position?.removeListener(_checkVisibility);
      _position = nextPosition;
      _position?.addListener(_checkVisibility);
    }

    _queueFrameCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _position?.removeListener(_checkVisibility);
    super.dispose();
  }

  void _queueFrameCheck() {
    if (_frameCheckQueued || !mounted) return;
    _frameCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameCheckQueued = false;
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (!mounted || _visible || _scheduled) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      _queueFrameCheck();
      return;
    }

    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) {
      _scheduleReveal();
      return;
    }

    final position = _position;
    if (position == null || !position.hasPixels) {
      _scheduleReveal();
      return;
    }

    final revealOffset = viewport.getOffsetToReveal(renderObject, 0.08).offset;
    final viewportExtent = position.viewportDimension;
    final currentOffset = position.pixels;
    final entersSoon = revealOffset < currentOffset + viewportExtent * 0.92;
    final notFarAbove =
        revealOffset + renderObject.size.height > currentOffset - 80;

    if (entersSoon && notFarAbove) {
      _scheduleReveal();
    }
  }

  void _scheduleReveal() {
    if (_scheduled || _visible) return;
    _scheduled = true;

    final staggerDelay = Duration(milliseconds: widget.index * 60);
    _timer = Timer(widget.delay + staggerDelay, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) {
      return widget.child;
    }

    return AnimatedSlide(
      offset: _visible ? Offset.zero : widget.offset,
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: _visible ? 1 : widget.beginScale,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class MotionPressable extends StatefulWidget {
  const MotionPressable({
    super.key,
    required this.child,
    this.hoverScale = 1.006,
    this.pressedScale = 0.992,
    this.duration = const Duration(milliseconds: 180),
  });

  final Widget child;
  final double hoverScale;
  final double pressedScale;
  final Duration duration;

  @override
  State<MotionPressable> createState() => _MotionPressableState();
}

class _MotionPressableState extends State<MotionPressable> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) {
      return widget.child;
    }

    final scale = _pressed
        ? widget.pressedScale
        : _hovered
            ? widget.hoverScale
            : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        behavior: HitTestBehavior.deferToChild,
        child: AnimatedScale(
          scale: scale,
          alignment: Alignment.center,
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class MotionFloat extends StatefulWidget {
  const MotionFloat({
    super.key,
    required this.child,
    this.amplitude = 5,
    this.duration = const Duration(milliseconds: 4200),
  });

  final Widget child;
  final double amplitude;
  final Duration duration;

  @override
  State<MotionFloat> createState() => _MotionFloatState();
}

class _MotionFloatState extends State<MotionFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final eased = Curves.easeInOutCubic.transform(_controller.value);
        final offset = (eased - 0.5) * widget.amplitude;
        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
    );
  }
}

class MotionParallax extends StatelessWidget {
  const MotionParallax({
    super.key,
    required this.child,
    this.scrollController,
    this.scrollOffset = 0,
    this.speed = 0.12,
    this.maxShift = 28,
    this.maxScaleDrop = 0.035,
  });

  final Widget child;
  final ScrollController? scrollController;
  final double scrollOffset;
  final double speed;
  final double maxShift;
  final double maxScaleDrop;

  @override
  Widget build(BuildContext context) {
    if (prefersReducedMotion(context)) {
      return child;
    }

    final controller = scrollController;
    if (controller == null) {
      return _ParallaxTransform(
        scrollOffset: scrollOffset,
        speed: speed,
        maxShift: maxShift,
        maxScaleDrop: maxScaleDrop,
        child: child,
      );
    }

    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final currentOffset = controller.hasClients ? controller.offset : 0.0;
        return _ParallaxTransform(
          scrollOffset: currentOffset,
          speed: speed,
          maxShift: maxShift,
          maxScaleDrop: maxScaleDrop,
          child: child!,
        );
      },
    );
  }
}

class _ParallaxTransform extends StatelessWidget {
  const _ParallaxTransform({
    required this.scrollOffset,
    required this.speed,
    required this.maxShift,
    required this.maxScaleDrop,
    required this.child,
  });

  final double scrollOffset;
  final double speed;
  final double maxShift;
  final double maxScaleDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shift = (-scrollOffset * speed).clamp(-maxShift, 0.0);
    final progress = (scrollOffset / 280).clamp(0.0, 1.0);
    final scale = 1 - (progress * maxScaleDrop);
    final opacity = 1 - (progress * 0.08);

    return Transform.translate(
      offset: Offset(0, shift),
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: Opacity(
          opacity: opacity,
          child: child,
        ),
      ),
    );
  }
}
