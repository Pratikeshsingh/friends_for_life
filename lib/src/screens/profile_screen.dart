import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/city_service.dart';
import '../core/interest_service.dart';
import '../core/profile_photo_service.dart';
import '../core/responsive.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/continuous_immersive_scene.dart';
import '../widgets/date_picker_sheet.dart';
import '../widgets/meetup_media.dart';
import '../widgets/motion.dart';
import '../widgets/option_picker_sheet.dart';
import '../widgets/section_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    this.onUserUpdated,
    required this.onSignOut,
    required this.isSigningOut,
    required this.unreadNotificationCount,
    required this.onOpenNotifications,
  });

  final User user;
  final ValueChanged<User>? onUserUpdated;
  final VoidCallback onSignOut;
  final bool isSigningOut;
  final int unreadNotificationCount;
  final VoidCallback onOpenNotifications;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User _user;
  bool _isSaving = false;
  bool _isLoadingPhoto = false;
  Uint8List? _profilePhotoBytes;
  String? _profilePhotoUrl;
  String? _profilePhotoPath;
  bool _profilePhotoFailedToRender = false;
  bool _isRecoveringProfilePhotoUrl = false;
  final ScrollController _scrollController = ScrollController();
  List<String> _cityOptions = const <String>[];
  List<String> _interestOptions = InterestService.defaultInterestOptions;
  int _profilePhotoLoadVersion = 0;

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
    final firstName = (_user.userMetadata?['first_name'] as String?)?.trim();
    final city = (_user.userMetadata?['city'] as String?)?.trim();
    final language = _displayLanguageValue(
      (_user.userMetadata?['language'] as String?)?.trim(),
    );
    final bio = (_user.userMetadata?['conversation_goals'] as String?)?.trim();
    final interestValues =
        ((_user.userMetadata?['interests'] as List?) ?? const [])
            .whereType<String>()
            .where(_interestOptions.contains)
            .toList();
    final displayName = _displayProfileName(firstName);
    final email = _user.email ?? 'Email unavailable';
    final bioValue = bio ?? '';
    final dateOfBirth = _displayDateOfBirth(
      (_user.userMetadata?['date_of_birth'] as String?)?.trim(),
    );
    final gender = (_user.userMetadata?['gender'] as String?)?.trim();

    return ContinuousImmersiveScene(
      assetName: GeneratedImageAssets.profileContinuousScene,
      semanticLabel: 'A calm cafe corner with an open chair',
      compactExtent: 650,
      regularExtent: 720,
      alignment: Alignment.topRight,
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final horizontal = responsiveHorizontalPadding(width);
              final maxWidth = responsiveContentMaxWidth(width);
              final wideProfile = isWideContentWidth(width);

              return ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  0,
                  MediaQuery.paddingOf(context).top + 12,
                  0,
                  112,
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ProfileBrandBar(
                              unreadCount: widget.unreadNotificationCount,
                              onOpenNotifications: widget.onOpenNotifications,
                            ),
                            const SizedBox(height: 24),
                            _ProfileHeaderCard(
                              motionIndex: 1,
                              avatar: _buildProfileAvatar(),
                              firstName: displayName,
                              email: email,
                              bio: bio,
                            ),
                            const SizedBox(height: 18),
                            if (wideProfile)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      children: [
                                        _ProfileDetailsCard(
                                          motionIndex: 2,
                                          firstName: displayName,
                                          bio: bioValue,
                                          dateOfBirth: dateOfBirth,
                                          gender: gender?.isNotEmpty == true
                                              ? gender
                                              : null,
                                          isSaving: _isSaving,
                                          onEditName: () => _editName(
                                            initialValue: firstName ?? '',
                                          ),
                                          onEditBio: () => _editBio(
                                            initialValue: bioValue,
                                          ),
                                          onEditBirthDate: _pickBirthDate,
                                          onEditGender: () => _pickSingleOption(
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
                                        const SizedBox(height: 18),
                                        _ProfileInterestsCard(
                                          motionIndex: 3,
                                          interests: interestValues,
                                          isSaving: _isSaving,
                                          onEdit: () =>
                                              _editInterests(interestValues),
                                        ),
                                        const SizedBox(height: 18),
                                        _ProfilePreferencesCard(
                                          motionIndex: 4,
                                          city: city,
                                          language: language,
                                          isSaving: _isSaving,
                                          onPickCity: () => _pickSingleOption(
                                            title: 'City',
                                            metadataKey: 'city',
                                            options: _cityOptions,
                                          ),
                                          onPickLanguage: () =>
                                              _pickSingleOption(
                                            title: 'Language',
                                            metadataKey: 'language',
                                            options: const [
                                              'English',
                                              'Dutch',
                                              'Both',
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        _ProfileAccountCard(
                                          motionIndex: 5,
                                          email: email,
                                          isSigningOut: widget.isSigningOut,
                                          onSignOut: widget.onSignOut,
                                        ),
                                        const SizedBox(height: 18),
                                        _ProfileHelpCard(
                                          motionIndex: 6,
                                          onOpenWhatsAppSupport:
                                              _openWhatsAppSupport,
                                          onOpenSafetyPage: _openSafetyPage,
                                          onOpenFaqPage: _openFaqPage,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _ProfileDetailsCard(
                                motionIndex: 2,
                                firstName: displayName,
                                bio: bioValue,
                                dateOfBirth: dateOfBirth,
                                gender:
                                    gender?.isNotEmpty == true ? gender : null,
                                isSaving: _isSaving,
                                onEditName: () => _editName(
                                  initialValue: firstName ?? '',
                                ),
                                onEditBio: () =>
                                    _editBio(initialValue: bioValue),
                                onEditBirthDate: _pickBirthDate,
                                onEditGender: () => _pickSingleOption(
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
                              const SizedBox(height: 18),
                              _ProfileInterestsCard(
                                motionIndex: 3,
                                interests: interestValues,
                                isSaving: _isSaving,
                                onEdit: () => _editInterests(interestValues),
                              ),
                              const SizedBox(height: 18),
                              _ProfilePreferencesCard(
                                motionIndex: 4,
                                city: city,
                                language: language,
                                isSaving: _isSaving,
                                onPickCity: () => _pickSingleOption(
                                  title: 'City',
                                  metadataKey: 'city',
                                  options: _cityOptions,
                                ),
                                onPickLanguage: () => _pickSingleOption(
                                  title: 'Language',
                                  metadataKey: 'language',
                                  options: const [
                                    'English',
                                    'Dutch',
                                    'Both',
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              _ProfileAccountCard(
                                motionIndex: 5,
                                email: email,
                                isSigningOut: widget.isSigningOut,
                                onSignOut: widget.onSignOut,
                              ),
                              const SizedBox(height: 18),
                              _ProfileHelpCard(
                                motionIndex: 6,
                                onOpenWhatsAppSupport: _openWhatsAppSupport,
                                onOpenSafetyPage: _openSafetyPage,
                                onOpenFaqPage: _openFaqPage,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (_isSaving)
            Positioned(
              top: 16,
              right: 16,
              child: Semantics(
                liveRegion: true,
                label: 'Saving profile changes',
                child: ExcludeSemantics(
                  child: Chip(label: Text('Saving changes...')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _displaySingleOptionValue(String metadataKey, String? value) {
    if (metadataKey == 'language') {
      return _displayLanguageValue(value);
    }
    return value;
  }

  String _displayLanguageValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'English';
    }
    return trimmed;
  }

  String _displayDateOfBirth(String? value) {
    if (value == null || value.isEmpty) return 'Not added';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return 'Not added';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
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
          searchHintText: metadataKey == 'city' ? 'Search cities' : null,
          emptyStateTitle: metadataKey == 'city' ? 'No matching cities' : null,
          emptyStateBody: metadataKey == 'city'
              ? 'Try another search. New meetup cities are added as they become available.'
              : null,
        );
      },
    );

    if (picked == null) return;
    if (picked == currentValue && picked == rawCurrentValue) return;
    await _saveMetadata({metadataKey: picked});
  }

  Future<void> _editInterests(List<String> currentInterests) async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _MultiSelectSheet(
          title: 'Edit interests',
          description: "Choose the kinds of meetups you'd enjoy.",
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
          description: 'This is the name people at your meetup will see.',
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
              'Share one easy conversation starter for when you arrive.',
          hintText: 'Always up for a good conversation',
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
              'Used to confirm you are 18+. It is never shown to other members.',
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

  Future<void> _openWhatsAppSupport() async {
    final uri = Uri.parse('https://wa.me/31685660139');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted || launched) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("We couldn't open WhatsApp. Try again in a moment."),
      ),
    );
  }

  void _openFaqPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _FaqPage(),
      ),
    );
  }

  void _openSafetyPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _SafetyPage(),
      ),
    );
  }

  Future<void> _changeProfilePhoto() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = error.code == 'ENTITLEMENT_NOT_FOUND'
          ? 'Photo access is unavailable. Check your device permissions and try again.'
          : "We couldn't open your photos. Try again.";
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
          content: Text(
            "We couldn't read that image. Choose a JPG, PNG, or WebP file.",
          ),
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

    if (!ProfilePhotoService.hasSupportedImageSignature(file.bytes!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a valid JPG, PNG, or WebP image.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final previousPhotoPath =
          (_user.userMetadata?['profile_photo_path'] as String?) ??
              _profilePhotoPath;
      final photoPath = await ProfilePhotoService.uploadPhoto(
        supabase: Supabase.instance.client,
        userId: _user.id,
        bytes: file.bytes!,
        fileName: file.name,
        slot: 'primary',
      );
      ProfilePhotoService.invalidateSignedPhotoUrl(previousPhotoPath);
      ProfilePhotoService.invalidateSignedPhotoUrl(photoPath);

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
          content: Text(ProfilePhotoService.uploadErrorMessage(error)),
        ),
      );
      setState(() => _isSaving = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ProfilePhotoService.genericUploadErrorMessage),
        ),
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
          _profilePhotoPath = mergedMetadata['profile_photo_path'] as String?;
          _profilePhotoBytes = nextProfilePhotoBytes;
          _profilePhotoUrl = null;
          _profilePhotoFailedToRender = false;
        }
      });
      widget.onUserUpdated?.call(response.user ?? _user);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved.')),
      );
    } on AuthException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
          'We could not save your changes. Check your connection and try again.',
        )),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
          'We could not save your changes. Check your connection and try again.',
        )),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _loadProfilePhoto() async {
    final loadVersion = ++_profilePhotoLoadVersion;
    var photoPath = _user.userMetadata?['profile_photo_path'] as String?;
    if ((photoPath == null || photoPath.isEmpty) && _user.id.isNotEmpty) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('profile_photo_path')
            .eq('id', _user.id)
            .maybeSingle();
        if (!mounted || loadVersion != _profilePhotoLoadVersion) return;
        photoPath = response?['profile_photo_path'] as String?;
      } catch (_) {
        // Ignore fallback lookup errors and leave the avatar in its default state.
      }
    }

    if (photoPath == null || photoPath.isEmpty) {
      if (!mounted || loadVersion != _profilePhotoLoadVersion) return;
      setState(() {
        _profilePhotoPath = null;
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
      final signedUrl = await ProfilePhotoService.createSignedPhotoUrl(
        supabase: Supabase.instance.client,
        path: photoPath,
      );
      if (!mounted || loadVersion != _profilePhotoLoadVersion) return;
      if (signedUrl != null && signedUrl.isNotEmpty) {
        setState(() {
          _profilePhotoPath = photoPath;
          _profilePhotoBytes = null;
          _profilePhotoUrl = signedUrl;
        });
        return;
      }
    } catch (_) {
      try {
        final bytes = await ProfilePhotoService.downloadPhoto(
          supabase: Supabase.instance.client,
          path: photoPath,
        );
        if (!mounted || loadVersion != _profilePhotoLoadVersion) return;
        if (bytes != null) {
          setState(() {
            _profilePhotoPath = photoPath;
            _profilePhotoBytes = bytes;
            _profilePhotoUrl = null;
          });
          return;
        }
      } catch (_) {
        if (!mounted || loadVersion != _profilePhotoLoadVersion) return;
        setState(() {
          _profilePhotoPath = null;
          _profilePhotoBytes = null;
          _profilePhotoUrl = null;
        });
      }
    } finally {
      if (mounted && loadVersion == _profilePhotoLoadVersion) {
        setState(() => _isLoadingPhoto = false);
      }
    }
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

  Widget _buildProfileAvatar() {
    final shouldShowPhoto = !_profilePhotoFailedToRender &&
        (_profilePhotoBytes != null ||
            (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty));
    final photoActionLabel =
        shouldShowPhoto ? 'Replace profile photo' : 'Add profile photo';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 118,
          height: 118,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Semantics(
                  button: shouldShowPhoto,
                  image: !shouldShowPhoto,
                  label: shouldShowPhoto
                      ? 'Profile photo'
                      : 'Default profile image',
                  hint: shouldShowPhoto ? 'Open full-size preview' : null,
                  child: ExcludeSemantics(
                    child: InkWell(
                      onTap: shouldShowPhoto ? _openProfilePhotoPreview : null,
                      borderRadius: BorderRadius.circular(32),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F4F2),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 4,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14062B55),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                          gradient: !shouldShowPhoto
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF062B55),
                                    Color(0xFF36B8A5),
                                  ],
                                )
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: shouldShowPhoto
                              ? _buildPhotoWidget(fit: BoxFit.cover)
                              : const Center(
                                  child: _DefaultAvatarIllustration(),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Tooltip(
                  message: photoActionLabel,
                  child: Semantics(
                    button: true,
                    enabled: !_isSaving,
                    label: photoActionLabel,
                    child: ExcludeSemantics(
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          onTap: _isSaving ? null : _changeProfilePhoto,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: _isLoadingPhoto || _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 18,
                                      color: Color(0xFF138B8A),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${ProfilePhotoService.supportedFormatsLabel} · max ${ProfilePhotoService.maxUploadLabel}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF60727A),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
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
                              semanticLabel: 'Profile photo preview',
                              errorBuilder: (_, __, ___) =>
                                  const _PhotoPreviewFallback(),
                            )
                          : Image.network(
                              url!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              filterQuality: FilterQuality.medium,
                              semanticLabel: 'Profile photo preview',
                              errorBuilder: (_, __, ___) =>
                                  const _PhotoPreviewFallback(),
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
    const cacheDimension = 320;

    if (_profilePhotoBytes != null) {
      return Image.memory(
        _profilePhotoBytes!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheDimension,
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
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _buildPhotoFailureFallback(),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPhotoFailureFallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _profilePhotoFailedToRender) return;
      final photoPath = _profilePhotoPath;
      if (!_isRecoveringProfilePhotoUrl &&
          photoPath != null &&
          photoPath.isNotEmpty &&
          _profilePhotoUrl != null) {
        unawaited(_refreshExpiredProfilePhotoUrl(photoPath));
        return;
      }
      setState(() => _profilePhotoFailedToRender = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "We couldn't display your photo. Try replacing it with a JPG, PNG, or WebP file.",
          ),
        ),
      );
    });

    return const SizedBox.shrink();
  }

  Future<void> _refreshExpiredProfilePhotoUrl(String photoPath) async {
    _isRecoveringProfilePhotoUrl = true;
    try {
      final signedUrl = await ProfilePhotoService.createSignedPhotoUrl(
        supabase: Supabase.instance.client,
        path: photoPath,
        forceRefresh: true,
      );
      if (!mounted || signedUrl == null || signedUrl.isEmpty) return;
      setState(() {
        _profilePhotoUrl = signedUrl;
        _profilePhotoFailedToRender = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _profilePhotoFailedToRender = true);
    } finally {
      _isRecoveringProfilePhotoUrl = false;
    }
  }
}

