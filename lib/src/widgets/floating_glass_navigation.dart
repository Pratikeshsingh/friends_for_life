import 'dart:ui';

import 'package:flutter/material.dart';
import '../core/i18n.dart' show t;

class FloatingGlassNavigation extends StatelessWidget {
  const FloatingGlassNavigation({
    super.key,
    required this.height,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.circleMode = false,
    this.showMessages = true,
    this.homeLabel,
  });

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
    const radius = BorderRadius.all(Radius.circular(30));

    return Semantics(
      container: true,
      label: t('Main navigation'),
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x24062B55),
                blurRadius: 26,
                offset: Offset(0, 10),
              ),
              BoxShadow(
                color: Color(0x14FFFFFF),
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: DecoratedBox(
                key: const ValueKey('floating-glass-navigation'),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xE8FFFCF8),
                      Color(0xCFF5FBF8),
                      Color(0xDCFDF8F2),
                    ],
                    stops: [0, 0.52, 1],
                  ),
                  border: Border.all(color: const Color(0xCFFFFFFF)),
                ),
                child: NavigationBar(
                  height: height,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  indicatorColor: const Color(0xCFE2F4EF),
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: const BorderSide(color: Color(0xBFFFFFFF)),
                  ),
                  selectedIndex: showMessages
                      ? selectedIndex
                      : (selectedIndex == 2 ? 1 : 0),
                  onDestinationSelected: (i) => onDestinationSelected(
                      showMessages ? i : (i == 1 ? 2 : 0)),
                  destinations: [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label:
                          t(homeLabel ?? (circleMode ? 'My Circle' : 'Home')),
                    ),
                    if (showMessages)
                      NavigationDestination(
                        icon: Icon(circleMode
                            ? Icons.chat_bubble_outline_rounded
                            : Icons.event_outlined),
                        selectedIcon: Icon(circleMode
                            ? Icons.chat_bubble_rounded
                            : Icons.event_rounded),
                        label: t(circleMode ? 'Messages' : 'Meetups'),
                      ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: t('Profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
