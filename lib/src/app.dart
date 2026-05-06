import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/responsive.dart';
import 'core/theme.dart';
import 'screens/prototype_shell.dart';

class VriendTimeApp extends StatefulWidget {
  const VriendTimeApp({super.key});

  @override
  State<VriendTimeApp> createState() => _VriendTimeAppState();
}

class _VriendTimeAppState extends State<VriendTimeApp> {
  late final ThemeData _baseTheme = buildTheme();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VriendTime',
      debugShowCheckedModeBanner: false,
      theme: _baseTheme,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final theme = responsiveThemeForWidth(
              Theme.of(context),
              constraints.maxWidth,
            );

            return Theme(
              data: theme,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        initialData: AuthState(
          AuthChangeEvent.initialSession,
          Supabase.instance.client.auth.currentSession,
        ),
        builder: (context, snapshot) {
          final session = snapshot.data?.session;
          return PrototypeShell(session: session);
        },
      ),
    );
  }
}