class _DefaultAvatarIllustration extends StatelessWidget {
  const _DefaultAvatarIllustration();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Image.asset(
        GeneratedImageAssets.profileDefaultAvatar,
        fit: BoxFit.contain,
        cacheWidth: 240,
        cacheHeight: 240,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.person_rounded,
            size: 82,
            color: Colors.white,
          );
        },
      ),
    );
  }
}

class _PhotoPreviewFallback extends StatelessWidget {
  const _PhotoPreviewFallback();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "We couldn't display this photo.",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

String _displayProfileName(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return 'Member';
  }

  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

class _ProfileBrandBar extends StatelessWidget {
  const _ProfileBrandBar({
    required this.unreadCount,
    required this.onOpenNotifications,
  });

  final int unreadCount;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return AppShellHeader(
      unreadCount: unreadCount,
      onOpenNotifications: onOpenNotifications,
      logoSize: 42,
      foregroundColor: const Color(0xFF062B55),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.motionIndex,
    required this.avatar,
    required this.firstName,
    required this.email,
    required this.bio,
  });

  final int motionIndex;
  final Widget avatar;
  final String firstName;
  final String email;
  final String? bio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryCopy = (bio != null && bio!.trim().isNotEmpty)
        ? bio!.trim()
        : 'Your private space for details and meetup preferences.';

