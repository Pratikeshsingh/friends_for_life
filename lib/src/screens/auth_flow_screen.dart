import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/city_service.dart';
import '../core/destructive.dart';
import '../core/event_catalog.dart';
import '../core/event_service.dart';
import '../core/auth_redirects.dart';
import '../core/responsive.dart';
import '../widgets/brand_logo.dart';
import '../widgets/continuous_immersive_scene.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/meetup_explorer_tile.dart';
import '../widgets/meetup_media.dart';
import '../widgets/motion.dart';
import '../widgets/option_picker_sheet.dart';
import '../widgets/section_card.dart';
import '../widgets/selection_field.dart';
import 'legal_document_screen.dart';

enum _AuthStage { access, details, recommendations, complete }

enum _AccountMode { signIn, signUp }

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({
    super.key,
    this.existingUser,
    this.onUserUpdated,
    this.onClose,
    this.startInSignIn = false,
    this.circleMode = false,
    this.presentedAsModal = false,
    this.supabaseClient,
    this.initialEvents,
    this.initialCityOptions,
  });

  final User? existingUser;
  final ValueChanged<User>? onUserUpdated;
  final VoidCallback? onClose;
  final bool startInSignIn;
  final bool circleMode;

  /// Shown inside a dialog rather than as a page, so the leading control
  /// closes the dialog instead of navigating back.
  final bool presentedAsModal;
  final SupabaseClient? supabaseClient;
  final List<MeetupEvent>? initialEvents;
  final List<String>? initialCityOptions;

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  final _scrollController = ScrollController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _conversationGoalsController = TextEditingController();
  final _dietaryNotesController = TextEditingController();

  _AccountMode _accountMode = _AccountMode.signUp;
  _AuthStage _stage = _AuthStage.access;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _hasAcceptedLegal = false;
  String? _statusMessage;

  String? _selectedCity;
  DateTime? _selectedBirthDate;
  String? _selectedGender;
  String? _selectedLanguage = 'English';
  String? _selectedAvailability;
  String? _selectedEnergy;
  String? _selectedGroupPreference;

  final Set<String> _selectedInterests = <String>{};
  final Set<String> _selectedEventIds = <String>{};
  List<MeetupEvent> _availableEvents = const <MeetupEvent>[];
  bool _eventLoadFailed = false;
  List<String> _cityOptions = const <String>[];
  static const _genderOptions = [
    'Woman',
    'Man',
    'Non-binary',
    'Prefer not to say'
  ];
  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  List<MeetupEvent> get _allOptions =>
      [..._availableEvents]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  User? get _signedInUser => _supabase.auth.currentUser ?? widget.existingUser;

  bool get _detailsReady =>
      _selectedCity?.trim().isNotEmpty == true &&
      _selectedBirthDate != null &&
      _underAgeErrorMessage() == null;

  bool get _canNavigateBack =>
      widget.onClose != null || _stage != _AuthStage.access;
  bool get _showsOnboardingProgress =>
      !widget.circleMode &&
      _stage != _AuthStage.complete &&
      !(_stage == _AuthStage.access && _accountMode == _AccountMode.signIn);
  String get _stageHeaderAsset => switch (_stage) {
        _AuthStage.access => GeneratedImageAssets.onboardingAccountImmersive,
        _AuthStage.details => GeneratedImageAssets.onboardingDetailsImmersive,
        _AuthStage.recommendations =>
          GeneratedImageAssets.meetupsContinuousScene,
        _AuthStage.complete => GeneratedImageAssets.homeContinuousScene,
      };
  String get _stageHeaderSemanticLabel => switch (_stage) {
        _AuthStage.access => 'Arriving at a welcoming cafe',
        _AuthStage.details => 'Two people having a friendly conversation',
        _AuthStage.recommendations => 'A small meetup around a shared table',
        _AuthStage.complete => 'A welcoming meetup table ready for guests',
      };
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
    final password = _passwordController.text.trim();
    if (password.isEmpty || _accountMode == _AccountMode.signIn) return null;
    return password.length < 6 ? 'Use at least six characters.' : null;
  }

  String? get _confirmPasswordValidationMessage {
    if (_accountMode == _AccountMode.signIn) return null;
    final confirm = _confirmPasswordController.text.trim();
    if (confirm.isEmpty) return null;
    return confirm != _passwordController.text.trim()
        ? 'Passwords do not match yet.'
        : null;
  }

  String? get _birthDateValidationMessage {
    if (_selectedBirthDate == null) return null;
    return _underAgeErrorMessage();
  }

  @override
  void initState() {
    super.initState();
    _accountMode =
        widget.startInSignIn ? _AccountMode.signIn : _AccountMode.signUp;
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_refreshValidation);
    _confirmPasswordController.addListener(_refreshValidation);
    _firstNameController.addListener(_refreshValidation);
    _lastNameController.addListener(_refreshValidation);
    _hydrateFromExistingUser();
    final initialEvents = widget.initialEvents;
    if (initialEvents == null) {
      _loadEvents();
    } else {
      _availableEvents = List<MeetupEvent>.of(initialEvents);
    }
    final initialCityOptions = widget.initialCityOptions;
    if (initialCityOptions == null) {
      _loadCityOptions();
    } else {
      _cityOptions = List<String>.of(initialCityOptions);
      _reconcileSelectedCity();
    }
  }

  @override
  void didUpdateWidget(covariant AuthFlowScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.existingUser?.id != widget.existingUser?.id ||
        oldWidget.existingUser?.updatedAt != widget.existingUser?.updatedAt) {
      _hydrateFromExistingUser();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _conversationGoalsController.dispose();
    _dietaryNotesController.dispose();
    super.dispose();
  }

  void _hydrateFromExistingUser() {
    final user = widget.existingUser;
    if (user == null) return;

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    _accountMode = _AccountMode.signUp;
    _emailController.text = user.email ?? '';
    _firstNameController.text = (metadata['first_name'] as String?) ?? '';
    _lastNameController.text = (metadata['last_name'] as String?) ?? '';
    _phoneController.text = (metadata['phone'] as String?) ?? '';
    _addressController.text = (metadata['address'] as String?) ?? '';
    _conversationGoalsController.text =
        (metadata['conversation_goals'] as String?) ?? '';
    _dietaryNotesController.text = (metadata['dietary_notes'] as String?) ?? '';
    _selectedCity = metadata['city'] as String?;
    _selectedGender = metadata['gender'] as String?;
    _selectedLanguage = metadata['language'] as String? ?? 'English';
    _selectedAvailability = metadata['availability'] as String?;
    _selectedEnergy = metadata['energy'] as String?;
    _selectedGroupPreference =
        _normalizeGroupPreference(metadata['group_preference'] as String?);
    final birthDateValue = metadata['date_of_birth'] as String?;
    _selectedBirthDate =
        birthDateValue == null ? null : DateTime.tryParse(birthDateValue);

    _selectedInterests
      ..clear()
      ..addAll(
        ((metadata['interests'] as List?) ?? const []).whereType<String>(),
      );

    _selectedEventIds
      ..clear()
      ..addAll(
        ((metadata['selected_event_ids'] as List?) ?? const [])
            .whereType<String>(),
      );

    _reconcileSelectedCity();
    _stage = _firstIncompleteStageForUser(user);
  }

  Future<void> _loadEvents({bool forceRefresh = false}) async {
    final events = await EventService(
      _supabase,
    ).fetchOpenEvents(forceRefresh: forceRefresh);
    final loadFailed = EventService.openEventsLoadFailed;
    if (!mounted) return;
    if (sameMeetupEventLists(_availableEvents, events) &&
        _eventLoadFailed == loadFailed) {
      return;
    }
    setState(() {
      _availableEvents = events;
      _eventLoadFailed = loadFailed;
    });
  }

  Future<void> _loadCityOptions() async {
    final options = await CityService(_supabase).fetchCityOptions();
    if (!mounted) return;
    if (listEquals(_cityOptions, options)) return;
    setState(() {
      _cityOptions = options;
      _reconcileSelectedCity();
    });
  }

  void _reconcileSelectedCity() {
    if (_cityOptions.isNotEmpty &&
        _selectedCity != null &&
        !_cityOptions.contains(_selectedCity)) {
      _selectedCity = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaSize = MediaQuery.sizeOf(context);
    final compact = mediaSize.width < 700;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: _stage == _AuthStage.access
                ? _AccessImmersiveBackground(
                    compact: compact,
                    semanticLabel: _stageHeaderSemanticLabel,
                  )
                : ContinuousImmersiveScene(
                    assetName: compact && _stage == _AuthStage.details
                        ? GeneratedImageAssets.landingImmersiveMobile
                        : _stageHeaderAsset,
                    semanticLabel: _stageHeaderSemanticLabel,
                    compactExtent: 980,
                    regularExtent: 820,
                    alignment: Alignment.topRight,
                    child: const SizedBox.expand(),
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
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    18,
                    horizontal,
                    _stage == _AuthStage.recommendations ? 148 : 32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MotionReveal(
                            index: 0,
                            child: _OnboardingTopBar(
                              canNavigateBack: _canNavigateBack,
                              showSkip: _stage == _AuthStage.recommendations,
                              onBack: _handleTopBack,
                              onSkip: _saveAndFinishLater,
                              isModal: widget.presentedAsModal,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_showsOnboardingProgress) ...[
                            MotionReveal(
                              index: 2,
                              child: _ProgressHeader(stage: _stage),
                            ),
                            const SizedBox(height: 22),
                          ] else
                            const SizedBox(height: 18),
                          if (_stage != _AuthStage.complete) ...[
                            MotionReveal(
                              index: 3,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: _StageIntro(
                                  key: ValueKey('intro-$_stage'),
                                  stage: _stage,
                                  accountMode: _accountMode,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: KeyedSubtree(
                              key: ValueKey(_stage),
                              child: _buildStage(theme),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_stage == _AuthStage.recommendations)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RecommendationActionBar(
                selectedCount: _selectedEventIds.length,
                isSubmitting: _isSubmitting,
                onBack: () => _setStage(_AuthStage.details),
                onContinue: _selectedEventIds.isNotEmpty
                    ? () => _saveRecommendationsAndContinue()
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStage(ThemeData theme) {
    switch (_stage) {
      case _AuthStage.access:
        return _buildAccessStep(theme);
      case _AuthStage.details:
        return _buildDetailsStep();
      case _AuthStage.recommendations:
        return _buildRecommendationsStep(theme);
      case _AuthStage.complete:
        return _buildCompletionStep(theme);
    }
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
                        _setStage(_AuthStage.access);
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
                  final compact = constraints.maxWidth < 520;

                  final firstNameField = TextField(
                    controller: _firstNameController,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.givenName],
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      hintText: 'Alex',
                    ),
                  );
                  final lastNameField = TextField(
                    controller: _lastNameController,
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.familyName],
                    decoration: const InputDecoration(
                      labelText: 'Last name',
                      hintText: 'Jansen',
                    ),
                  );

                  if (compact) {
                    return Column(
                      children: [
                        firstNameField,
                        const SizedBox(height: 12),
                        lastNameField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: firstNameField),
                      const SizedBox(width: 12),
                      Expanded(child: lastNameField),
                    ],
                  );
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
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
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
                labelText: 'Password',
                hintText:
                    isSignUp ? 'Create a password' : 'Enter your password',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
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
                    _handleAccessContinue();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  hintText: 'Same password again',
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
                        ? _handleAccessContinue
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

  Widget _buildDetailsStep() {
    return SectionCard(
      key: const ValueKey('details-form'),
      motionIndex: 4,
      enableReveal: false,
      backgroundColor: const Color(0xE6FFFDF9),
      borderColor: const Color(0x99D9E8E2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '* Required',
              key: const ValueKey('details-required-legend'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF138B8A),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          SelectionField(
            key: const ValueKey('details-birth-date-field'),
            icon: Icons.cake_outlined,
            label: 'Date of birth *',
            value: _selectedBirthDate == null
                ? null
                : _formatBirthDate(_selectedBirthDate!),
            placeholder: 'Choose your date',
            onTap: _pickBirthDate,
          ),
          if (_birthDateValidationMessage != null) ...[
            const SizedBox(height: 8),
            _InlineValidation(
              message: _birthDateValidationMessage!,
              positive: _underAgeErrorMessage() == null,
            ),
          ],
          const SizedBox(height: 12),
          SelectionField(
            key: const ValueKey('city-selection-field'),
            icon: Icons.location_city_outlined,
            label: 'City *',
            value: _selectedCity,
            placeholder: 'Choose your city',
            onTap: _pickCity,
          ),
          const SizedBox(height: 12),
          SelectionField(
            key: const ValueKey('details-gender-field'),
            icon: Icons.person_outline,
            label: 'Gender',
            value: _selectedGender,
            placeholder: 'Choose if you want',
            onTap: _pickGender,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('details-phone-field'),
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+31 6 12345678',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            onChanged: (_) => _refreshValidation(),
            onSubmitted: (_) {
              if (_detailsReady && !_isSubmitting) {
                unawaited(_saveDetailsAndContinue());
              }
            },
          ),
          const SizedBox(height: 10),
          _DetailsPrivacySummary(onWhyWeAsk: _showDetailsPrivacyInfo),
          const SizedBox(height: 18),
          if (_statusMessage != null) ...[
            _OnboardingStatusNotice(message: _statusMessage!),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting || !_detailsReady
                  ? null
                  : _saveDetailsAndContinue,
              child: Text(
                _isSubmitting ? 'Setting your place…' : 'Continue to meetups',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsStep(ThemeData theme) {
    final selectedCount = _selectedEventIds.length;
    final selectedOrder = _selectedEventIds.toList();
    final selectedEvents = _allOptions
        .where((option) => _selectedEventIds.contains(option.id))
        .toList()
      ..sort((a, b) {
        final aIndex = selectedOrder.indexOf(a.id);
        final bIndex = selectedOrder.indexOf(b.id);
        return aIndex.compareTo(bIndex);
      });
    final recommendationOptions = _allOptions;

    return SectionCard(
      motionIndex: 4,
      enableReveal: false,
      backgroundColor: const Color(0xE6FFFDF9),
      borderColor: const Color(0x99D9E8E2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_statusMessage != null) ...[
            _OnboardingStatusNotice(message: _statusMessage!),
            const SizedBox(height: 18),
          ],
          if (selectedEvents.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4F4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD3E5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF062B55),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          selectedCount == 1
                              ? '1 meetup selected'
                              : '$selectedCount meetups selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Your meetups so far',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  for (final event in selectedEvents) ...[
                    _SelectedEventSummaryCard(event: event),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
          if (selectedEvents.isNotEmpty) const SizedBox(height: 18),
          if (recommendationOptions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7F5),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFB9E3DC)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _eventLoadFailed
                          ? Icons.wifi_off_rounded
                          : Icons.event_busy_outlined,
                      color: const Color(0xFF138B8A),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _eventLoadFailed
                              ? 'We couldn’t load meetups'
                              : 'No meetups open right now',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _eventLoadFailed
                              ? 'Check your connection, then try again.'
                              : 'New options will appear here as soon as they are available.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4F6671),
                          ),
                        ),
                        if (_eventLoadFailed) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _loadEvents(forceRefresh: true),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            for (final option in recommendationOptions) ...[
              MeetupExplorerTile(
                key: ValueKey('onboarding-meetup-${option.id}'),
                event: option,
                selected: _selectedEventIds.contains(option.id),
                keyPrefix: 'onboarding-meetup',
                onOpenDetails: () => _showRecommendationPreview(option),
              ),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCompletionStep(ThemeData theme) {
    final selectedEvents = _allOptions
        .where((option) => _selectedEventIds.contains(option.id))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final meetupDays = selectedEvents
        .map((event) =>
            '${event.startsAt.day} ${_shortMonth(event.startsAt.month)}')
        .toList();
    final vibeLabel = selectedEvents.isEmpty
        ? 'Small-group meetups'
        : selectedEvents.map((event) => event.vibeLabel).toSet().join(' • ');
    final hasOneMeetup = selectedEvents.length == 1;

    return SectionCard(
      motionIndex: 4,
      enableReveal: false,
      backgroundColor: const Color(0xE6FFFDF9),
      borderColor: const Color(0x99D9E8E2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasOneMeetup
                ? 'Your first meetup is ready'
                : 'Your meetups are ready',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF062B55),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasOneMeetup
                ? 'Your reservation is confirmed. Manage it from Meetups; cancellations close 12 hours before it starts.'
                : 'Your reservations are confirmed. Manage them from Meetups; cancellations close 12 hours before each one starts.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF60727A),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFDDE7E3)),
            ),
            child: Column(
              children: [
                _FinishSummaryRow(
                  icon: Icons.place_outlined,
                  label: _selectedCity ?? 'City not set',
                ),
                const SizedBox(height: 14),
                _FinishSummaryRow(
                  icon: Icons.translate_outlined,
                  label: _selectedLanguage ?? 'English',
                ),
                const SizedBox(height: 14),
                _FinishSummaryRow(
                  icon: Icons.event_available_outlined,
                  label: meetupDays.isEmpty
                      ? 'No meetup reserved yet'
                      : meetupDays.join(' • '),
                ),
                const SizedBox(height: 14),
                _FinishSummaryRow(
                  icon: Icons.favorite_border_rounded,
                  label: vibeLabel,
                ),
                const SizedBox(height: 14),
                _FinishSummaryRow(
                  icon: Icons.star_border_rounded,
                  label: selectedEvents.length == 1
                      ? '1 meetup selected'
                      : '${selectedEvents.length} meetups selected',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : widget.onClose,
              child: const Text('Continue to VriendTime'),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'You can update your profile details anytime.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF138B8A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _normalizeGroupPreference(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value == 'No preference') return 'Mixed groups';
    return value;
  }

  Future<void> _saveRecommendationsAndContinue() async {
    final user = _signedInUser;
    if (user == null) {
      widget.onClose?.call();
      return;
    }

    await _runAuthAction(() async {
      final updatedUser = await _saveOnboardingMetadata(
        user,
        fields: const ['interests', 'selected_event_ids', 'language'],
        extraFields: {
          'completed_onboarding': true,
          'has_ever_reserved_meetup':
              (user.userMetadata?['has_ever_reserved_meetup'] as bool?) ==
                      true ||
                  _selectedEventIds.isNotEmpty,
        },
      );
      widget.onUserUpdated?.call(updatedUser ?? user);
      await _persistOnboardingData(updatedUser ?? user);
      if (!mounted) return;
      _setStage(_AuthStage.complete);
    });
  }

  void _handleAccessContinue() {
    _checkSignUpAccess();
  }

  Future<void> _checkSignUpAccess() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

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
          'last_name': _lastNameController.text.trim(),
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
          _accountMode = _AccountMode.signIn;
          _statusMessage =
              'Account created. Confirm your email, then sign in to finish setup.';
        });
        _setStage(_AuthStage.access);
        return;
      }

      await _ensureProfileForUser(response.user);
      if (!mounted) return;

      setState(() => _statusMessage = null);
      if (widget.circleMode) {
        widget.onClose?.call();
      } else {
        _setStage(_AuthStage.details);
      }
    });
  }

  Future<void> _openLegalDocument(LegalDocumentType type) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(type: type),
      ),
    );
  }

  void _onEmailChanged() {
    _refreshValidation();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DatePickerSheet(
          title: 'Date of birth',
          description:
              'Used to confirm you’re 18+. It stays private and is never shown to other members.',
          initialDate:
              _selectedBirthDate ?? DateTime(now.year - 28, now.month, now.day),
          firstDate: DateTime(1940),
          lastDate: now,
          confirmLabel: 'Save',
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedBirthDate = picked;
      _statusMessage = null;
    });
  }

  Future<void> _showDetailsPrivacyInfo() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x8F062B55),
      builder: (context) => FractionallySizedBox(
        heightFactor: MediaQuery.sizeOf(context).height < 700 ? 0.92 : 0.82,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: const _DetailsPrivacySheet(),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCity() async {
    final cityCount = _cityOptions.length;
    final coverageText = cityCount == 0
        ? 'No cities are available for selection right now. Please check back soon.'
        : cityCount == 1
            ? 'VriendTime is currently available in 1 city. More cities are coming soon.'
            : 'VriendTime is currently available in $cityCount cities. More cities are coming soon.';

    final picked = await _pickOption(
      title: 'Choose your city',
      currentValue: _selectedCity,
      options: _cityOptions,
      searchHintText: cityCount > 5 ? 'Search cities' : null,
      supportingText: coverageText,
      emptyStateTitle: 'We are launching city by city.',
      emptyStateBody:
          'We are live in a limited set of cities for now and adding more as we grow.',
    );

    if (!mounted || picked == null) return;
    setState(() {
      _selectedCity = picked;
      _statusMessage = null;
    });
  }

  Future<void> _pickGender() async {
    final picked = await _pickOption(
      title: 'Choose your gender',
      currentValue: _selectedGender,
      options: _genderOptions,
    );

    if (!mounted || picked == null) return;
    setState(() => _selectedGender = picked);
  }

  Future<String?> _pickOption({
    required String title,
    required String? currentValue,
    required List<String> options,
    String? searchHintText,
    String? supportingText,
    String? emptyStateTitle,
    String? emptyStateBody,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return OptionPickerSheet(
          title: title,
          currentValue: currentValue,
          options: options,
          searchHintText: searchHintText,
          supportingText: supportingText,
          emptyStateTitle: emptyStateTitle,
          emptyStateBody: emptyStateBody,
        );
      },
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
      final response = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
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

  Future<void> _saveDetailsAndContinue() async {
    final underAgeMessage = _underAgeErrorMessage();
    if (underAgeMessage != null) {
      _setStatus(underAgeMessage);
      return;
    }

    final user = _signedInUser;
    if (user == null) {
      _setStage(_AuthStage.recommendations);
      return;
    }

    await _runAuthAction(() async {
      final updatedUser = await _saveOnboardingMetadata(
        user,
        fields: const ['phone', 'city', 'date_of_birth', 'gender'],
      );
      await _ensureProfileForUser(updatedUser);
      widget.onUserUpdated?.call(updatedUser ?? user);
      if (!mounted) return;
      _setStage(_AuthStage.recommendations);
    });
  }

  Future<void> _saveAndFinishLater() async {
    final user = _signedInUser;
    if (user == null) {
      widget.onClose?.call();
      return;
    }

    await _runAuthAction(() async {
      User updatedUser = user;

      if (_stage == _AuthStage.recommendations) {
        updatedUser = (await _saveOnboardingMetadata(
              updatedUser,
              fields: const ['interests', 'selected_event_ids', 'language'],
              extraFields: {
                'completed_onboarding': true,
                'has_ever_reserved_meetup':
                    (user.userMetadata?['has_ever_reserved_meetup'] as bool?) ==
                            true ||
                        _selectedEventIds.isNotEmpty,
              },
            )) ??
            updatedUser;
      }

      widget.onUserUpdated?.call(updatedUser);
      _persistOnboardingDataInBackground(updatedUser);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Progress saved. You can finish setup later.',
          ),
        ),
      );
      widget.onClose?.call();
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

  Future<User?> _saveOnboardingMetadata(
    User user, {
    List<String>? fields,
    Map<String, dynamic> extraFields = const <String, dynamic>{},
  }) async {
    final allowedFields = fields?.toSet();
    final mergedData = <String, dynamic>{...?user.userMetadata};

    for (final entry in _buildUserMetadata().entries) {
      if (allowedFields != null && !allowedFields.contains(entry.key)) {
        continue;
      }
      mergedData[entry.key] = entry.value;
    }

    mergedData.addAll(extraFields);

    final response = await _supabase.auth.updateUser(
      UserAttributes(data: mergedData),
    );

    return response.user ?? user;
  }

  Map<String, dynamic> _buildUserMetadata() {
    return {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'city': _selectedCity,
      'date_of_birth': _birthDateIso(),
      'gender': _selectedGender,
      'language': _selectedLanguage,
      'availability': _selectedAvailability,
      'energy': _selectedEnergy,
      'group_preference': _selectedGroupPreference,
      'conversation_goals': _conversationGoalsController.text.trim(),
      'dietary_notes': _dietaryNotesController.text.trim(),
      'interests': _selectedInterests.toList(),
      'selected_event_ids': _selectedEventIds.toList(),
    };
  }

  Future<void> _ensureProfileForUser(User? user) async {
    if (user == null) return;

    final metadata = user.userMetadata ?? const <String, dynamic>{};

    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'first_name': metadata['first_name'],
        'phone': metadata['phone'],
        'address': metadata['address'],
        'city': metadata['city'],
        'date_of_birth': metadata['date_of_birth'],
        'gender': metadata['gender'],
        'language': metadata['language'],
        'availability': metadata['availability'],
        'energy': metadata['energy'],
        'group_preference': metadata['group_preference'],
        'conversation_goals': metadata['conversation_goals'],
        'dietary_notes': metadata['dietary_notes'],
        'interests': metadata['interests'] ?? const <String>[],
        'selected_event_ids':
            metadata['selected_event_ids'] ?? const <String>[],
        'profile_photo_path': metadata['profile_photo_path'],
        'profile_photo_name': metadata['profile_photo_name'],
        'secondary_photo_path': metadata['secondary_photo_path'],
        'secondary_photo_name': metadata['secondary_photo_name'],
        'has_profile_photo': metadata['has_profile_photo'] ?? false,
      }, onConflict: 'id');
    } catch (_) {
      // If the schema hasn't been applied yet, auth should still work.
    }
  }

  void _persistOnboardingDataInBackground(User user) {
    unawaited(_persistOnboardingData(user, swallowErrors: true));
  }

  Future<void> _persistOnboardingData(
    User user, {
    bool swallowErrors = false,
  }) async {
    try {
      await _ensureProfileForUser(user);
      await _syncEventAttendeesForUser(user.id);
    } catch (_) {
      if (!swallowErrors) rethrow;
      // The visible onboarding handoff should stay responsive even if
      // secondary persistence finishes a little later.
    }
  }

  Future<void> _syncEventAttendeesForUser(String userId) async {
    final eventService = EventService(_supabase);
    final existingReservedIds =
        await eventService.fetchReservedEventIds(userId);
    final previousIds = existingReservedIds.toSet();
    final nextIds = _selectedEventIds.toSet();
    final addedIds = nextIds.difference(previousIds).toList();
    final removedIds = previousIds.difference(nextIds).toList();

    for (final eventId in addedIds) {
      await eventService.reserveEvent(
        eventId: eventId,
        profileId: userId,
      );
    }

    for (final eventId in removedIds) {
      await eventService.cancelReservation(
        eventId: eventId,
        profileId: userId,
      );
    }
  }

  Future<User?> _syncMeetupSelectionsForUser(User user) async {
    final mergedMetadata = {
      ...?user.userMetadata,
      ..._buildUserMetadata(),
      'has_ever_reserved_meetup':
          (user.userMetadata?['has_ever_reserved_meetup'] as bool?) == true ||
              _selectedEventIds.isNotEmpty,
    };

    await _syncEventAttendeesForUser(user.id);
    final reservedIds = await EventService(_supabase).fetchReservedEventIds(
      user.id,
    );
    final persistedMetadata = {
      ...mergedMetadata,
      'selected_event_ids': reservedIds,
    };

    final response = await _supabase.auth.updateUser(
      UserAttributes(data: persistedMetadata),
    );
    final updatedUser = response.user ?? user;

    await _supabase.from('profiles').upsert({
      'id': updatedUser.id,
      'email': updatedUser.email,
      'first_name': persistedMetadata['first_name'],
      'phone': persistedMetadata['phone'],
      'address': persistedMetadata['address'],
      'city': persistedMetadata['city'],
      'date_of_birth': persistedMetadata['date_of_birth'],
      'gender': persistedMetadata['gender'],
      'language': persistedMetadata['language'],
      'availability': persistedMetadata['availability'],
      'energy': persistedMetadata['energy'],
      'group_preference': persistedMetadata['group_preference'],
      'conversation_goals': persistedMetadata['conversation_goals'],
      'dietary_notes': persistedMetadata['dietary_notes'],
      'interests': persistedMetadata['interests'] ?? const <String>[],
      'selected_event_ids': reservedIds,
      'profile_photo_path': persistedMetadata['profile_photo_path'],
      'profile_photo_name': persistedMetadata['profile_photo_name'],
      'secondary_photo_path': persistedMetadata['secondary_photo_path'],
      'secondary_photo_name': persistedMetadata['secondary_photo_name'],
      'has_profile_photo': persistedMetadata['has_profile_photo'] ?? false,
    }, onConflict: 'id');

    await _loadEvents();
    return updatedUser;
  }

  String _friendlyAuthMessage(AuthException error) {
    final message = error.message.toLowerCase();

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

  void _refreshValidation() {
    if (!mounted) return;
    setState(() {});
  }

  void _setStage(_AuthStage nextStage) {
    if (!mounted) return;
    setState(() => _stage = nextStage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  void _handleTopBack() {
    switch (_stage) {
      case _AuthStage.access:
        widget.onClose?.call();
        break;
      case _AuthStage.details:
        _setStage(_AuthStage.access);
        break;
      case _AuthStage.recommendations:
        _setStage(_AuthStage.details);
        break;
      case _AuthStage.complete:
        _setStage(_AuthStage.recommendations);
        break;
    }
  }

  Future<void> _toggleEvent(MeetupEvent option) async {
    final isAlreadySelected = _selectedEventIds.contains(option.id);
    if (isAlreadySelected && !canCancelMeetupReservation(option)) {
      _setStatus(
        'This reservation can no longer be cancelled. Cancellations close 12 hours before the meetup starts.',
      );
      return;
    }

    if (!isAlreadySelected) {
      if (!option.isOpenForReservation) {
        _setStatus(option.reservationUnavailableLabel);
        return;
      }

      final currentEvents = selectedMeetupEventsFromIds(
        _selectedEventIds.toList(),
        availableEvents: _availableEvents,
      );
      final conflictMessage = reservationConflictMessage(
        currentEvents: currentEvents,
        candidate: option,
      );

      if (conflictMessage != null) {
        _setStatus(conflictMessage);
        return;
      }
    }

    final confirmed =
        isAlreadySelected ? await _confirmSpotRemoval(option) : true;
    if (!confirmed || !mounted) return;

    final previousIds = _selectedEventIds.toSet();

    setState(() {
      if (_selectedEventIds.contains(option.id)) {
        _selectedEventIds.remove(option.id);
      } else {
        _selectedEventIds.add(option.id);
      }
      _statusMessage = null;
    });

    final user = _signedInUser;
    if (user == null) return;

    try {
      await _syncMeetupSelectionsForUser(user);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _selectedEventIds
          ..clear()
          ..addAll(previousIds);
        _statusMessage = _friendlyAuthMessage(error);
      });
    } on PostgrestException catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedEventIds
          ..clear()
          ..addAll(previousIds);
        _statusMessage =
            'We could not update your reservation. Check your connection and try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedEventIds
          ..clear()
          ..addAll(previousIds);
        _statusMessage =
            'We could not update your reservation. Check your connection and try again.';
      });
    }
  }

  Future<void> _showRecommendationPreview(MeetupEvent option) {
    final selected = _selectedEventIds.contains(option.id);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _RecommendationPreviewSheet(
          event: option,
          selected: selected,
          onChoose: () async {
            Navigator.of(context).pop();
            await _toggleEvent(option);
          },
        );
      },
    );
  }

  Future<bool> _confirmSpotRemoval(MeetupEvent option) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cancel this reservation?',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  option.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF062B55),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_onboardingDateLabel(option)} • ${option.detailTimeLabel}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF60727A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cancelling releases your seat. Cancellations close 12 hours before the meetup starts.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF60727A),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Keep reservation'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: destructiveOutlinedStyle,
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Cancel reservation'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return result == true;
  }

  String _formatBirthDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _shortMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, months.length - 1)];
  }

  String? _birthDateIso() {
    return _selectedBirthDate?.toIso8601String().split('T').first;
  }

  String? _underAgeErrorMessage() {
    final birthDate = _selectedBirthDate;
    if (birthDate == null) return null;

    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hadBirthday = now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) {
      age -= 1;
    }

    if (age < 18) {
      return 'Members need to be at least 18 years old to join VriendTime.';
    }

    return null;
  }

  _AuthStage _firstIncompleteStageForUser(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final hasDetails = (metadata['city'] as String?)?.isNotEmpty == true &&
        (metadata['date_of_birth'] as String?)?.isNotEmpty == true;
    final hasMeetupSelection =
        ((metadata['selected_event_ids'] as List?) ?? const []).isNotEmpty;
    if (!hasDetails) return _AuthStage.details;
    if (!hasMeetupSelection) return _AuthStage.recommendations;
    return _AuthStage.recommendations;
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

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({
    required this.canNavigateBack,
    required this.showSkip,
    required this.onBack,
    required this.onSkip,
    this.isModal = false,
  });

  final bool canNavigateBack;
  final bool showSkip;
  final VoidCallback onBack;
  final VoidCallback onSkip;

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
                    tooltip: 'Back',
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
            width: showSkip ? 88 : 52,
            height: 52,
            child: isModal
                ? IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.92),
                      foregroundColor: const Color(0xFF062B55),
                    ),
                  )
                : showSkip
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const ValueKey('skip-onboarding'),
                          onPressed: onSkip,
                          style: TextButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.94),
                            side: const BorderSide(color: Color(0xFFD5E5E2)),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            minimumSize: const Size(72, 44),
                            foregroundColor: const Color(0xFF062B55),
                            textStyle: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Skip'),
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.stage});

  final _AuthStage stage;

  @override
  Widget build(BuildContext context) {
    const actionableStageCount = 3;
    final stageIndex =
        _AuthStage.values.indexOf(stage).clamp(0, actionableStageCount - 1);

    return Column(
      children: [
        Text(
          'Step ${stageIndex + 1} of $actionableStageCount',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF60727A),
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(actionableStageCount, (index) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(
                  right: index == actionableStageCount - 1 ? 0 : 8,
                ),
                decoration: BoxDecoration(
                  color: index <= stageIndex
                      ? const Color(0xFF138B8A)
                      : const Color(0xFFE3E8E5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _StageIntro extends StatelessWidget {
  const _StageIntro({
    super.key,
    required this.stage,
    required this.accountMode,
  });

  final _AuthStage stage;
  final _AccountMode accountMode;

  @override
  Widget build(BuildContext context) {
    if (stage == _AuthStage.complete) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final headline = switch (stage) {
      _AuthStage.access => accountMode == _AccountMode.signIn
          ? 'Welcome back'
          : 'Create your account',
      _AuthStage.details => 'A little about you',
      _AuthStage.recommendations => 'Choose your first meetup',
      _AuthStage.complete => '',
    };
    final body = switch (stage) {
      _AuthStage.access => accountMode == _AccountMode.signIn
          ? 'Sign in to see what’s next.'
          : 'A few details. A new beginning with VriendTime.',
      _AuthStage.details => 'Your age and city help us show the right meetups.',
      _AuthStage.recommendations => 'Pick up to three meetups—one on each day.',
      _AuthStage.complete => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: const Color(0xFF062B55),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF60727A),
          ),
        ),
      ],
    );
  }
}

class _MeetupAvailability {
  const _MeetupAvailability({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
}

_MeetupAvailability _availabilityForEvent(
  MeetupEvent event, {
  required bool selected,
}) {
  if (selected) {
    return const _MeetupAvailability(
      label: 'Reserved',
      icon: Icons.check_circle_rounded,
      foregroundColor: Color(0xFF0B7474),
      backgroundColor: Color(0xFFDFF3EF),
    );
  }

  if (event.status == 'cancelled') {
    return const _MeetupAvailability(
      label: 'Cancelled',
      icon: Icons.event_busy_outlined,
      foregroundColor: Color(0xFF8B5148),
      backgroundColor: Color(0xFFF7E5E0),
    );
  }

  if (event.status == 'closed' || event.hasStarted) {
    return const _MeetupAvailability(
      label: 'Reservations closed',
      icon: Icons.lock_clock_outlined,
      foregroundColor: Color(0xFF656B69),
      backgroundColor: Color(0xFFE8E8E4),
    );
  }

  if (event.isFull) {
    return const _MeetupAvailability(
      label: 'Full',
      icon: Icons.group_off_outlined,
      foregroundColor: Color(0xFF9A4E43),
      backgroundColor: Color(0xFFF9E3DC),
    );
  }

  if (event.isAlmostFull) {
    return _MeetupAvailability(
      label: event.browseAvailabilityLabel,
      icon: Icons.local_fire_department_outlined,
      foregroundColor: const Color(0xFF8B5A15),
      backgroundColor: const Color(0xFFFFEBC7),
    );
  }

  return const _MeetupAvailability(
    label: 'Spots available',
    icon: Icons.event_seat_outlined,
    foregroundColor: Color(0xFF0B7474),
    backgroundColor: Color(0xFFE2F3EF),
  );
}

class _SelectedEventSummaryCard extends StatelessWidget {
  const _SelectedEventSummaryCard({required this.event});

  final MeetupEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 56,
              height: 56,
              child: MeetupArtwork(
                event: event,
                height: 56,
                radius: 14,
                assetName: GeneratedImageAssets.reservedCardForEvent(event),
                preferFullBleed: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_onboardingDateLabel(event)} • ${event.city}',
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF138B8A),
          ),
        ],
      ),
    );
  }
}

