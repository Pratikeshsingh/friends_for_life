import 'package:flutter/material.dart';

import 'brand_logo.dart';

class AppShellHeader extends StatelessWidget {
  const AppShellHeader({
    super.key,
    required this.onOpenNotifications,
    required this.unreadCount,
    this.logoSize = 42,
    this.foregroundColor = const Color(0xFF062B55),
  });

  final VoidCallback onOpenNotifications;
  final int unreadCount;
  final double logoSize;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BrandLockup(
            logoSize: logoSize,
            foregroundColor: foregroundColor,
          ),
        ),
        const SizedBox(width: 12),
        _NotificationBellButton(
          unreadCount: unreadCount,
          onTap: onOpenNotifications,
        ),
      ],
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = unreadCount > 99 ? '99+' : '$unreadCount';
    final semanticLabel = unreadCount > 0
        ? 'Open notifications, $badgeLabel unread'
        : 'Open notifications';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Material(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFDDE7E3)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onTap,
                    child: const ExcludeSemantics(
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xFF062B55),
                      ),
                    ),
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: ExcludeSemantics(
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 22),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD85F4D),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