    Widget identity({required TextAlign textAlign}) => Column(
          crossAxisAlignment: textAlign == TextAlign.left
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Text(
              firstName,
              textAlign: textAlign,
              style: responsiveHeadlineStyle(
                context,
                color: const Color(0xFF062B55),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              textAlign: textAlign,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF60727A),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                summaryCopy,
                textAlign: textAlign,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF385866),
                  height: 1.35,
                ),
              ),
            ),
          ],
        );

    return MotionReveal(
      index: motionIndex,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              const Color(0xFFFFFCF7).withValues(alpha: 0.90),
              const Color(0xFFFFFCF7).withValues(alpha: 0.62),
              const Color(0xFFFFFCF7).withValues(alpha: 0.12),
            ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(
                children: [
                  avatar,
                  const SizedBox(height: 14),
                  identity(textAlign: TextAlign.center),
                ],
              );
            }
            return Row(
              children: [
                avatar,
                const SizedBox(width: 24),
                Expanded(child: identity(textAlign: TextAlign.left)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({
    required this.motionIndex,
    required this.firstName,
    required this.bio,
    required this.dateOfBirth,
    required this.gender,
    required this.isSaving,
    required this.onEditName,
    required this.onEditBio,
    required this.onEditBirthDate,
    required this.onEditGender,
  });

  final int motionIndex;
  final String firstName;
  final String bio;
  final String dateOfBirth;
  final String? gender;
  final bool isSaving;
  final VoidCallback onEditName;
  final VoidCallback onEditBio;
  final VoidCallback onEditBirthDate;
  final VoidCallback onEditGender;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      motionIndex: motionIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile details',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _EditableProfileRow(
            icon: Icons.badge_outlined,
            label: 'Name',
            value: firstName,
            onTap: isSaving ? null : onEditName,
          ),
          const SizedBox(height: 8),
          _EditableProfileRow(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Intro',
            value: bio.trim().isEmpty ? 'Add intro' : bio.trim(),
            onTap: isSaving ? null : onEditBio,
          ),
          const SizedBox(height: 8),
          _EditableProfileRow(
            icon: Icons.cake_outlined,
            label: 'Date of birth · Private',
            value: dateOfBirth,
            onTap: isSaving ? null : onEditBirthDate,
          ),
          const SizedBox(height: 8),
          _EditableProfileRow(
            icon: Icons.person_outline,
            label: 'Gender · Private',
            value: gender ?? 'Not added',
            onTap: isSaving ? null : onEditGender,
          ),
        ],
      ),
    );
  }
}

