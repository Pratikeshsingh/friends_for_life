import 'package:flutter/material.dart';

class BrandAssets {
  const BrandAssets._();

  static const logo = 'assets/brand/vriendtime-logo.png';
}

class BrandLogoMark extends StatelessWidget {
  const BrandLogoMark({
    super.key,
    this.size = 64,
    this.radius = 18,
  });

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        BrandAssets.logo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Text(
              'VT',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          );
        },
      ),
    );
  }
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
        BrandLogoMark(size: logoSize, radius: logoSize * 0.24),
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
