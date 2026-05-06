import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/calendar_service.dart';
import '../core/city_service.dart';
import '../core/event_catalog.dart';
import '../core/event_service.dart';
import '../core/interest_service.dart';
import '../core/profile_photo_service.dart';
import '../core/responsive.dart';
import '../widgets/brand_logo.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/meetup_media.dart';
import '../widgets/motion.dart';
import '../widgets/option_picker_sheet.dart';
import '../widgets/section_card.dart';
import '../widgets/selection_field.dart';

enum _AuthStage { access, details, recommendations, photo }

enum _AccountMode { signIn, signUp }

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({
    super.key,
    this.existingUser,
    this.onUserUpdated,
    this.onClose,
    this.photoOnlyMode = false,
  });

  final User? existingUser;
  final ValueChanged<User>? onUserUpdated;
  final VoidCallback? onClose;
  final bool photoOnlyMode;

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  final _scrollController = ScrollController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _conversationGoalsController = TextEditingController();
  final _dietaryNotesController = TextEditingController();

  _AccountMode _accountMode = _AccountMode.signUp;
  _AuthStage _stage = _AuthStage.access;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _statusMessage;
  Timer? _emailCheckDebounce;
  bool _isCheckingEmail = false;
  bool _emailAlreadyUsed = false;

  String? _selectedCity;
  DateTime? _selectedBirthDate;
  String? _selectedGender;
  String? _selectedLanguage;
  String? _selectedAvailability;
  String? _selectedEnergy;
  String? _selectedGroupPreference;

  Uint8List? _mainPhotoBytes;
  Uint8List? _extraPhotoBytes;
  String? _mainPhotoName;
  String? _extraPhotoName;

  final Set<String> _selectedInterests = <String>{};
  final Set<String> _selectedEventIds = <String>{};
  List<MeetupEvent> _availableEvents = allMeetupEvents;
  List<String> _cityOptions = CityService.defaultCityOptions;
  static const _genderOptions = [
    'Woman',
    'Man',
    'Non-binary',
    'Prefer not to say'
  ];
  SupabaseClient get _supabase => Supabase.instance.client;

  List<MeetupEvent> get _allOptions =>
      [..._availableEvents]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  User? get _signedInUser => _supabase.auth.currentUser ?? widget.existingUser;

  bool get _detailsReady =>
      _selectedCity != null &&
      _selectedBirthDate != null &&
      _selectedGender != null;

  bool get _hasMainPhoto => _mainPhotoBytes != null;
  bool get _hasExtraPhoto => _extraPhotoBytes != null;
  bool get _canNavigateBack =>
      widget.onClose != null ||
      (!widget.photoOnlyMode && _stage != _AuthStage.access);
  bool get _isAccessStepValid {
    if (_accountMode == _AccountMode.signIn) {
      return _looksLikeEmail(_emailController.text) &&
          _passwordController.text.trim().isNotEmpty;
    }

    return _nameController.text.trim().isNotEmpty &&
        _looksLikeEmail(_emailController.text) &&
        _passwordController.text.trim().length >= 6 &&
        _passwordController.text == _confirmPasswordController.text;
  }

  String? get _emailValidationMessage {
    final email = _emailController.text.trim();
    if (email.isEmpty) return null;
    if (!_looksLikeEmail(email)) {
      return 'Enter a valid email address.';
    }
    if (_accountMode == _AccountMode.signUp && _emailAlreadyUsed) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (_accountMode == _AccountMode.signUp && _isCheckingEmail) {
      return 'Checking whether this email is available...';
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
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_refreshValidation);
    _confirmPasswordController.addListener(_refreshValidation);
    _nameController.addListener(_refreshValidation);
    _hydrateFromExistingUser();
    _loadEvents();
    _loadCityOptions();
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
    _emailCheckDebounce?.cancel();
    _scrollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
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
    _nameController.text = (metadata['first_name'] as String?) ?? '';
    _phoneController.text = (metadata['phone'] as String?) ?? '';
    _addressController.text = (metadata['address'] as String?) ?? '';
    _conversationGoalsController.text =
        (metadata['conversation_goals'] as String?) ?? '';
    _dietaryNotesController.text = (metadata['dietary_notes'] as String?) ?? '';
    _selectedCity = metadata['city'] as String?;
    _selectedGender = metadata['gender'] as String?;
    _selectedLanguage = metadata['language'] as String?;
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
    _selectedInterests.removeWhere(
      (interest) => !InterestService.defaultInterestOptions.contains(interest),
    );

    _selectedEventIds
      ..clear()
      ..addAll(
        ((metadata['selected_event_ids'] as List?) ?? const [])
            .whereType<String>(),
      );

    _mainPhotoName = metadata['profile_photo_name'] as String?;
    _extraPhotoName = metadata['secondary_photo_name'] as String?;
    _stage = widget.photoOnlyMode
        ? _AuthStage.photo
        : _firstIncompleteStageForUser(user);
  }

  Future<void> _loadEvents() async {
    final events = await EventService(_supabase).fetchOpenEvents();
    if (!mounted) return;
    if (sameMeetupEventLists(_availableEvents, events)) return;
    setState(() => _availableEvents = events);
  }

  Future<void> _loadCityOptions() async {
    final options = await CityService(_supabase).fetchCityOptions();
    if (!mounted) return;
    if (listEquals(_cityOptions, options)) return;
    setState(() => _cityOptions = options);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const _WarmBackdrop(),
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
                            child: SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: _canNavigateBack
                                        ? IconButton(
                                            onPressed: _handleTopBack,
                                            icon: const Icon(
                                              Icons.arrow_back_rounded,
                                            ),
                                            tooltip: _stage == _AuthStage.access
                                                ? 'Back'
                                                : 'Previous step',
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.9),
                                              foregroundColor:
                                                  const Color(0xFF062B55),
                                            ),
                                          )
                                        : null,
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: BrandLockup(
                                        logoSize: 42,
                                        foregroundColor:
                                            theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 48, height: 48),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          MotionReveal(
                            index: 1,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 320),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: _HeroPanel(
                                key: ValueKey(_stage),
                                stage: _stage,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
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
                onFinishLater: () => _saveAndFinishLater(),
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
        return _buildDetailsStep(theme);
      case _AuthStage.recommendations:
        return _buildRecommendationsStep(theme);
      case _AuthStage.photo:
        return _buildPhotoStep(theme);
    }
  }

  Widget _buildAccessStep(ThemeData theme) {
    final isSignUp = _accountMode == _AccountMode.signUp;

    return SectionCard(
      motionIndex: 4,
      enableReveal: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSignUp ? 'Start with your account' : 'Welcome back',
            style: theme.textTheme.titleLarge,
          ),
          if (isSignUp) ...[
            const SizedBox(height: 8),
            Text(
              'Just your name, email, and a password.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: double.infinity,
                child: SegmentedButton<_AccountMode>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
          const SizedBox(height: 18),
          if (isSignUp) ...[
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'First name',
                hintText: 'Alex',
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
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
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: isSignUp ? 'Create a password' : 'Enter your password',
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
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
          if (isSignUp) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                hintText: 'Same password again',
                suffixIcon: IconButton(
                  onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
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
          ],
          const SizedBox(height: 16),
          if (_statusMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7F5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFB9E3DC)),
              ),
              child: Text(
                _statusMessage!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFF062B55)),
              ),
            ),
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
                    ? (isSignUp ? 'Creating...' : 'Signing in...')
                    : (isSignUp ? 'Continue' : 'Sign in'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep(ThemeData theme) {
    return SectionCard(
      motionIndex: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your profile', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'These details help us suggest the right meetups. Your date of birth is never shown to others.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Text('City', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          SelectionField(
            icon: Icons.location_city_outlined,
            value: _selectedCity,
            placeholder: 'Your city',
            onTap: _pickCity,
          ),
          const SizedBox(height: 18),
          Text('Date of birth', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          SelectionField(
            icon: Icons.cake_outlined,
            value: _selectedBirthDate == null
                ? null
                : _formatBirthDate(_selectedBirthDate!),
            placeholder: 'Your date of birth',
            onTap: _pickBirthDate,
          ),
          if (_birthDateValidationMessage != null) ...[
            const SizedBox(height: 8),
            _InlineValidation(
              message: _birthDateValidationMessage!,
              positive: _underAgeErrorMessage() == null,
            ),
          ],
          const SizedBox(height: 18),
          Text('Gender', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          SelectionField(
            icon: Icons.person_outline,
            value: _selectedGender,
            placeholder: 'Your gender',
            onTap: _pickGender,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _detailsReady ? _saveDetailsAndContinue : null,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsStep(ThemeData theme) {
    final selectedCount = _selectedEventIds.length;
    final selectedEvents = _allOptions
        .where((option) => _selectedEventIds.contains(option.id))
        .toList()
      ..sort((a, b) {
        final aIndex = _selectedEventIds.toList().indexOf(a.id);
        final bIndex = _selectedEventIds.toList().indexOf(b.id);
        return aIndex.compareTo(bIndex);
      });
    final recommendationOptions = _allOptions;

    return SectionCard(
      motionIndex: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedEvents.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFDDE7E3)),
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
                              ? '1 spot selected'
                              : '$selectedCount spots selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7F5),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFB9E3DC)),
              ),
              child: Text(
                'No meetups are open yet. New meetups will appear here.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else ...[
            for (final option in recommendationOptions) ...[
              _EventOptionCard(
                option: option,
                selected: _selectedEventIds.contains(option.id),
                onTap: () => _toggleEvent(option),
              ),
              const SizedBox(height: 12),
            ],
          ],
          const SizedBox(height: 4),
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
      _setStage(_AuthStage.photo);
      return;
    }

    await _runAuthAction(() async {
      final updatedUser = await _saveOnboardingMetadata(
        user,
        fields: const ['interests', 'selected_event_ids', 'language'],
      );
      await _ensureProfileForUser(updatedUser);
      widget.onUserUpdated?.call(updatedUser ?? user);
      if (!mounted) return;
      _setStage(_AuthStage.photo);
    });
  }

  Widget _buildPhotoStep(ThemeData theme) {
    final eventById = {
      for (final event in _allOptions) event.id: event,
    };
    final selectedActivities = _selectedEventIds
        .map((id) => eventById[id])
        .whereType<MeetupEvent>()
        .toList();

    return SectionCard(
      motionIndex: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAF7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDDE7E3)),
            ),
            child: selectedActivities.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No meetup yet',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You can add your photo now and choose a meetup later.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your meetups',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      for (final activity in selectedActivities)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: const Color(0xFF062B55),
                                ),
                                child: const Icon(
                                  Icons.event_available_outlined,
                                  color: Color(0xFF36B8A5),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity.title,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      activity.dateLabel,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          if (_statusMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7F5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFB9E3DC)),
              ),
              child: Text(
                _statusMessage!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFF062B55)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          _PhotoSlot(
            title: 'Profile photo',
            subtitle:
                _mainPhotoName ?? 'Helps others recognize you at the table',
            helper: _hasMainPhoto
                ? 'Photo added. You can replace it any time.'
                : '',
            filled: _hasMainPhoto,
            imageBytes: _mainPhotoBytes,
            onTap: () => _pickPhoto(primary: true),
          ),
          const SizedBox(height: 18),
          if (widget.photoOnlyMode)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _hasMainPhoto && !_isSubmitting
                    ? _completeOnboarding
                    : null,
                child: Text(
                  _isSubmitting ? 'Saving...' : 'Finish setup',
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _setStage(_AuthStage.recommendations),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _hasMainPhoto && !_isSubmitting
                        ? _completeOnboarding
                        : null,
                    child: Text(
                      _isSubmitting ? 'Saving...' : 'Finish setup',
                    ),
                  ),
                ),
              ],
            ),
          if (!_hasMainPhoto) ...[
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : _saveAndFinishLater,
                    child: const Text('Add photo later'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your spots are reserved. You can add a photo anytime.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleAccessContinue() {
    _checkSignUpAccess();
  }

  Future<void> _checkSignUpAccess() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (_nameController.text.trim().isEmpty) {
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

    if (_emailAlreadyUsed) {
      _setStatus(
        'An account with this email already exists. Try signing in instead.',
      );
      return;
    }

    await _runAuthAction(() async {
      final emailExists = await _checkEmailAvailability(
        _emailController.text.trim(),
        updateState: true,
      );

      if (!mounted) return;

      if (emailExists == true) {
        _setStatus(
          'An account with this email already exists. Try signing in instead.',
        );
        return;
      }

      final response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'first_name': _nameController.text.trim(),
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

      setState(() {
        _statusMessage = 'Account created. Let\'s add your basic details.';
      });
      _setStage(_AuthStage.details);
    });
  }

  void _onEmailChanged() {
    _refreshValidation();

    if (_accountMode != _AccountMode.signUp) {
      if (_emailAlreadyUsed || _isCheckingEmail) {
        setState(() {
          _emailAlreadyUsed = false;
          _isCheckingEmail = false;
        });
      }
      return;
    }

    final email = _emailController.text.trim();
    _emailCheckDebounce?.cancel();

    if (email.isEmpty || !_looksLikeEmail(email)) {
      if (_emailAlreadyUsed || _isCheckingEmail) {
        setState(() {
          _emailAlreadyUsed = false;
          _isCheckingEmail = false;
        });
      }
      return;
    }

    setState(() {
      _emailAlreadyUsed = false;
      _isCheckingEmail = true;
      _statusMessage = null;
    });

    _emailCheckDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _checkEmailAvailability(email, updateState: true),
    );
  }

  Future<bool?> _checkEmailAvailability(
    String email, {
    required bool updateState,
  }) async {
    try {
      final result = await _supabase
          .rpc<bool>('email_exists', params: {'check_email': email});

      if (!mounted) return result;

      final matchesCurrentInput = email == _emailController.text.trim();
      if (updateState && matchesCurrentInput) {
        setState(() {
          _emailAlreadyUsed = result == true;
          _isCheckingEmail = false;
        });
      }

      return result == true;
    } catch (_) {
      if (!mounted) return null;

      final matchesCurrentInput = email == _emailController.text.trim();
      if (updateState && matchesCurrentInput) {
        setState(() {
          _emailAlreadyUsed = false;
          _isCheckingEmail = false;
        });
      }

      return null;
    }
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
              'Used for age matching only. It is never shown to others.',
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
      _statusMessage = _underAgeErrorMessage();
    });
  }

  Future<void> _pickCity() async {
    final picked = await _pickOption(
      title: 'Choose your city',
      currentValue: _selectedCity,
      options: _cityOptions,
      searchHintText: 'Search cities',
    );

    if (!mounted || picked == null) return;
    setState(() => _selectedCity = picked);
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
        );
      },
    );
  }

  Future<void> _pickPhoto({required bool primary}) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
    } on PlatformException catch (error) {
      final message = error.code == 'ENTITLEMENT_NOT_FOUND'
          ? 'Your device did not allow photo access.'
          : 'We could not open your photo library. Try again.';
      _setStatus(message);
      return;
    }

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    if (file.bytes == null) {
      _setStatus('We could not read that photo. Choose a JPG, PNG, or WebP.');
      return;
    }

    if (ProfilePhotoService.isTooLarge(file.bytes!)) {
      _setStatus(
          ProfilePhotoService.tooLargeMessage(file.bytes!.lengthInBytes));
      return;
    }

    if (!mounted) return;

    setState(() {
      _statusMessage = null;
      if (primary) {
        _mainPhotoBytes = file.bytes;
        _mainPhotoName = file.name;
      } else {
        _extraPhotoBytes = file.bytes;
        _extraPhotoName = file.name;
      }
    });
  }

  Future<void> _signIn() async {
    if (!_looksLikeEmail(_emailController.text)) {
      _setStatus('Enter a valid email address.');
      return;
    }
    final emailExists = await _checkEmailAvailability(
      _emailController.text.trim(),
      updateState: true,
    );
    if (!mounted) return;
    if (emailExists == false) {
      _setStatus('No account found with this email. Create an account first.');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _setStatus('Enter your password to continue.');
      return;
    }

    await _runAuthAction(() async {
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
        fields: const ['city', 'date_of_birth', 'gender'],
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
      User? updatedUser = user;

      if (_stage == _AuthStage.recommendations) {
        updatedUser = await _saveOnboardingMetadata(
          user,
          fields: const ['interests', 'selected_event_ids', 'language'],
        );
      } else if (_stage == _AuthStage.photo) {
        updatedUser = await _saveOnboardingMetadata(user);
      }

      await _ensureProfileForUser(updatedUser);
      widget.onUserUpdated?.call(updatedUser ?? user);

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

  Future<void> _completeOnboarding() async {
    final user = _signedInUser;
    if (user == null) {
      _setStatus('Sign in again to finish setup.');
      return;
    }
    if (!_detailsReady) {
      _setStatus('Complete your basic details first.');
      return;
    }
    if (!_hasMainPhoto) {
      _setStatus('Add a profile photo to finish setup.');
      return;
    }
    final underAgeMessage = _underAgeErrorMessage();
    if (underAgeMessage != null) {
      _setStatus(underAgeMessage);
      return;
    }

    await _runAuthAction(() async {
      final photoUpdates = await _uploadSelectedPhotosForUser(user);
      final updatedUser = await _saveOnboardingMetadata(
        user,
        extraFields: photoUpdates,
      );
      final syncedUser =
          await _syncMeetupSelectionsForUser(updatedUser ?? user);
      await _ensureProfileForUser(syncedUser);
      widget.onUserUpdated?.call(syncedUser ?? user);
      widget.onClose?.call();
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      await action();
    } on AuthException catch (error) {
      if (!mounted) return;
      _setStatus(_friendlyAuthMessage(error));
    } on StorageException catch (error) {
      if (!mounted) return;
      _setStatus(_friendlyStorageMessage(error));
    } catch (_) {
      if (!mounted) return;
      _setStatus('We could not finish that. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<User?> _saveOnboardingMetadata(
    User user, {
    List<String>? fields,
    Map<String, dynamic> extraFields = const <String, dynamic>{},
  }) async {
    final nextMetadata = {
      ..._buildUserMetadata(),
      ...extraFields,
    };
    final allowedFields = fields?.toSet();
    final mergedData = <String, dynamic>{...?user.userMetadata};

    for (final entry in nextMetadata.entries) {
      if (allowedFields != null && !allowedFields.contains(entry.key)) {
        continue;
      }
      mergedData[entry.key] = entry.value;
    }

    final response = await _supabase.auth.updateUser(
      UserAttributes(data: mergedData),
    );

    return response.user ?? user;
  }

  Map<String, dynamic> _buildUserMetadata() {
    return {
      'first_name': _nameController.text.trim(),
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
      'has_profile_photo': _hasMainPhoto || _hasExtraPhoto,
    };
  }

  Future<Map<String, dynamic>> _uploadSelectedPhotosForUser(User user) async {
    final updates = <String, dynamic>{};

    if (_mainPhotoBytes != null && _mainPhotoName != null) {
      final primaryPath = await ProfilePhotoService.uploadPhoto(
        supabase: _supabase,
        userId: user.id,
        bytes: _mainPhotoBytes!,
        fileName: _mainPhotoName!,
        slot: 'primary',
      );
      updates['profile_photo_path'] = primaryPath;
      updates['profile_photo_name'] = _mainPhotoName;
    }

    if (_extraPhotoBytes != null && _extraPhotoName != null) {
      final secondaryPath = await ProfilePhotoService.uploadPhoto(
        supabase: _supabase,
        userId: user.id,
        bytes: _extraPhotoBytes!,
        fileName: _extraPhotoName!,
        slot: 'secondary',
      );
      updates['secondary_photo_path'] = secondaryPath;
      updates['secondary_photo_name'] = _extraPhotoName;
    }

    if (updates.isEmpty) {
      return updates;
    }

    updates['has_profile_photo'] = true;
    return updates;
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

  Future<User?> _syncMeetupSelectionsForUser(User user) async {
    final mergedMetadata = {
      ...?user.userMetadata,
      ..._buildUserMetadata(),
      'has_ever_reserved_meetup':
          (user.userMetadata?['has_ever_reserved_meetup'] as bool?) == true ||
              _selectedEventIds.isNotEmpty,
    };

    final response = await _supabase.auth.updateUser(
      UserAttributes(data: mergedMetadata),
    );
    final updatedUser = response.user ?? user;

    await _supabase.from('profiles').upsert({
      'id': updatedUser.id,
      'email': updatedUser.email,
      'first_name': mergedMetadata['first_name'],
      'phone': mergedMetadata['phone'],
      'address': mergedMetadata['address'],
      'city': mergedMetadata['city'],
      'date_of_birth': mergedMetadata['date_of_birth'],
      'gender': mergedMetadata['gender'],
      'language': mergedMetadata['language'],
      'availability': mergedMetadata['availability'],
      'energy': mergedMetadata['energy'],
      'group_preference': mergedMetadata['group_preference'],
      'conversation_goals': mergedMetadata['conversation_goals'],
      'dietary_notes': mergedMetadata['dietary_notes'],
      'interests': mergedMetadata['interests'] ?? const <String>[],
      'selected_event_ids': _selectedEventIds.toList(),
      'profile_photo_path': mergedMetadata['profile_photo_path'],
      'profile_photo_name': mergedMetadata['profile_photo_name'],
      'secondary_photo_path': mergedMetadata['secondary_photo_path'],
      'secondary_photo_name': mergedMetadata['secondary_photo_name'],
      'has_profile_photo': mergedMetadata['has_profile_photo'] ?? false,
    }, onConflict: 'id');

    final existingReservedIds =
        await EventService(_supabase).fetchReservedEventIds(updatedUser.id);
    final previousIds = existingReservedIds.toSet();
    final nextIds = _selectedEventIds.toSet();
    final addedIds = nextIds.difference(previousIds).toList();
    final removedIds = previousIds.difference(nextIds).toList();

    if (addedIds.isNotEmpty) {
      await _supabase.from('event_attendees').upsert(
        [
          for (final eventId in addedIds)
            {
              'event_id': eventId,
              'profile_id': updatedUser.id,
              'status': 'joined',
            },
        ],
        onConflict: 'event_id,profile_id',
      );
    }

    if (removedIds.isNotEmpty) {
      await _supabase
          .from('event_attendees')
          .update({'status': 'cancelled'})
          .eq('profile_id', updatedUser.id)
          .inFilter('event_id', removedIds);
    }

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
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (message.contains('signup') && message.contains('18')) {
      return 'Members need to be at least 18 years old to join.';
    }

    return 'We could not complete that. Check your details and try again.';
  }

  String _friendlyStorageMessage(StorageException error) {
    if (ProfilePhotoService.isBucketMissing(error)) {
      return 'Photo uploads are temporarily unavailable.';
    }
    if (ProfilePhotoService.isUploadTooLargeError(error)) {
      return 'That photo is too large. Choose a photo under ${ProfilePhotoService.maxUploadLabel}.';
    }

    final message = error.message.toLowerCase();
    if (message.contains('row-level security') ||
        message.contains('permission')) {
      return 'We could not upload your photo. Sign in again and try once more.';
    }

    return 'We could not upload your photo. Try again.';
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
    if (widget.photoOnlyMode) {
      widget.onClose?.call();
      return;
    }

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
      case _AuthStage.photo:
        _setStage(_AuthStage.recommendations);
        break;
    }
  }

  Future<void> _toggleEvent(MeetupEvent option) async {
    final isAlreadySelected = _selectedEventIds.contains(option.id);
    if (!isAlreadySelected) {
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

    final confirmed = isAlreadySelected
        ? await _confirmSpotRemoval(option)
        : await _confirmSpotSelection(option);
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
        _statusMessage = 'We could not update your spot. Try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedEventIds
          ..clear()
          ..addAll(previousIds);
        _statusMessage = 'We could not update your spot. Try again.';
      });
    }
  }

  Future<bool> _confirmSpotSelection(MeetupEvent option) async {
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
                  'Confirm your spot?',
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
                  '${option.detailDateLabel} • ${option.detailTimeLabel}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF60727A),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Confirm spot'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.center,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Not now'),
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
                  'Remove this spot?',
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
                  '${option.detailDateLabel} • ${option.detailTimeLabel}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF60727A),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Remove spot'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.center,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Keep it'),
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
        (metadata['date_of_birth'] as String?)?.isNotEmpty == true &&
        (metadata['gender'] as String?)?.isNotEmpty == true;
    final hasMeetupSelection =
        ((metadata['selected_event_ids'] as List?) ?? const []).isNotEmpty;
    final hasPhoto = (metadata['has_profile_photo'] as bool?) == true ||
        (metadata['profile_photo_path'] as String?)?.isNotEmpty == true;

    if (!hasDetails) return _AuthStage.details;
    if (!hasMeetupSelection) return _AuthStage.recommendations;
    if (!hasPhoto) return _AuthStage.photo;
    return _AuthStage.photo;
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({super.key, required this.stage});

  final _AuthStage stage;

  @override
  Widget build(BuildContext context) {
    final stageIndex = _AuthStage.values.indexOf(stage);
    final stageLabel = switch (stage) {
      _AuthStage.access => 'Account',
      _AuthStage.details => 'Profile',
      _AuthStage.recommendations => 'Meetups',
      _AuthStage.photo => 'Photo',
    };
    final headline = switch (stage) {
      _AuthStage.access => 'First, let\'s get you in.',
      _AuthStage.details => 'Tell us a little about yourself.',
      _AuthStage.recommendations => 'Pick what works for you.',
      _AuthStage.photo => 'Almost there.',
    };

    final body = switch (stage) {
      _AuthStage.access => '',
      _AuthStage.details => '',
      _AuthStage.recommendations => 'Pick up to three meetups — one per day.',
      _AuthStage.photo => 'A photo helps people recognize you when you arrive.',
    };

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF062B55), Color(0xFF138B8A), Color(0xFFFF7759)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26150806),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StageAccent(
                label: 'Step ${stageIndex + 1} of ${_AuthStage.values.length}',
              ),
              _StageAccent(label: stageLabel),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_AuthStage.values.length, (index) {
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(
                    right: index == _AuthStage.values.length - 1 ? 0 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: index <= stageIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          Text(
            headline,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFEAF7F5),
                ),
          ),
        ],
      ),
    );
  }
}