class _ProfileInterestChip extends StatelessWidget {
  const _ProfileInterestChip({
    required this.label,
    this.icon,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  IconData get _resolvedIcon {
    if (icon != null) return icon!;
    switch (label.toLowerCase()) {
      case 'coffee':
        return Icons.local_cafe_outlined;
      case 'brunch':
      case 'lunch':
      case 'dinner':
      case 'food':
        return Icons.restaurant_outlined;
      case 'walk':
      case 'walks':
        return Icons.park_outlined;
      case 'culture':
        return Icons.account_balance_outlined;
      case 'books':
        return Icons.menu_book_outlined;
      case 'music':
        return Icons.music_note_outlined;
      case 'travel':
        return Icons.flight_outlined;
      default:
        return Icons.favorite_border_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEAF7F5),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _resolvedIcon,
                size: 18,
                color: const Color(0xFF138B8A),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF138B8A),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInterestsCard extends StatelessWidget {
  const _ProfileInterestsCard({
    required this.motionIndex,
    required this.interests,
    required this.isSaving,
    required this.onEdit,
  });

  final int motionIndex;
  final List<String> interests;
  final bool isSaving;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      motionIndex: motionIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileCardHeader(
            title: 'Interests',
            accentColor: const Color(0xFFEAF4F6),
            onTap: isSaving || interests.isEmpty ? null : onEdit,
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: interests.isNotEmpty
                ? interests
                    .map((interest) => _ProfileInterestChip(label: interest))
                    .toList()
                : [
                    _ProfileInterestChip(
                      label: 'Add interests',
                      icon: Icons.add_rounded,
                      onTap: isSaving ? null : onEdit,
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _ProfilePreferencesCard extends StatelessWidget {
  const _ProfilePreferencesCard({
    required this.motionIndex,
    required this.city,
    required this.language,
    required this.isSaving,
    required this.onPickCity,
    required this.onPickLanguage,
  });

  final int motionIndex;
  final String? city;
  final String language;
  final bool isSaving;
  final VoidCallback onPickCity;
  final VoidCallback onPickLanguage;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      motionIndex: motionIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferences',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          _EditableProfileRow(
            icon: Icons.location_on_outlined,
            label: 'City',
            value: city?.isNotEmpty == true ? city! : 'Choose your city',
            onTap: isSaving ? null : onPickCity,
          ),
          const SizedBox(height: 10),
          _EditableProfileRow(
            icon: Icons.language_rounded,
            label: 'Language',
            value: language,
            onTap: isSaving ? null : onPickLanguage,
          ),
        ],
      ),
    );
  }
}

class _ProfileAccountCard extends StatelessWidget {
  const _ProfileAccountCard({
    required this.motionIndex,
    required this.email,
    required this.isSigningOut,
    required this.onSignOut,
  });

  final int motionIndex;
  final String email;
  final bool isSigningOut;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      motionIndex: motionIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _AccountDetailRow(
            label: 'Email',
            value: email,
            icon: Icons.mail_outline,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSigningOut ? null : onSignOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(isSigningOut ? 'Signing out...' : 'Sign out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF062B55),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF9CA9AE),
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHelpCard extends StatelessWidget {
  const _ProfileHelpCard({
    required this.motionIndex,
    required this.onOpenWhatsAppSupport,
    required this.onOpenSafetyPage,
    required this.onOpenFaqPage,
  });

  final int motionIndex;
  final VoidCallback onOpenWhatsAppSupport;
  final VoidCallback onOpenSafetyPage;
  final VoidCallback onOpenFaqPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SectionCard(
      motionIndex: motionIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Support', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Get help, review safety guidance, or find quick answers.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF60727A),
            ),
          ),
          const SizedBox(height: 16),
          _NavigationTile(
            label: 'Contact us',
            value: 'Chat with our team on WhatsApp',
            semanticHint: 'Opens WhatsApp',
            onTap: onOpenWhatsAppSupport,
          ),
          _NavigationTile(
            label: 'Safety',
            value: 'Guidance for feeling comfortable and getting help',
            onTap: onOpenSafetyPage,
          ),
          _NavigationTile(
            label: 'FAQs',
            value: 'Common questions about meetups',
            onTap: onOpenFaqPage,
          ),
        ],
      ),
    );
  }
}

