import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_redirects.dart';
import '../core/i18n.dart';
import '../core/responsive.dart';
import '../widgets/brand_logo.dart';
import '../core/image_assets.dart';
import '../widgets/motion.dart';
import '../widgets/section_card.dart';
import 'legal_document_screen.dart';

enum _AccountMode { signIn, signUp }

/// Sign up and sign in for Friendship Circles. Everything after creating
/// an account (the application, photo and times) happens in the Circle app.
class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({
    super.key,
    this.onUserUpdated,
    this.onClose,
    this.startInSignIn = false,
    this.presentedAsModal = false,
    this.supabaseClient,
  });

  final ValueChanged<User>? onUserUpdated;
  final VoidCallback? onClose;
  final bool startInSignIn;

  /// Shown inside a dialog rather than as a page, so the leading control
  /// closes the dialog instead of navigating back.
  final bool presentedAsModal;
  final SupabaseClient? supabaseClient;

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  final _scrollController = ScrollController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();

  _AccountMode _accountMode = _AccountMode.signUp;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _hasAcceptedLegal = false;
  String? _statusMessage;
  bool _awaitingConfirmation = false;
  DateTime? _resendAvailableAt;

  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  bool get _isAccessStepValid {
    if (_accountMode == _AccountMode.signIn) {
      return _looksLikeEmail(_emailController.text) &&
          _passwordController.text.trim().isNotEmpty;
    }

    return _firstNameController.text.trim().isNotEmpty &&
        _looksLikeEmail(_emailController.text) &&
        _passwordController.text.trim().length >= 6 &&
        _passwordController.text == _confirmPasswordController.text &&
        _hasAcceptedLegal;
  }

  String? get _emailValidationMessage {
    final email = _emailController.text.trim();
    if (email.isEmpty) return null;
    if (!_looksLikeEmail(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? get _passwordValidationMessage {
    final password = _passwordController.text;
    if (password.isEmpty || _accountMode == _AccountMode.signIn) return null;
    return password.length < 6 ? 'Use at least six characters.' : null;
  }

  String? get _confirmPasswordValidationMessage {
    if (_accountMode == _AccountMode.signIn) return null;
    final confirm = _confirmPasswordController.text;
    if (confirm.isEmpty) return null;
    return confirm != _passwordController.text
        ? 'Passwords do not match yet.'
        : null;
  }

  @override
  void initState() {
    super.initState();
    _accountMode =
        widget.startInSignIn ? _AccountMode.signIn : _AccountMode.signUp;
    _emailController.addListener(_refreshValidation);
    _passwordController.addListener(_refreshValidation);
    // A new attempt is being typed: the old "does not match" message must
    // not sit there as if it were about what is in the field now.
    _emailController.addListener(_clearStaleError);
    _passwordController.addListener(_clearStaleError);
    _confirmPasswordController.addListener(_refreshValidation);
    _firstNameController.addListener(_refreshValidation);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 700;
    final signIn = _accountMode == _AccountMode.signIn;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _AccessImmersiveBackground(
              compact: compact,
              semanticLabel: t('A welcoming cafe table waiting for guests'),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final horizontal = responsiveHorizontalPadding(width);
                final maxWidth = responsiveContentMaxWidth(width);

                return SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MotionReveal(
                            index: 0,
                            child: _OnboardingTopBar(
                              canNavigateBack: widget.onClose != null,
                              onBack: () => widget.onClose?.call(),
                              isModal: widget.presentedAsModal,
                            ),
                          ),
                          const SizedBox(height: 36),
                          MotionReveal(
                            index: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  signIn
                                      ? 'Welcome back'
                                      : 'Create your account',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                          color: const Color(0xFF062B55)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  signIn
                                      ? 'Sign in to see what’s next.'
                                      : 'Takes a minute. After this, four short questions about you, your week and your kind of company, plus a photo so your group can recognise you. No payment.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                      color: const Color(0xFF60727A)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildAccessStep(theme),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessStep(ThemeData theme) {
    final isSignUp = _accountMode == _AccountMode.signUp;

    return SectionCard(
      key: const ValueKey('auth-access-form'),
      motionIndex: 4,
      enableReveal: false,
      backgroundColor: const Color(0xE6FFFDF9),
      borderColor: const Color(0x99D9E8E2),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_awaitingConfirmation) ...[
              const Text('Check your email',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text(
                  'Open the confirmation link, then sign in. Check spam too. You can correct the email below if needed.'),
              TextButton(
                  onPressed: _isSubmitting ? null : _resendConfirmation,
                  child: const Text('Resend confirmation email')),
            ],
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F5F3),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFD5E5E2)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<_AccountMode>(
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                      ),
                      segments: const [
                        ButtonSegment(
                          value: _AccountMode.signUp,
                          label: FittedBox(child: Text('Sign up')),
                        ),
                        ButtonSegment(
                          value: _AccountMode.signIn,
                          label: FittedBox(child: Text('Sign in')),
                        ),
                      ],
                      selected: {_accountMode},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _accountMode = selection.first;
                          _statusMessage = null;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            if (isSignUp) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final firstNameField = TextField(
                    controller: _firstNameController,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.givenName],
                    decoration: InputDecoration(
                      labelText: t('First name'),
                      hintText: t('e.g. Sanne'),
                    ),
                  );

                  // Circles only ever use a first name.
                  return firstNameField;
                },
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: t('Email'),
                hintText: t('e.g. you@example.com'),
              ),
            ),
            if (_emailValidationMessage != null) ...[
              const SizedBox(height: 8),
              _InlineValidation(message: _emailValidationMessage!),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction:
                  isSignUp ? TextInputAction.next : TextInputAction.done,
              autofillHints: [
                isSignUp ? AutofillHints.newPassword : AutofillHints.password,
              ],
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) {
                if (!isSignUp && !_isSubmitting && _isAccessStepValid) {
                  unawaited(_signIn());
                }
              },
              decoration: InputDecoration(
                labelText: t('Password'),
                hintText:
                    isSignUp ? 'Create a password' : 'Enter your password',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  tooltip:
                      t(_obscurePassword ? 'Show password' : 'Hide password'),
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                ),
              ),
            ),
            if (_passwordValidationMessage != null) ...[
              const SizedBox(height: 8),
              _InlineValidation(message: _passwordValidationMessage!),
            ],
            if (!isSignUp) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSubmitting ? null : _sendPasswordResetEmail,
                  child: const Text('Forgot password?'),
                ),
              ),
            ],
            if (isSignUp) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) {
                  if (!_isSubmitting && _isAccessStepValid) {
                    _checkSignUpAccess();
                  }
                },
                decoration: InputDecoration(
                  labelText: t('Confirm password'),
                  hintText: t('Same password again'),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                    tooltip: _obscureConfirmPassword
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(_obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                  ),
                ),
              ),
              if (_confirmPasswordValidationMessage != null) ...[
                const SizedBox(height: 8),
                _InlineValidation(message: _confirmPasswordValidationMessage!),
              ],
              const SizedBox(height: 14),
              _LegalConsentField(
                value: _hasAcceptedLegal,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _hasAcceptedLegal = value;
                          _statusMessage = null;
                        });
                      },
                onOpenTerms: () => _openLegalDocument(LegalDocumentType.terms),
                onOpenPrivacy: () =>
                    _openLegalDocument(LegalDocumentType.privacy),
              ),
            ],
            const SizedBox(height: 16),
            if (_statusMessage != null) ...[
              _OnboardingStatusNotice(message: _statusMessage!),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting || !_isAccessStepValid
                    ? null
                    : isSignUp
                        ? _checkSignUpAccess
                        : _signIn,
                child: Text(
                  _isSubmitting
                      ? (isSignUp
                          ? 'Pulling up a chair for you…'
                          : 'Welcoming you back…')
                      : (isSignUp ? 'Create account' : 'Sign in'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resendConfirmation() async {
    if (!_looksLikeEmail(_emailController.text)) {
      _setStatus('Enter a valid email address.');
      return;
    }
    if (_resendAvailableAt?.isAfter(DateTime.now()) == true) {
      _setStatus('Please wait a minute before requesting another email.');
      return;
    }
    await _runAuthAction(() async {
      await _supabase.auth.resend(
          type: OtpType.signup,
          email: _emailController.text.trim(),
          emailRedirectTo: AuthRedirects.emailRedirectTo);
      _resendAvailableAt = DateTime.now().add(const Duration(minutes: 1));
      if (mounted) {
        _setStatus(
            'If this address has an unconfirmed account, we’ve sent a new confirmation link.');
      }
    });
  }

  Future<void> _checkSignUpAccess() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (_firstNameController.text.trim().isEmpty) {
      _setStatus('Add your first name to continue.');
      return;
    }
    if (!_looksLikeEmail(_emailController.text)) {
      _setStatus('Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      _setStatus('Use a password with at least six characters.');
      return;
    }
    if (password != confirmPassword) {
      _setStatus('Your passwords do not match yet.');
      return;
    }
    if (!_hasAcceptedLegal) {
      _setStatus(
        'Agree to the Terms & Conditions and acknowledge the Privacy Policy to create an account.',
      );
      return;
    }

    await _runAuthAction(() async {
      final acceptedAt = DateTime.now().toUtc().toIso8601String();
      final response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        emailRedirectTo: AuthRedirects.emailRedirectTo,
        data: {
          'first_name': _firstNameController.text.trim(),
          'terms_accepted_at': acceptedAt,
          'terms_version': LegalDocuments.termsVersion,
          'privacy_acknowledged_at': acceptedAt,
          'privacy_version': LegalDocuments.privacyVersion,
        },
      );

      final session = response.session;
      if (!mounted) return;

      if (session == null) {
        setState(() {
          _awaitingConfirmation = true;
          _accountMode = _AccountMode.signIn;
          _statusMessage =
              'Account created. Confirm your email, then sign in to finish setup.';
        });
        return;
      }

      await _ensureProfileForUser(response.user);
      if (!mounted) return;

      setState(() => _statusMessage = null);
      widget.onClose?.call();
    });
  }

  Future<void> _openLegalDocument(LegalDocumentType type) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(type: type),
      ),
    );
  }

  Future<void> _signIn() async {
    if (!_looksLikeEmail(_emailController.text)) {
      _setStatus('Enter a valid email address.');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _setStatus('Enter your password to continue.');
      return;
    }

    final succeeded = await _runAuthAction(() async {
      final AuthResponse response;
      try {
        response = await _supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } on AuthException catch (error) {
        // Not confirmed yet (perhaps the link expired): offer a new link.
        if (error.code == 'email_not_confirmed' ||
            error.message.toLowerCase().contains('email not confirmed')) {
          if (mounted) setState(() => _awaitingConfirmation = true);
        }
        rethrow;
      }
      await _ensureProfileForUser(response.user);
      final signedInUser = response.user;
      if (signedInUser != null) {
        widget.onUserUpdated?.call(signedInUser);
      }
    });

    // On web, submitting puts this AutofillGroup's DOM <form> to sleep parked
    // off-screen, and the next focus reuses it there — so after a failed
    // attempt the password field looks focused but the input actually taking
    // keystrokes is at -9999px, and edits are silently lost. (Switching to
    // sign-up and back used to be the only escape, because that rebuilds the
    // fields under new autofill ids.) Tearing the context down returns a
    // fresh, correctly placed form on the next tap. shouldSave: false so the
    // browser is never offered the password that just failed.
    if (!succeeded && mounted && kIsWeb) {
      TextInput.finishAutofillContext(shouldSave: false);
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();

    if (!_looksLikeEmail(email)) {
      _setStatus('Enter your email first, then tap forgot password.');
      return;
    }

    await _runAuthAction(() async {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: AuthRedirects.passwordResetRedirectTo,
      );
      if (!mounted) return;
      _setStatus(
          'Password reset email sent. Check your inbox for the reset link.');
    });
  }

  Future<bool> _runAuthAction(Future<void> Function() action) async {
    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    var succeeded = true;
    try {
      await action();
    } on AuthException catch (error) {
      succeeded = false;
      if (!mounted) return false;
      _setStatus(_friendlyAuthMessage(error));
    } catch (_) {
      succeeded = false;
      if (!mounted) return false;
      _setStatus(
          'We could not finish setup. Check your connection and try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
    return succeeded;
  }

  Future<void> _ensureProfileForUser(User? user) async {
    if (user == null) return;

    final metadata = user.userMetadata ?? const <String, dynamic>{};

    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'first_name': metadata['first_name'],
        // Only create a missing row; never overwrite an existing profile.
        // The Circle app keeps the photo and birthday on the profile itself,
        // so overwriting here used to erase them on every sign-in.
      }, onConflict: 'id', ignoreDuplicates: true);
    } catch (_) {
      // If the schema hasn't been applied yet, auth should still work.
    }
  }

  String _friendlyAuthMessage(AuthException error) {
    final message = error.message.toLowerCase();

    // A request that never reached the server is not the member's fault;
    // pointing them at their email and password would send them hunting
    // for a typo that is not there.
    if (error is AuthRetryableFetchException ||
        message.contains('failed to fetch') ||
        message.contains('clientexception') ||
        message.contains('socketexception') ||
        message.contains('network') ||
        message.contains('timed out') ||
        message.contains('timeout')) {
      return 'We couldn’t reach VriendTime. Check your connection and try again.';
    }
    // The one-minute wait between emails to the same address.
    if (message.contains('for security purposes')) {
      return 'Please wait a minute before requesting another email.';
    }
    // Too many emails or attempts across everyone in a short time.
    if (error.statusCode == '429' || message.contains('rate limit')) {
      return 'Many people are signing up right now. Please try again in a few minutes.';
    }

    if (message.contains('invalid login credentials')) {
      return 'That email and password do not match our records. Check for typos or create an account first.';
    }
    if (message.contains('email not confirmed')) {
      return 'Confirm your email first, then come back to sign in.';
    }
    if (message.contains('user already registered')) {
      return 'If you already have an account, switch to sign in. Otherwise, check your email and try again.';
    }
    if (message.contains('redirect') &&
        (message.contains('not allowed') ||
            message.contains('invalid') ||
            message.contains('mismatch'))) {
      return 'Email links are not configured correctly yet. Add vriendtime://auth/callback to the Supabase redirect URLs, then try again.';
    }
    if (message.contains('signup') && message.contains('18')) {
      return 'Members need to be at least 18 years old to join.';
    }
    return 'We could not complete that. Check your details and try again.';
  }

  bool _looksLikeEmail(String value) {
    final email = value.trim();
    return email.contains('@') && email.contains('.');
  }

  void _setStatus(String message) {
    setState(() => _statusMessage = message);
  }

  String? _lastEmail, _lastPassword;
  void _clearStaleError() {
    final changed = _emailController.text != _lastEmail ||
        _passwordController.text != _lastPassword;
    _lastEmail = _emailController.text;
    _lastPassword = _passwordController.text;
    if (changed && !_isSubmitting && _statusMessage != null && mounted) {
      setState(() => _statusMessage = null);
    }
  }

  void _refreshValidation() {
    if (!mounted) return;
    setState(() {});
  }
}