class _StageAccent extends StatelessWidget {
  const _StageAccent({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth = responsiveChipMaxWidth(MediaQuery.sizeOf(context).width);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFEAF7F5),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _EventOptionCard extends StatelessWidget {
  const _EventOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final MeetupEvent option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE7F4F2) : const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? const Color(0xFF36B8A5) : const Color(0xFFDDE7E3),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  selected ? const Color(0x1E36B8A5) : const Color(0x10062B55),
              blurRadius: selected ? 20 : 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: double.infinity,
                height: 144,
                child: MeetupArtwork(
                  event: option,
                  height: 144,
                  radius: 18,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RecommendationBadge(
                  label: selected ? 'Spot chosen' : option.vibeLabel,
                  dark: true,
                ),
                _RecommendationBadge(label: option.groupSizeLabel),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              option.title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              option.subtitle,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RecommendationMetaChip(
                  label:
                      '${option.detailDateLabel} • ${option.detailTimeLabel}',
                ),
                _RecommendationMetaChip(
                  label: '${option.areaLabel} • ${option.city}',
                ),
                _RecommendationMetaChip(
                  label: '${option.activityLabel} • ${option.vibeLabel}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            SeatMeter(
              filled: option.seatsFilled,
              total: option.seatsTotal,
            ),
            const SizedBox(height: 14),
            if (selected)
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = isCompactWidth(constraints.maxWidth);
                  final calendarButton = OutlinedButton.icon(
                    onPressed: () async {
                      final added = await addMeetupToCalendar(option);
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            added
                                ? 'Calendar opened for ${option.title}.'
                                : 'We could not open your calendar.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Add to calendar'),
                  );
                  final cancelButton = OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.event_busy_outlined),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD85F4D),
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      side: const BorderSide(color: Color(0xFFDDE7E3)),
                    ),
                    label: const Text('Remove spot'),
                  );

                  return stacked
                      ? Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: calendarButton,
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: cancelButton,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: calendarButton),
                            const SizedBox(width: 10),
                            Expanded(child: cancelButton),
                          ],
                        );
                },
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: option.isFull ? null : onTap,
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Choose this meetup'),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
              width: 48,
              height: 48,
              child: MeetupArtwork(
                event: event,
                height: 48,
                radius: 14,
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
                ),
                const SizedBox(height: 2),
                Text(
                  event.dateLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationBadge extends StatelessWidget {
  const _RecommendationBadge({
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

class _RecommendationMetaChip extends StatelessWidget {
  const _RecommendationMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4F6671)),
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
    required this.onFinishLater,
  });

  final int selectedCount;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback? onContinue;
  final VoidCallback onFinishLater;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = responsiveHorizontalPadding(width);
    final maxWidth = responsiveContentMaxWidth(width);

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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isSubmitting ? null : onBack,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : onContinue,
                          child: Text(
                            selectedCount == 0 ? 'Choose a meetup' : 'Continue',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: isSubmitting ? null : onFinishLater,
                    child: const Text('Finish later'),
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

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.title,
    required this.subtitle,
    required this.helper,
    required this.filled,
    required this.onTap,
    this.imageBytes,
  });

  final String title;
  final String subtitle;
  final String helper;
  final bool filled;
  final VoidCallback onTap;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: filled ? const Color(0xFFEAF7F5) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: filled ? const Color(0xFF36B8A5) : const Color(0xFFDDE7E3),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: _buildPrimaryLayout(context),
      ),
    );
  }

  Widget _buildPrimaryLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 640;
        final preview = _PreviewPanel(
          filled: filled,
          imageBytes: imageBytes,
        );
        final copy = _PhotoSlotCopy(
          title: title,
          subtitle: subtitle,
          helper: helper,
          filled: filled,
        );

        if (stacked) {
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                preview,
                const SizedBox(height: 16),
                copy,
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 4, child: preview),
              const SizedBox(width: 22),
              Expanded(flex: 3, child: copy),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.filled,
    required this.imageBytes,
  });

  final bool filled;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final image = imageBytes;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE7F4F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDE7E3)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: image == null
              ? Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? const Color(0xFF36B8A5)
                          : const Color(0xFFFFFFFF),
                    ),
                    child: Icon(
                      filled ? Icons.check : Icons.add_a_photo_outlined,
                      color: filled
                          ? const Color(0xFF062B55)
                          : const Color(0xFF66727C),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.72),
                      child: Image.memory(
                        image,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PhotoSlotCopy extends StatelessWidget {
  const _PhotoSlotCopy({
    required this.title,
    required this.subtitle,
    required this.helper,
    required this.filled,
  });

  final String title;
  final String subtitle;
  final String helper;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (helper.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            helper,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF062B55),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              filled ? 'Replace photo' : 'Choose photo',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WarmBackdrop extends StatelessWidget {
  const _WarmBackdrop();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFCF7),
              Color(0xFFEAF7F5),
              Color(0xFFF7ECE4),
            ],
          ),
        ),
      ),
    );
  }
}