class _EditableProfileRow extends StatelessWidget {
  const _EditableProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label. $value',
      hint: enabled ? 'Edit $label' : 'Profile changes are being saved',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDDE7E3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF7F5),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: const Color(0xFF138B8A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF60727A),
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF062B55),
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF60727A),
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

class _ProfileCardHeader extends StatelessWidget {
  const _ProfileCardHeader({
    required this.title,
    this.onTap,
    this.accentColor = const Color(0xFFEAF7F5),
  });

  final String title;
  final VoidCallback? onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (onTap != null)
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit ${title.toLowerCase()}',
            style: IconButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: const Color(0xFF062B55),
              side: BorderSide(color: accentColor.withValues(alpha: 0.9)),
            ),
          ),
      ],
    );
  }
}

class _FaqPage extends StatelessWidget {
  const _FaqPage();

  @override
  Widget build(BuildContext context) {
    return _HelpArticlePage(
      title: 'FAQs',
      intro: 'Quick answers about meetups, timing, and expectations.',
      children: const [
        _HelpAnswerCard(
          icon: Icons.location_on_outlined,
          title: 'When do I get the exact location?',
          body: 'The area is shown before you reserve. The exact venue appears '
              'in your VriendTime notifications at 10:00 on the date shown '
              'in your reservation.',
        ),
        _HelpAnswerCard(
          icon: Icons.event_repeat_outlined,
          title: 'Can I change or cancel my meetup?',
          body:
              'You can cancel until 12 hours before the meetup starts. Changes depend on another suitable meetup still being open, so they are not guaranteed.',
        ),
        _HelpAnswerCard(
          icon: Icons.groups_2_outlined,
          title: 'What is expected at the table?',
          body:
              'Come as you are and be kind. Keeping the meetup phone-free gives everyone more room to connect.',
        ),
      ],
    );
  }
}

