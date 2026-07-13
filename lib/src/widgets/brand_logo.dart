import 'package:flutter/material.dart';

class BrandLogoMark extends StatelessWidget {
  const BrandLogoMark({
    super.key,
    this.size = 64,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'VriendTime',
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(
          painter: _VriendTimeMarkPainter(),
        ),
      ),
    );
  }
}

class _VriendTimeMarkPainter extends CustomPainter {
  const _VriendTimeMarkPainter();

  static const _navy = Color(0xFF062B55);
  static const _teal = Color(0xFF29B8AA);
  static const _coral = Color(0xFFFF7759);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 512;
    final horizontalOffset = (size.width - (512 * scale)) / 2;
    final verticalOffset = (size.height - (512 * scale)) / 2;

    canvas
      ..save()
      ..translate(horizontalOffset, verticalOffset)
      ..scale(scale);

    canvas
      ..drawCircle(const Offset(154, 116), 39, Paint()..color = _navy)
      ..drawCircle(const Offset(358, 116), 39, Paint()..color = _teal)
      ..drawPath(
        Path()
          ..moveTo(88, 410)
          ..cubicTo(86, 330, 96, 250, 164, 211)
          ..cubicTo(188, 197, 218, 199, 233, 220)
          ..cubicTo(248, 242, 239, 268, 216, 279)
          ..cubicTo(180, 296, 164, 335, 170, 410)
          ..close(),
        Paint()..color = _navy,
      )
      ..drawPath(
        Path()
          ..moveTo(424, 410)
          ..cubicTo(426, 330, 416, 250, 348, 211)
          ..cubicTo(324, 197, 294, 199, 279, 220)
          ..cubicTo(264, 242, 273, 268, 296, 279)
          ..cubicTo(332, 296, 348, 335, 342, 410)
          ..close(),
        Paint()..color = _teal,
      );

    final navyArm = Paint()
      ..color = _navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    final tealArm = Paint()
      ..color = _teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawLine(const Offset(184, 260), const Offset(225, 300), navyArm)
      ..drawLine(const Offset(328, 260), const Offset(287, 300), tealArm);

    final coral = Paint()..color = _coral;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(194, 292, 124, 38),
          const Radius.circular(19),
        ),
        coral,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(246, 322, 20, 84),
          const Radius.circular(10),
        ),
        coral,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(216, 396, 80, 22),
          const Radius.circular(11),
        ),
        coral,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _VriendTimeMarkPainter oldDelegate) => false;
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.logoSize = 62,
    this.foregroundColor = Colors.white,
  });

  final double logoSize;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: BrandLogoMark(size: logoSize)),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            'VriendTime',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
          ),
        ),
      ],
    );
  }
}
