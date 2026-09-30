import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_redirects.dart';
import 'core/i18n.dart' show LanguageScope, appLanguage;
import 'core/responsive.dart';
import 'core/theme.dart';
import 'circles/circle_shell.dart';
import 'screens/reset_password_screen.dart';

class VriendTimeApp extends StatefulWidget {
  const VriendTimeApp({super.key});

  @override
  State<VriendTimeApp> createState() => _VriendTimeAppState();
}

class _VriendTimeAppState extends State<VriendTimeApp> {
  late final ThemeData _baseTheme = buildTheme();

  @override
  Widget build(BuildContext context) {
    final isResetPasswordRoute = AuthRedirects.isPasswordResetUri(Uri.base);

    // The whole app follows the chosen language, including Flutter's own
    // widgets such as the date picker.
    return ValueListenableBuilder<String>(
        valueListenable: appLanguage,
        builder: (context, language, _) => LanguageScope(
                child: MaterialApp(
              title: 'VriendTime',
              debugShowCheckedModeBanner: false,
              theme: _baseTheme,
              locale: Locale(language),
              supportedLocales: const [Locale('en'), Locale('nl')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
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
                  final authEvent = snapshot.data?.event;
                  if (isResetPasswordRoute) {
                    return ResetPasswordScreen(
                      session: session,
                      authEvent: authEvent,
                    );
                  }
                  return CircleShell(session: session);
                },
              ),
            )));
  }
}