String _onboardingDateLabel(MeetupEvent event) {
  return '${event.startsAt.day} ${_onboardingMonthLabel(event.startsAt.month)}';
}

String _onboardingMonthLabel(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final index = month - 1;
  if (index < 0 || index >= months.length) return '';
  return months[index];
}

class _FinishSummaryRow extends StatelessWidget {
  const _FinishSummaryRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF60727A)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF062B55),
                ),
          ),
        ),
      ],
    );
  }
}

class _RecommendationPreviewSheet extends StatelessWidget {
  const _RecommendationPreviewSheet({
    required this.event,
    required this.selected,
    required this.onChoose,
  });

  final MeetupEvent event;
  final bool selected;
  final Future<void> Function() onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canCancel = selected && canCancelMeetupReservation(event);
    final availability = _availabilityForEvent(event, selected: selected);
    final heroHeight = MediaQuery.sizeOf(context).width < 380 ? 260.0 : 220.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFCF7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: SizedBox(
                    width: double.infinity,
                    height: heroHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MeetupArtwork(
                          event: event,
                          height: heroHeight,
                          radius: 26,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x7AFFF9F0),
                                Color(0x3DFFF9F0),
                                Color(0x2006294A),
                                Color(0xC0062B55),
                              ],
                              stops: [0, 0.34, 0.54, 1],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _SheetBadge(
                                    label: event.timeOfDayLabel,
                                    dark: true,
                                  ),
                                  _SheetBadge(label: event.languageLabel),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                event.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                event.subtitle,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: const Color(0xFFF3EEE8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SheetMetaPill(
                        label: '${event.activityLabel} • ${event.vibeLabel}'),
                    _SheetMetaPill(label: event.groupSizeLabel),
                    _SheetMetaPill(label: availability.label),
                  ],
                ),
                const SizedBox(height: 18),
                _SheetDetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: '${event.detailDateLabel} • ${event.detailTimeLabel}',
                ),
                const SizedBox(height: 16),
                _SheetDetailRow(
                  icon: Icons.place_outlined,
                  label: 'Area',
                  value: '${event.areaLabel}, ${event.city}',
                ),
                const SizedBox(height: 16),
                _SheetDetailRow(
                  icon: Icons.group_outlined,
                  label: 'Group size',
                  value: event.groupSizeLabel,
                ),
                const SizedBox(height: 16),
                const _SheetDetailRow(
                  icon: Icons.euro_rounded,
                  label: 'Cost',
                  value: meetupCostLabel,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        canCancel || (!selected && event.isOpenForReservation)
                            ? () async => onChoose()
                            : null,
                    icon: Icon(
                      selected
                          ? Icons.event_busy_outlined
                          : Icons.event_available_outlined,
                    ),
                    label: Text(
                      selected
                          ? canCancel
                              ? 'Cancel reservation'
                              : 'Cancellation window closed'
                          : event.isOpenForReservation
                              ? 'Reserve meetup'
                              : availability.label,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(height: 10),
                  Text(
                    canCancel
                        ? 'You can cancel until 12 hours before this meetup starts.'
                        : 'Cancellations close 12 hours before the meetup starts. This reservation can no longer be changed.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF60727A),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 6,
        decoration: BoxDecoration(
          color: const Color(0xFFD5E5E2),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SheetBadge extends StatelessWidget {
  const _SheetBadge({
    required this.label,
    this.dark = false,
  });

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white : const Color(0xFF138B8A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF062B55) : const Color(0xFFEAF7F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SheetMetaPill extends StatelessWidget {
  const _SheetMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF4F6671),
            ),
      ),
    );
  }
}

class _SheetDetailRow extends StatelessWidget {
  const _SheetDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF7F5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF138B8A), size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailsPrivacySummary extends StatelessWidget {
  const _DetailsPrivacySummary({required this.onWhyWeAsk});

  final VoidCallback onWhyWeAsk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: 'Your details stay private. Learn why we ask.',
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: Color(0xFF60727A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your details stay private.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF60727A),
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('why-we-ask'),
            onPressed: onWhyWeAsk,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Why we ask'),
          ),
        ],
      ),
    );
  }
}