class _AccessImmersiveBackground extends StatelessWidget {
  const _AccessImmersiveBackground({
    required this.compact,
    required this.semanticLabel,
  });

  final bool compact;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      compact
          ? GeneratedImageAssets.landingImmersiveMobile
          : GeneratedImageAssets.onboardingAccountImmersive,
      fit: compact ? BoxFit.fitWidth : BoxFit.cover,
      alignment: compact ? Alignment.bottomCenter : Alignment.center,
      cacheWidth: compact ? 900 : 1600,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
    );
    final wash = compact
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xF7FFFCF7),
              Color(0xEDFFFCF7),
              Color(0xC8FFFCF7),
              Color(0x78FFFCF7),
              Color(0xA8FFFCF7),
            ],
            stops: [0, 0.22, 0.46, 0.74, 1],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xEFFFFCF7),
              Color(0xA8FFFCF7),
              Color(0x42FFFCF7),
              Color(0x92FFFCF7),
              Color(0xE6FFFCF7),
            ],
            stops: [0, 0.2, 0.43, 0.76, 1],
          );

    return KeyedSubtree(
      key: const ValueKey('auth-access-background'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFFFFCF7)),
          image,
          DecoratedBox(decoration: BoxDecoration(gradient: wash)),
          if (!compact)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xE8FFFCF7), Color(0x10FFFCF7)],
                  stops: [0, 0.58],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegalConsentField extends StatelessWidget {
  const _LegalConsentField({
    required this.value,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: t(
          'Agreement to the Terms and Conditions and acknowledgement of the Privacy Policy'),
      child: Container(
        key: const ValueKey('legal-consent-field'),
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? const Color(0xFF8BCBC1) : const Color(0xFFD5E5E2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              key: const ValueKey('legal-consent-checkbox'),
              value: value,
              onChanged: onChanged == null
                  ? null
                  : (nextValue) => onChanged!(nextValue ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'I agree to the ',
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      key: const ValueKey('open-terms'),
                      onPressed: onOpenTerms,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Terms & Conditions'),
                    ),
                    Text(
                      ' and acknowledge that I have read the ',
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      key: const ValueKey('open-privacy-policy'),
                      onPressed: onOpenPrivacy,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Privacy Policy.'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStatusNotice extends StatelessWidget {
  const _OnboardingStatusNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7F5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFB9E3DC)),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF062B55),
              ),
        ),
      ),
    );
  }
}

class _InlineValidation extends StatelessWidget {
  const _InlineValidation({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFA54F33);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({
    required this.canNavigateBack,
    required this.onBack,
    this.isModal = false,
  });

  final bool canNavigateBack;
  final VoidCallback onBack;

  /// In a dialog the leading control becomes a close affordance on the
  /// right, where people look for it, rather than a back arrow.
  final bool isModal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: canNavigateBack && !isModal
                ? IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: t('Back'),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.92),
                      foregroundColor: const Color(0xFF062B55),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Center(
              child: BrandLockup(
                logoSize: 42,
                foregroundColor: theme.colorScheme.onSurface,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            height: 52,
            child: isModal
                ? IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: t('Close'),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.92),
                      foregroundColor: const Color(0xFF062B55),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