class _SafetyPage extends StatelessWidget {
  const _SafetyPage();

  @override
  Widget build(BuildContext context) {
    return _HelpArticlePage(
      title: 'Safety',
      intro:
          'A few simple guidelines to help everyone feel comfortable arriving and meeting new people.',
      children: const [
        _HelpAnswerCard(
          icon: Icons.health_and_safety_outlined,
          title: 'Trust your instincts',
          body:
              "You can leave at any time. If something doesn't feel right, move somewhere safe and contact us.",
        ),
        _HelpAnswerCard(
          icon: Icons.people_outline,
          title: 'Meet in the planned setting',
          body:
              'Stay at the location shared in the app. If plans change, only go somewhere you feel comfortable.',
        ),
        _HelpAnswerCard(
          icon: Icons.support_agent_outlined,
          title: 'Reach out when needed',
          body:
              'Open Contact us from your profile to message the team directly on WhatsApp.',
        ),
      ],
    );
  }
}

class _HelpArticlePage extends StatelessWidget {
  const _HelpArticlePage({
    required this.title,
    required this.intro,
    required this.children,
  });

  final String title;
  final String intro;
  final List<Widget> children;

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
              final horizontal = responsiveHorizontalPadding(
                constraints.maxWidth,
              );
              final maxWidth = responsiveContentMaxWidth(constraints.maxWidth);

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                              tooltip: 'Back to profile',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.92,
                                ),
                                foregroundColor: const Color(0xFF062B55),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.headlineSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          intro,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF60727A),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ...children.map(
                          (child) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: child,
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
      ),
    );
  }
}