class _DetailsPrivacySheet extends StatelessWidget {
  const _DetailsPrivacySheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Why we ask for these details',
      child: Material(
        color: const Color(0xFFFFFCF7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCAD6D2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 10, 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE4F4F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF138B8A),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      'Why we ask',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFF062B55),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Each detail has a clear purpose. Nothing here appears on your public profile.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF4F6671),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _PrivacyDetailRow(
                      icon: Icons.cake_outlined,
                      title: 'Date of birth',
                      body:
                          'Required only to confirm every member is at least 18.',
                    ),
                    const SizedBox(height: 18),
                    const _PrivacyDetailRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Gender',
                      body:
                          'Helps us understand and improve the mix of VriendTime groups.',
                    ),
                    const SizedBox(height: 18),
                    const _PrivacyDetailRow(
                      icon: Icons.phone_outlined,
                      title: 'Phone number',
                      body:
                          'Used only for important or last-minute meetup updates.',
                    ),
                    const SizedBox(height: 18),
                    const _PrivacyDetailRow(
                      icon: Icons.location_city_outlined,
                      title: 'City',
                      body: 'Required so we can show meetups near you.',
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'You can update optional answers later from Profile.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF60727A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('close-why-we-ask'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Got it'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyDetailRow extends StatelessWidget {
  const _PrivacyDetailRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF7F5),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 21, color: const Color(0xFF138B8A)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF60727A),
                ),
              ),
            ],
          ),
        ),
      ],
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
      label:
          'Agreement to the Terms and Conditions and acknowledgement of the Privacy Policy',
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
  const _InlineValidation({
    required this.message,
    this.positive = false,
  });

  final String message;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xFF2C7258) : const Color(0xFFA54F33);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          positive ? Icons.check_circle_outline : Icons.info_outline,
          size: 16,
          color: color,
        ),
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

class _RecommendationActionBar extends StatelessWidget {
  const _RecommendationActionBar({
    required this.selectedCount,
    required this.isSubmitting,
    required this.onBack,
    required this.onContinue,
  });

  final int selectedCount;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = responsiveHorizontalPadding(width);
    final maxWidth =
        responsiveContentMaxWidth(width).clamp(0.0, 720.0).toDouble();
    final compact = width < 520;
    final backButton = OutlinedButton.icon(
      onPressed: isSubmitting ? null : onBack,
      icon: const Icon(Icons.arrow_back),
      label: const Text('Back'),
    );
    final continueButton = ElevatedButton(
      onPressed: isSubmitting ? null : onContinue,
      child: Text(
        selectedCount == 0
            ? (compact ? 'Choose a meetup' : 'Choose a meetup to continue')
            : 'Save and continue',
      ),
    );

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xF8FFFBF8),
          border: Border(
            top: BorderSide(color: Color(0xFFDDE7E3)),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 18,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (compact) ...[
                    SizedBox(width: double.infinity, child: continueButton),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: backButton),
                  ] else
                    Row(
                      children: [
                        Expanded(child: backButton),
                        const SizedBox(width: 12),
                        Expanded(child: continueButton),
                      ],
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
