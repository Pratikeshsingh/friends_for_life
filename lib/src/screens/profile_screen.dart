import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/city_service.dart';
import '../core/interest_service.dart';
import '../core/profile_photo_service.dart';
import '../core/responsive.dart';
import '../widgets/brand_logo.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/motion.dart';
import '../widgets/option_picker_sheet.dart';
import '../widgets/section_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    this.onUserUpdated,
  });

  final User user;
  final ValueChanged<User>? onUserUpdated;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _availabilityOptions = [
    'Weekdays',
    'Weekends',
    'Both',
  ];

  static const _groupOptions = [
    'Mixed groups',
    'Women only',
    'Men only',
  ];

  late User _user;
  bool _isSaving = false;
  bool _isLoadingPhoto = false;
  Uint8List? _profilePhotoBytes;
  String? _profilePhotoUrl;
  bool _profilePhotoFailedToRender = false;
  final ScrollController _scrollController = ScrollController();
  List<String> _cityOptions = CityService.defaultCityOptions;
  List<String> _interestOptions = InterestService.defaultInterestOptions;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadProfilePhoto();
    _loadCityOptions();
    _loadInterestOptions();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.user.updatedAt != widget.user.updatedAt) {
      _user = widget.user;
      _loadProfilePhoto();
    }
  }

  Future<void> _loadCityOptions() async {
    final options =
        await CityService(Supabase.instance.client).fetchCityOptions();
    if (!mounted) return;
    if (listEquals(_cityOptions, options)) return;
    setState(() => _cityOptions = options);
  }

  Future<void> _loadInterestOptions() async {
    final options =
        await InterestService(Supabase.instance.client).fetchInterestOptions();
    if (!mounted) return;
    if (listEquals(_interestOptions, options)) return;
    setState(() => _interestOptions = options);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = (_user.userMetadata?['first_name'] as String?)?.trim();
    final city = (_user.userMetadata?['city'] as String?)?.trim();
    final dateOfBirth =
        (_user.userMetadata?['date_of_birth'] as String?)?.trim();
    final gender = (_user.userMetadata?['gender'] as String?)?.trim();
    final language = (_user.userMetadata?['language'] as String?)?.trim();
    final bio = (_user.userMetadata?['conversation_goals'] as String?)?.trim();
    final interestValues =
        ((_user.userMetadata?['interests'] as List?) ?? const [])
            .whereType<String>()
            .where(InterestService.defaultInterestOptions.contains)
            .toList();
    final ageLabel = _ageLabelFromIso(dateOfBirth);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFCF7), Color(0xFFEAF7F5), Color(0xFFF7ECE4)],
        ),
      ),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final horizontal = responsiveHorizontalPadding(width);
              final maxWidth = responsiveContentMaxWidth(width);
              final compactHero = isCompactWidth(width);

              return SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 140),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MotionReveal(
                          index: 0,
                          child: BrandLockup(
                            logoSize: 42,
                            foregroundColor: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 18),
                        MotionReveal(
                          index: 1,
                          child: Text(
                            'Your profile',
                            style: responsiveDisplayStyle(context),
                          ),
                        ),
                        const SizedBox(height: 18),
                        MotionReveal(
                          index: 2,
                          child: MotionParallax(
                            scrollController: _scrollController,
                            speed: 0.15,
                            maxShift: 30,
                            child: Container(
                              constraints: BoxConstraints(
                                minHeight: compactHero ? 348 : 312,
                              ),
                              padding: const EdgeInsets.all(26),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(34),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF062B55),
                                    Color(0xFF138B8A),
                                    Color(0xFFFF7759),
                                  ],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x2F1A0D08),
                                    blurRadius: 26,
                                    offset: Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  compactHero
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildProfileAvatar(firstName),
                                            const SizedBox(height: 18),
                                            _ProfileHeroCopy(
                                              firstName: firstName,
                                              ageLabel: ageLabel,
                                              city: city,
                                              email: _user.email,
                                              gender: gender,
                                              language: language,
                                            ),
                                          ],
                                        )
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildProfileAvatar(firstName),
                                            const SizedBox(width: 18),
                                            Expanded(
                                              child: _ProfileHeroCopy(
                                                firstName: firstName,
                                                ageLabel: ageLabel,
                                                city: city,
                                                email: _user.email,
                                                gender: gender,
                                                language: language,
                                              ),
                                            ),
                                          ],
                                        ),
                                  const SizedBox(height: 20),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(minHeight: 72),
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Text(
                                        bio != null && bio.isNotEmpty
                                            ? bio
                                            : 'Share something simple to help others start a conversation.',
                                        style:
                                            theme.textTheme.bodyLarge?.copyWith(
                                          color: const Color(0xFFEAF7F5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextButton(
                                    onPressed: _isSaving
                                        ? null
                                        : () => _editBio(
                                              initialValue: bio ?? '',
                                            ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Text(
                                      bio != null && bio.isNotEmpty
                                          ? 'Edit intro'
                                          : 'Add intro',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SectionCard(
                          motionIndex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Basics', style: theme.textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Text(
                                'Your date of birth is used for age matching. It is never shown to others.',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              _EditablePreferenceTile(
                                label: 'Name',
                                value: firstName?.isNotEmpty == true
                                    ? firstName!
                                    : 'Not set',
                                onTap: _isSaving
                                    ? null
                                    : () => _editName(
                                          initialValue: firstName ?? '',
                                        ),
                              ),
                              _EditablePreferenceTile(
                                label: 'City',
                                value: city?.isNotEmpty == true
                                    ? city!
                                    : 'Not set',
                                onTap: () => _pickSingleOption(
                                  title: 'City',
                                  metadataKey: 'city',
                                  options: _cityOptions,
                                ),
                              ),
                              _EditablePreferenceTile(
                                label: 'Date of birth',
                                value:
                                    _displayBirthDate(dateOfBirth) ?? 'Not set',
                                onTap: _isSaving ? null : _pickBirthDate,
                              ),
                              _EditablePreferenceTile(
                                label: 'Gender',
                                value: gender?.isNotEmpty == true
                                    ? gender!
                                    : 'Not set',
                                onTap: () => _pickSingleOption(
                                  title: 'Gender',
                                  metadataKey: 'gender',
                                  options: const [
                                    'Woman',
                                    'Man',
                                    'Non-binary',
                                    'Prefer not to say',
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SectionCard(
                          motionIndex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Preferences',
                                  style: theme.textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Text(
                                'Help us suggest meetups that feel like a good fit.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF60727A),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _EditablePreferenceTile(
                                label: 'Interests',
                                value: interestValues.isNotEmpty
                                    ? '${interestValues.length} selected'
                                    : 'Not set',
                                onTap: () => _editInterests(interestValues),
                              ),
                              _EditablePreferenceTile(
                                label: 'Available days',
                                value: _displayAvailabilityValue(
                                      (_user.userMetadata?['availability']
                                              as String?) ??
                                          '',
                                    ) ??
                                    'Any day',
                                onTap: _pickAvailability,
                              ),
                              _EditablePreferenceTile(
                                label: 'Meetup vibe',
                                value: _displayGroupPreferenceValue(
                                      _user.userMetadata?['group_preference']
                                          as String?,
                                    ) ??
                                    'Not set',
                                onTap: () => _pickSingleOption(
                                  title: 'Meetup vibe',
                                  metadataKey: 'group_preference',
                                  options: _groupOptions,
                                ),
                              ),
                              _EditablePreferenceTile(
                                label: 'Language',
                                value: (_user.userMetadata?['language']
                                        as String?) ??
                                    'Not set',
                                onTap: () => _pickSingleOption(
                                  title: 'Language',
                                  metadataKey: 'language',
                                  options: const ['English', 'Dutch', 'Both'],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SectionCard(
                          motionIndex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Account',
                                  style: theme.textTheme.titleLarge),
                              const SizedBox(height: 16),
                              _AccountDetailRow(
                                label: 'Email',
                                value: _user.email ?? 'No email on account',
                                icon: Icons.mail_outline,
                              ),
                              const SizedBox(height: 12),
                              _AccountDetailRow(
                                label: 'Status',
                                value: _user.emailConfirmedAt != null
                                    ? 'Verified'
                                    : 'Not verified',
                                icon: _user.emailConfirmedAt != null
                                    ? Icons.verified_outlined
                                    : Icons.mark_email_unread_outlined,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () =>
                                Supabase.instance.client.auth.signOut(),
                            child: const Text('Sign out'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (_isSaving)
            const Positioned(
              top: 16,
              right: 16,
              child: Chip(label: Text('Saving changes...')),
            ),
        ],
      ),
    );
  }

  String? _displayGroupPreferenceValue(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value == 'No preference') return 'Mixed groups';
    return _groupOptions.contains(value) ? value : null;
  }

  String? _displaySingleOptionValue(String metadataKey, String? value) {
    if (metadataKey == 'group_preference') {
      return _displayGroupPreferenceValue(value);
    }
    return value;
  }

  Future<void> _pickSingleOption({
    required String title,
    required String metadataKey,
    required List<String> options,
  }) async {
    final rawCurrentValue = _user.userMetadata?[metadataKey] as String?;
    final currentValue =
        _displaySingleOptionValue(metadataKey, rawCurrentValue);
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return OptionPickerSheet(
          title: title,
          currentValue: currentValue,
          options: options,
        );
      },
    );

    if (picked == null) return;
    if (picked == currentValue && picked == rawCurrentValue) return;
    await _saveMetadata({metadataKey: picked});
  }

  Future<void> _pickAvailability() async {
    final rawCurrentValue = _user.userMetadata?['availability'] as String?;
    final currentValue = _displayAvailabilityValue(rawCurrentValue);
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return OptionPickerSheet(
          title: 'Available days',
          currentValue: currentValue,
          options: _availabilityOptions,
        );
      },
    );

    if (picked == null) return;
    if (picked == rawCurrentValue) return;
    await _saveMetadata({'availability': picked});
  }

  String? _displayAvailabilityValue(String? value) {
    switch (value) {
      case 'Weekday daytime':
      case 'Weekday evening':
      case 'Weekdays':
        return 'Weekdays';
      case 'Weekend daytime':
      case 'Weekend evening':
      case 'Weekends':
        return 'Weekends';
      case 'Both':
        return 'Both';
      default:
        return value?.trim().isEmpty ?? true ? null : value;
    }
  }

  Future<void> _editInterests(List<String> currentInterests) async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _MultiSelectSheet(
          title: 'Edit interests',
          description: 'Choose the meetup types you are interested in.',
          currentValues: currentInterests,
          options: _interestOptions,
          saveLabel: 'Save interests',
        );
      },
    );

    if (picked == null) return;
    await _saveMetadata({'interests': picked});
  }

  Future<void> _editName({required String initialValue}) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _TextEditorSheet(
          title: 'Edit name',
          description: 'Use the first name other members should see.',
          hintText: 'Your first name',
          initialValue: initialValue,
          maxLines: 1,
          minLines: 1,
          saveLabel: 'Save',
        );
      },
    );

    if (result == null) return;
    await _saveMetadata({'first_name': result});
  }

  Future<void> _editBio({required String initialValue}) async {
    final hasBio = initialValue.trim().isNotEmpty;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _TextEditorSheet(
          title: hasBio ? 'Edit intro' : 'Add intro',
          description:
              'Add a line about yourself - something to break the ice before you arrive.',
          hintText: 'Easy to talk to, always up for good conversation',
          initialValue: initialValue,
          maxLines: 5,
          minLines: 5,
          saveLabel: 'Save',
        );
      },
    );

    if (result == null) return;
    await _saveMetadata({'conversation_goals': result});
  }

  Future<void> _pickBirthDate() async {
    final initialDate = DateTime.tryParse(
          (_user.userMetadata?['date_of_birth'] as String?) ?? '',
        ) ??
        DateTime(1995, 1, 1);
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
          initialDate: initialDate,
          firstDate: DateTime(1900, 1, 1),
          lastDate: now,
          confirmLabel: 'Save',
        );
      },
    );

    if (picked == null) return;
    final validationMessage = _underAgeErrorMessageForDate(picked);
    if (validationMessage != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    final isoDate = picked.toIso8601String().split('T').first;
    if (isoDate == (_user.userMetadata?['date_of_birth'] as String?)) return;
    await _saveMetadata({'date_of_birth': isoDate});
  }

  Future<void> _changeProfilePhoto() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = error.code == 'ENTITLEMENT_NOT_FOUND'
          ? 'Your device did not allow photo access.'
          : 'We could not open your photo library. Try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    if (file.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('We could not read that photo. Choose a JPG, PNG, or WebP.'),
        ),
      );
      return;
    }

    if (ProfilePhotoService.isTooLarge(file.bytes!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ProfilePhotoService.tooLargeMessage(file.bytes!.lengthInBytes),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final photoPath = await ProfilePhotoService.uploadPhoto(
        supabase: Supabase.instance.client,
        userId: _user.id,
        bytes: file.bytes!,
        fileName: file.name,
        slot: 'primary',
      );

      await _saveMetadata(
        {
          'profile_photo_path': photoPath,
          'profile_photo_name': file.name,
          'has_profile_photo': true,
        },
        nextProfilePhotoBytes: file.bytes,
      );
    } on StorageException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ProfilePhotoService.isBucketMissing(error)
                ? 'Photo uploads are temporarily unavailable.'
                : ProfilePhotoService.isUploadTooLargeError(error)
                    ? 'That photo is too large. Choose a photo under ${ProfilePhotoService.maxUploadLabel}.'
                    : 'We could not upload your photo. Try again.',
          ),
        ),
      );
      setState(() => _isSaving = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('We could not upload your photo. Try again.')),
      );
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveMetadata(
    Map<String, dynamic> updates, {
    Uint8List? nextProfilePhotoBytes,
  }) async {
    if (!_isSaving) {
      setState(() => _isSaving = true);
    }
    final mergedMetadata = {
      ...?_user.userMetadata,
      ...updates,
    };
    final normalizedGroupPreference = _displayGroupPreferenceValue(
      mergedMetadata['group_preference'] as String?,
    );
    if (normalizedGroupPreference != null) {
      mergedMetadata['group_preference'] = normalizedGroupPreference;
    }

    try {
      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: mergedMetadata),
      );

      await Supabase.instance.client.from('profiles').upsert({
        'id': _user.id,
        'email': _user.email,
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
        'selected_event_ids':
            mergedMetadata['selected_event_ids'] ?? const <String>[],
        'profile_photo_path': mergedMetadata['profile_photo_path'],
        'profile_photo_name': mergedMetadata['profile_photo_name'],
        'secondary_photo_path': mergedMetadata['secondary_photo_path'],
        'secondary_photo_name': mergedMetadata['secondary_photo_name'],
        'has_profile_photo': mergedMetadata['has_profile_photo'] ?? false,
      }, onConflict: 'id');

      if (!mounted) return;
      setState(() {
        _user = response.user ?? _user;
        if (nextProfilePhotoBytes != null) {
          _profilePhotoBytes = nextProfilePhotoBytes;
          _profilePhotoUrl = null;
          _profilePhotoFailedToRender = false;
        }
      });
      widget.onUserUpdated?.call(response.user ?? _user);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } on AuthException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('We could not save your changes. Try again.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('We could not save your changes. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _loadProfilePhoto() async {
    var photoPath = _user.userMetadata?['profile_photo_path'] as String?;
    if ((photoPath == null || photoPath.isEmpty) && _user.id.isNotEmpty) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('profile_photo_path')
            .eq('id', _user.id)
            .maybeSingle();
        photoPath = response?['profile_photo_path'] as String?;
      } catch (_) {
        // Ignore fallback lookup errors and leave the avatar in its default state.
      }
    }

    if (photoPath == null || photoPath.isEmpty) {
      if (!mounted) return;
      setState(() {
        _profilePhotoBytes = null;
        _profilePhotoUrl = null;
        _profilePhotoFailedToRender = false;
      });
      return;
    }

    setState(() {
      _isLoadingPhoto = true;
      _profilePhotoFailedToRender = false;
    });

    try {
      final bytes = await ProfilePhotoService.downloadPhoto(
        supabase: Supabase.instance.client,
        path: photoPath,
      );
      if (!mounted) return;
      if (bytes != null) {
        setState(() {
          _profilePhotoBytes = bytes;
          _profilePhotoUrl = null;
        });
        return;
      }
    } catch (_) {
      try {
        final signedUrl = await ProfilePhotoService.createSignedPhotoUrl(
          supabase: Supabase.instance.client,
          path: photoPath,
        );
        if (!mounted) return;
        setState(() {
          _profilePhotoBytes = null;
          _profilePhotoUrl = signedUrl;
        });
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _profilePhotoBytes = null;
          _profilePhotoUrl = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPhoto = false);
      }
    }
  }

  String? _displayBirthDate(String? isoValue) {
    final date = DateTime.tryParse(isoValue ?? '');
    if (date == null) return null;

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  String? _underAgeErrorMessageForDate(DateTime date) {
    final now = DateTime.now();
    var age = now.year - date.year;
    final hadBirthday = now.month > date.month ||
        (now.month == date.month && now.day >= date.day);
    if (!hadBirthday) {
      age -= 1;
    }

    if (age < 18) {
      return 'Members need to be at least 18 years old to join VriendTime.';
    }

    return null;
  }

  Widget _buildProfileAvatar(String? firstName) {
    final shouldShowPhoto = !_profilePhotoFailedToRender &&
        (_profilePhotoBytes != null ||
            (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty));

    return SizedBox(
      width: 148,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: shouldShowPhoto ? _openProfilePhotoPreview : null,
            borderRadius: BorderRadius.circular(28),
            child: Ink(
              height: 148,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F4F2),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.82),
                  width: 4,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2A062B55),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
                gradient: !shouldShowPhoto
                    ? const LinearGradient(
                        colors: [Color(0xFF062B55), Color(0xFF36B8A5)],
                      )
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: shouldShowPhoto
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: ColoredBox(
                            color: Colors.white.withValues(alpha: 0.72),
                            child: _buildPhotoWidget(fit: BoxFit.contain),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          (firstName ?? 'M').substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSaving ? null : _changeProfilePhoto,
              borderRadius: BorderRadius.circular(99),
              child: Ink(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F5),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFB9E3DC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingPhoto || _isSaving)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 15,
                        color: Color(0xFF138B8A),
                      ),
                    const SizedBox(width: 7),
                    Text(
                      shouldShowPhoto ? 'Update photo' : 'Add photo',
                      style: const TextStyle(
                        color: Color(0xFF138B8A),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openProfilePhotoPreview() {
    final bytes = _profilePhotoBytes;
    final url = _profilePhotoUrl;
    if (bytes == null && (url == null || url.isEmpty)) return;

    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile photo',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 460),
                    child: ColoredBox(
                      color: const Color(0xFFE7F4F2),
                      child: bytes != null
                          ? Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              filterQuality: FilterQuality.medium,
                            )
                          : Image.network(
                              url!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              filterQuality: FilterQuality.medium,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: Navigator.of(context).pop,
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _changeProfilePhoto();
                        },
                        child: const Text('Replace'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoWidget({BoxFit fit = BoxFit.cover}) {
    const cacheDimension = 1200;

    if (_profilePhotoBytes != null) {
      return Image.memory(
        _profilePhotoBytes!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheDimension,
        cacheHeight: cacheDimension,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _buildPhotoFailureFallback(),
      );
    }

    if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) {
      return Image.network(
        _profilePhotoUrl!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheDimension,
        cacheHeight: cacheDimension,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _buildPhotoFailureFallback(),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPhotoFailureFallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _profilePhotoFailedToRender) return;
      setState(() => _profilePhotoFailedToRender = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not display that photo. Use JPG, PNG, or WebP.',
          ),
        ),
      );
    });

    return const SizedBox.shrink();
  }
}

