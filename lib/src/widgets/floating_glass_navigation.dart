import 'package:flutter/material.dart';
import '../core/i18n.dart' show t;

/// The three tabs along the bottom of a phone: a solid, quiet bar with a
/// clear edge, so nothing on the page sits half-hidden behind it.
class FloatingGlassNavigation extends StatelessWidget {
  const FloatingGlassNavigation({
    super.key,
    required this.height,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.circleMode = false,
    this.showMessages = true,
    this.homeLabel,
    this.messagesUnread = false,
  });

  /// A dot on the Messages tab when the Circle wrote something new.
  final bool messagesUnread;

  final bool circleMode;

  /// Circles: the chat tab only exists once someone is in a Circle. When
  /// hidden, [selectedIndex] and [onDestinationSelected] still use the
  /// three-tab numbering (0 home, 2 profile), so callers need no mapping.
  final bool showMessages;
  final String? homeLabel;
  final double height;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: t('Main navigation'),
      child: DecoratedBox(
        key: const ValueKey('floating-glass-navigation'),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCF8),
          border: Border(top: BorderSide(color: Color(0x1F062B55))),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: NavigationBar(
                height: height,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                indicatorColor: const Color(0xFFE2F1EE),
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                selectedIndex:
                    showMessages ? selectedIndex : (selectedIndex == 2 ? 1 : 0),
                onDestinationSelected: (i) =>
                    onDestinationSelected(showMessages ? i : (i == 1 ? 2 : 0)),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home_rounded),
                    label: t(homeLabel ?? (circleMode ? 'My Circle' : 'Home')),
                  ),
                  if (showMessages)
                    NavigationDestination(
                      icon: Badge(
                          isLabelVisible: messagesUnread,
                          smallSize: 9,
                          child: Icon(circleMode
                              ? Icons.chat_bubble_outline_rounded
                              : Icons.event_outlined)),
                      selectedIcon: Icon(circleMode
                          ? Icons.chat_bubble_rounded
                          : Icons.event_rounded),
                      label: t(circleMode ? 'Messages' : 'Meetups'),
                    ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person_rounded),
                    label: t('Profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
