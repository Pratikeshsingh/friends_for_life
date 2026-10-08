import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth_redirects.dart';
import '../core/responsive.dart';
import '../widgets/brand_logo.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.session,
    required this.authEvent,
  });

  final Session? session;
  final AuthChangeEvent? authEvent;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _statusMessage;

  bool get _hasRecoverySession =>
      widget.session != null ||
      Supabase.instance.client.auth.currentSession != null ||
      widget.authEvent == AuthChangeEvent.passwordRecovery;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFCF7),
              Color(0xFFEAF7F5),
              Color(0xFFF7ECE4),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal =
                  responsiveHorizontalPadding(constraints.maxWidth);

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF7),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFDDE7E3)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const BrandLockup(
                                logoSize: 44,
                                foregroundColor: Color(0xFF062B55)),
                            const SizedBox(height: 20),
                            Text(
                              _isSuccess
                                  ? 'Password updated'
                                  : 'Reset your password',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isSuccess
                                  ? 'Your password has been changed. You can go back to VriendTime and sign in with the new one.'
                                  : _hasRecoverySession
                                      ? 'Choose a new password for your account.'
                                      : 'This reset link is not active yet or may have expired. Open the latest email and try again.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 20),
                            if (_statusMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF7F5),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFB9E3DC),
                                  ),
                                ),
                                child: Text(
                                  _statusMessage!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF062B55),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_isSuccess) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _openApp,
                                  child: const Text('Open VriendTime'),
                                ),
                              ),
                            ] else if (_hasRecoverySession) ...[
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: t('New password'),
                                  hintText: t('Choose a new password'),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: t('Confirm password'),
                                  hintText: t('Type it again'),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                    tooltip: _obscureConfirmPassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  child: Text(
                                    _isSubmitting
                                        ? 'Securing your account…'
                                        : 'Update password',
                                  ),
                                ),
                              ),
                            ] else ...[
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _openApp,
                                  child: const Text('Back to VriendTime'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.length < 8) {
      setState(() => _statusMessage = 'Use at least eight characters.');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _statusMessage = 'Passwords do not match yet.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      await auth.updateUser(UserAttributes(password: password));
      // A new password should lock out anyone else: end every other
      // signed-in session. Best effort — the password itself is changed.
      try {
        await auth.signOut(scope: SignOutScope.others);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _isSuccess = true);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _statusMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _statusMessage =
            'Password update failed. Check the link or try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openApp() async {
    await launchUrl(
      Uri.parse(AuthRedirects.webAppUrl),
      mode: LaunchMode.platformDefault,
    );
  }
}