String? _ageLabelFromIso(String? value) {
  if (value == null || value.isEmpty) return null;

  final date = DateTime.tryParse(value);
  if (date == null) return null;

  final now = DateTime.now();
  var age = now.year - date.year;
  final hadBirthday = now.month > date.month ||
      (now.month == date.month && now.day >= date.day);
  if (!hadBirthday) {
    age -= 1;
  }

  return age.toString();
}

class _ProfileHeroCopy extends StatelessWidget {
  const _ProfileHeroCopy({
    required this.firstName,
    required this.ageLabel,
    required this.city,
    required this.email,
    required this.gender,
    required this.language,
  });

  final String? firstName;
  final String? ageLabel;
  final String? city;
  final String? email;
  final String? gender;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      if (city != null && city!.isNotEmpty) city!,
      if (gender != null && gender!.isNotEmpty) gender!,
      if (language != null && language!.isNotEmpty) language!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            firstName ?? 'Member',
            if (ageLabel != null) ageLabel,
          ].join(' • '),
          style: responsiveHeadlineStyle(
            context,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          details.isNotEmpty
              ? details.join(' • ')
              : email ?? 'Profile details incomplete',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFEAF7F5),
          ),
        ),
      ],
    );
  }
}

class _EditablePreferenceTile extends StatelessWidget {
  const _EditablePreferenceTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDE7E3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                enabled ? 'Edit' : '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: enabled ? const Color(0xFF138B8A) : null,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (enabled) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDetailRow extends StatelessWidget {
  const _AccountDetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F4F2),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: const Color(0xFF138B8A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF60727A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF60727A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiSelectSheet extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.description,
    required this.currentValues,
    required this.options,
    required this.saveLabel,
  });

  final String title;
  final String description;
  final List<String> currentValues;
  final List<String> options;
  final String saveLabel;

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _TextEditorSheet extends StatefulWidget {
  const _TextEditorSheet({
    required this.title,
    required this.description,
    required this.hintText,
    required this.initialValue,
    required this.maxLines,
    required this.minLines,
    required this.saveLabel,
  });

  final String title;
  final String description;
  final String hintText;
  final String initialValue;
  final int maxLines;
  final int minLines;
  final String saveLabel;

  @override
  State<_TextEditorSheet> createState() => _TextEditorSheetState();
}

class _TextEditorSheetState extends State<_TextEditorSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  widget.description,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_controller.text.trim()),
                        child: Text(widget.saveLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late final Set<String> _selected = widget.currentValues.toSet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _selected.length;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBF8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(widget.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7F5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFB9E3DC)),
              ),
              child: Text(
                selectedCount == 0
                    ? 'None selected'
                    : selectedCount == 1
                        ? '1 selected'
                        : '$selectedCount selected',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF138B8A),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final option in widget.options)
                  FilterChip(
                    selected: _selected.contains(option),
                    onSelected: (_) {
                      setState(() {
                        if (_selected.contains(option)) {
                          _selected.remove(option);
                        } else {
                          _selected.add(option);
                        }
                      });
                    },
                    label: Text(option),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_selected.toList()),
                child: Text(widget.saveLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