class _HelpAnswerCard extends StatelessWidget {
  const _HelpAnswerCard({
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE7E3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F4F2),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: const Color(0xFF138B8A), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
                const SizedBox(height: 6),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.semanticHint,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. $value',
      hint: semanticHint ?? 'Open $label',
      child: ExcludeSemantics(
        child: InkWell(
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final labelText = Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  );
                  final valueText = Text(
                    value,
                    textAlign: compact ? TextAlign.left : TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium,
                  );

                  if (compact) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              labelText,
                              const SizedBox(height: 6),
                              valueText,
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: labelText),
                      const SizedBox(width: 16),
                      Expanded(child: valueText),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  );
                },
              ),
            ),
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
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
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
                      textCapitalization: widget.maxLines == 1
                          ? TextCapitalization.words
                          : TextCapitalization.sentences,
                      textInputAction: widget.maxLines == 1
                          ? TextInputAction.done
                          : TextInputAction.newline,
                      onSubmitted: widget.maxLines == 1
                          ? (_) =>
                              Navigator.of(context).pop(_controller.text.trim())
                          : null,
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
                            onPressed: () => Navigator.of(context)
                                .pop(_controller.text.trim()),
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBF8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(widget.description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                              Navigator.of(context).pop(_selected.toList()),
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
      ),
    );
  }
}
