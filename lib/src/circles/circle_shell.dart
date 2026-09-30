import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../core/profile_photo_service.dart';
import 'circle_profile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/account_deletion_service.dart';
import '../screens/auth_flow_screen.dart';
import '../screens/legal_document_screen.dart';
import '../screens/profile_screen.dart';
import '../widgets/brand_logo.dart';
import '../widgets/circle_loading.dart';
import '../widgets/continuous_immersive_scene.dart';
import '../widgets/floating_glass_navigation.dart';
import 'circle_admin.dart';
import 'circle_application.dart';
import 'circle_home.dart';
import 'circle_landing.dart';
import 'circle_past_meetups.dart';
import 'circle_repository.dart';
import 'circle_widgets.dart';

class CircleShell extends StatefulWidget {
  const CircleShell({super.key, required this.session, this.repository});
  final Session? session;
  final CircleRepository? repository;
  @override
  State<CircleShell> createState() => _CircleShellState();
}

class _CircleShellState extends State<CircleShell> {
  CircleRepository? repo;
  Json? state;
  String? error;
  bool busy = false, auth = false, signIn = false, editing = false;
  bool _authDialogOpen = false;

  /// Set when someone saves an unsubmitted application for later, so the
  /// home tab shows a "continue" card instead of reopening the form.
  bool applicationParked = false;
  int tab = 0;
  int editStep = 0;
  final message = TextEditingController();
  final scroll = ScrollController();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    repo = widget.repository;
    if (repo != null) {
      load();
    } else if (const bool.fromEnvironment('CIRCLES_ENABLE_PREVIEW') &&
        Uri.base.queryParameters['preview'] == '1') {
      preview();
    } else if (widget.session != null) {
      repo = SupabaseCircleRepository(Supabase.instance.client);
      load();
    }
    timer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (repo != null && !busy && !editing) load(silent: true);
    });
  }

  @override
  void didUpdateWidget(covariant CircleShell old) {
    super.didUpdateWidget(old);
    if (old.session?.user.id != widget.session?.user.id &&
        repo?.isDemo != true) {
      state = null;
      error = null;
      tab = 0;
      auth = false;
      repo = widget.session == null
          ? null
          : SupabaseCircleRepository(Supabase.instance.client);
      if (repo != null) load();
    }
    // Signing in from the modal leaves the dialog sitting on top of the
    // signed-in app, because the dialog is its own route rather than part
    // of this tree. Close it for any route into a session: sign in, sign
    // up, an email link, or a restored session.
    if (_authDialogOpen && widget.session != null) {
      _authDialogOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    message.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> preview() async {
    final prefs = await SharedPreferences.getInstance();
    final demo = DemoCircleRepository(prefs);
    if (!prefs.containsKey(DemoCircleRepository.storageKey)) {
      await demo.act('preview', {'stage': 'active'});
    }
    if (!mounted) return;
    setState(() {
      repo = demo;
      state = null;
      auth = false;
      tab = 0;
    });
    await load();
  }

  Future<void> load({bool silent = false}) async {
    final source = repo;
    if (source == null) return;
    try {
      final value = await source.load();
      if (mounted && identical(repo, source)) {
        setState(() {
          state = value;
          error = null;
        });
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() => error =
            'We couldn’t load your Circle right now. Please try again in a moment.');
      }
    }
  }

  Future<void> act(String action, [Json data = const {}]) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await repo!.act(action, data);
      await load();
      if (mounted) {
        if (['apply', 'withdraw', 'preview', 'reset'].contains(action)) {
          setState(() {
            editing = false;
            tab = 0;
          });
          if (scroll.hasClients) scroll.jumpTo(0);
        }
        if ([
          'draft',
          'check_in',
          'outcome',
          'schedule',
          'refund',
          'refresh_commitment',
          'exclude',
          'email_notifications',
          'leave_circle'
        ].contains(action)) {
          showCircleToast(
              context,
              switch (action) {
                'draft' => 'Your answers are saved.',
                'refresh_commitment' => 'Availability confirmed.',
                'exclude' => 'Noted. This stays between you and us.',
                'email_notifications' => data['enabled'] == true
                    ? 'We’ll email you about your Circle.'
                    : 'Emails turned off. Your Circle updates stay in the app.',
                'leave_circle' =>
                  'You’ve left the Circle. We’ll be in touch about anything outstanding.',
                _ => 'Saved.'
              });
        }
      }
    } catch (e) {
      if (mounted) {
        showCircleToast(
            context,
            icon: Icons.error_outline_rounded,
            (e is StateError
                ? e.message
                : e is PostgrestException
                    ? e.message
                    : 'We couldn’t save that change. Please try again.'));
      }
      rethrow;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> safeAct(String action, [Json data = const {}]) async {
    try {
      await act(action, data);
    } catch (_) {}
  }

  void openAdmin() {
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) =>
                CircleAdmin(repository: repo!, onChanged: () => load())));
  }

  bool get _authAsModal => MediaQuery.sizeOf(context).width >= 760;

  void _openAuth({required bool signIn}) {
    if (_authAsModal) {
      // Sign in is a much shorter form than sign up (two fields vs five
      // plus terms); size the dialog to whichever tab is opening so it
      // doesn't leave a slab of empty space below a short form. Switching
      // tabs inside the dialog still works fine — the content scrolls
      // internally if it outgrows this initial size.
      final dialogHeight = signIn ? 560.0 : 780.0;
      _authDialogOpen = true;
      showDialog<void>(
              context: context,
              barrierColor: circleNavy.withValues(alpha: .45),
              builder: (dialogContext) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Center(
                      child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: 560, maxHeight: dialogHeight),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: AuthFlowScreen(
                                  circleMode: true,
                                  presentedAsModal: true,
                                  initialEvents: const [],
                                  initialCityOptions: const ['Alkmaar'],
                                  startInSignIn: signIn,
                                  onClose: () =>
                                      Navigator.of(dialogContext).pop()))))))
          .whenComplete(() => _authDialogOpen = false);
      return;
    }
    setState(() {
      auth = true;
      this.signIn = signIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (repo == null) {
      if (auth && !_authAsModal) {
        return AuthFlowScreen(
            circleMode: true,
            initialEvents: const [],
            initialCityOptions: const ['Alkmaar'],
            startInSignIn: signIn,
            onClose: () => setState(() => auth = false));
      }
      return CircleLanding(
          onApply: () => _openAuth(signIn: false),
          onSignIn: () => _openAuth(signIn: true));
    }
    final demo = repo!.isDemo;
    return Scaffold(
        extendBody: true,
        body: ContinuousImmersiveScene(
            assetName: tab == 2
                ? 'assets/generated/profile-continuous-scene-v3.webp'
                : 'assets/generated/home-continuous-scene-v3.webp',
            child: SafeArea(
                bottom: false,
                child: Column(children: [
                  if (demo)
                    Container(
                        width: double.infinity,
                        color: const Color(0xFFE4F3EF),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Row(children: [
                          const Icon(Icons.science_outlined,
                              size: 17, color: circleTeal),
                          const SizedBox(width: 8),
                          const Expanded(
                              child: Text(
                                  'Preview · example people · no charges',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700))),
                          PopupMenuButton<String>(
                              tooltip: 'Explore preview stages',
                              onSelected: (v) => safeAct(
                                  v == 'reset' ? 'reset' : 'preview',
                                  {'stage': v}),
                              itemBuilder: (_) => [
                                    for (final e in {
                                      'apply': 'Application',
                                      'waiting': 'Waiting for a Circle',
                                      'invited': 'Circle invitation',
                                      'active': 'Six-week experience',
                                      'completed': 'Graduation',
                                      'reset': 'Reset preview'
                                    }.entries)
                                      PopupMenuItem(
                                          value: e.key, child: Text(e.value))
                                  ],
                              child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Text('Explore ▾',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800))))
                        ])),
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      child: Row(children: [
                        const Expanded(
                            child: BrandLockup(
                                logoSize: 38, foregroundColor: circleNavy)),
                        if (state?['is_admin'] == true)
                          IconButton(
                              onPressed: openAdmin,
                              tooltip: 'Circle organiser',
                              icon: const Icon(Icons.tune_rounded)),
                        IconButton(
                            onPressed: () => _notifications(context),
                            tooltip: 'Notifications',
                            icon: Badge(
                                isLabelVisible:
                                    (state?['unread_notifications'] as num? ??
                                            0) >
                                        0,
                                child: const Icon(
                                    Icons.notifications_none_rounded))),
                        if (demo)
                          IconButton(
                              onPressed: () {
                                setState(() {
                                  repo = widget.session == null
                                      ? null
                                      : SupabaseCircleRepository(
                                          Supabase.instance.client);
                                  state = null;
                                  tab = 0;
                                });
                                if (repo != null) load();
                              },
                              tooltip: 'Exit preview',
                              icon: const Icon(Icons.close))
                      ])),
                  Expanded(
                      child: state == null
                          ? Center(
                              child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: error == null
                                      ? const CircleLoading()
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                              Text(error!,
                                                  textAlign: TextAlign.center),
                                              const SizedBox(height: 20),
                                              ElevatedButton(
                                                  onPressed: load,
                                                  child:
                                                      const Text('Try again')),
                                              TextButton(
                                                  onPressed: () => Supabase
                                                      .instance.client.auth
                                                      .signOut(),
                                                  child: const Text('Sign out'))
                                            ])))
                          : RefreshIndicator(
                              onRefresh: load,
                              child: SingleChildScrollView(
                                  controller: scroll,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                      22, 16, 22, 130),
                                  child: Center(
                                      child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 900),
                                          child: _body(context)))))),
                ]))),
        bottomNavigationBar: repo == null
            ? null
            : SafeArea(
                child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: FloatingGlassNavigation(
                                height: 70,
                                circleMode: true,
                                selectedIndex: tab,
                                onDestinationSelected: (v) {
                                  setState(() => tab = v);
                                  if (scroll.hasClients) scroll.jumpTo(0);
                                }))))));
  }

  void _openApplication(int step) => setState(() {
        editing = true;
        editStep = step;
        applicationParked = false;
        tab = 0;
      });

  Widget _body(BuildContext context) {
    if (tab == 1) return _messages(context);
    if (tab == 2) return _profile(context);
    if (editing || (state!['stage'] == 'apply' && !applicationParked)) {
      // A focused edit is one answer being changed from the profile or home
      // — never "Continue my application" or "Finish my profile", which both
      // open at step 0 and must keep the whole four-step walk.
      final focused = editing && editStep > 0;
      return CircleApplication(
          key: ValueKey(editing ? 'edit' : 'apply'),
          initial: Map<String, dynamic>.from(state!['application'] as Map? ??
              {'name': widget.session?.user.userMetadata?['first_name'] ?? ''}),
          busy: busy,
          initialStep: editing ? editStep : 0,
          focusedEdit: focused,
          onDone: () => setState(() {
                editing = false;
                editStep = 0;
                // Closing a focused edit is not enough on its own: an
                // application still in the 'apply' stage matches the second
                // clause of the condition above, so the full four-step form
                // would re-open at step 0 the instant this one closed —
                // which reads as "saving my availability restarted my
                // onboarding". Park it so they land on the home card.
                if (state?['stage'] == 'apply') applicationParked = true;
              }),
          onPhoto: repo!.isDemo ? null : _pickPhoto,
          onSave: (d) => act('draft', d),
          onSubmit: (d) => act('apply', d),
          // Leaving the form needs somewhere to land; for an unsubmitted
          // application that is the home tab's "continue" card.
          onSaveForLater: () => setState(() {
                editing = false;
                editStep = 0;
                applicationParked = true;
              }));
    }
    return CircleHome(
        state: state!,
        demo: repo!.isDemo,
        busy: busy,
        act: safeAct,
        onEdit: _openApplication,
        onMessages: () => setState(() => tab = 1));
  }

  Widget _messages(BuildContext context) {
    final enabled = ['active', 'completed'].contains(state!['stage']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CircleHeading('A little hello goes a long way.',
          eyebrow: 'Circle messages',
          subtitle:
              'The place for plans, small updates, and “see you Thursday”.'),
      if (!enabled)
        const CirclePanel(children: [
          Icon(Icons.chat_bubble_outline_rounded, color: circleTeal, size: 32),
          SizedBox(height: 14),
          Text(
              'Your group conversation opens when you join your Circle. We’ll keep your place here.')
        ])
      else ...[
        for (final m in rows(state!['messages']))
          Align(
              alignment: m['own'] == true
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: m['own'] == true
                          ? const Color(0xFFDFF1EA)
                          : const Color(0xFFFFFCF7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDDE7E3))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['name'] as String? ?? 'Circle member',
                            style: const TextStyle(
                                color: circleTeal,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        SelectableText(m['body'] as String),
                        if (m['created_at'] != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                  circleDate(m['created_at'].toString()),
                                  style:
                                      Theme.of(context).textTheme.labelSmall)),
                        if (m['own'] != true && m['id'] != null)
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () => _report(messageId: m['id'] as String),
                              child: const Text('Report message'))
                      ]))),
        if (rows(state!['messages']).isEmpty)
          const Text('Be the first to say hello.'),
        const SizedBox(height: 10),
        CirclePanel(children: [
          TextField(
              controller: message,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                  hintText: 'Say hello, suggest a plan…',
                  labelText: 'Message your Circle')),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (message.text.trim().isEmpty) return;
                      try {
                        await act('message', {'body': message.text.trim()});
                        message.clear();
                      } catch (_) {}
                    },
              child: const Text('Send message'))
        ]),
        const SizedBox(height: 12),
        const Text(
            'Your Circle can read this conversation. Organisers can review reported messages. Be kind, and ask before sharing someone’s personal details.')
      ]
    ]);
  }

  Widget _profile(BuildContext context) => CircleProfile(
        state: state!,
        onEdit: ['apply', 'waiting'].contains(state!['stage'])
            ? _openApplication
            : null,
        onPhoto: repo!.isDemo
            ? null
            : () async {
                try {
                  await _pickPhoto();
                  await load(silent: true);
                } catch (_) {}
              },
        // safeAct, not act: a failed toggle should leave the switch where it
        // was with a message, not throw out of a callback that returns void.
        onEmailNotifications: repo!.isDemo
            ? null
            : (enabled) => safeAct('email_notifications', {'enabled': enabled}),
        onAccount: repo!.isDemo ? null : _openAccount,
        onReport: state!['circle'] == null ? null : () => _report(),
        onExport: repo!.isDemo ? null : _exportData,
        // The Circle's own completed meetups. This used to open the legacy
        // meetups app, which gates on onboarding a Circles member has never
        // been through, so it always demanded a city, birthday and gender
        // the programme does not use.
        onBookings: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => CirclePastMeetups(state: state!))),
        onSignOut:
            repo!.isDemo ? null : () => Supabase.instance.client.auth.signOut(),
        onEditPublic: repo!.isDemo || state!['stage'] == 'apply'
            ? null
            : _editPublicProfile,
        onAdmin: state!['is_admin'] == true ? openAdmin : null,
        onHelp: _openSupportChat,
        onTerms: () => _openLegal(LegalDocumentType.terms),
        onPrivacy: () => _openLegal(LegalDocumentType.privacy),
      );

  void _openLegal(LegalDocumentType type) => Navigator.push(context,
      MaterialPageRoute<void>(builder: (_) => LegalDocumentScreen(type: type)));

  Future<void> _openSupportChat() async {
    final launched = await launchUrl(Uri.parse('https://wa.me/31685660139'),
        mode: LaunchMode.externalApplication);
    if (!mounted || launched) return;
    showCircleToast(
        context, "We couldn't open WhatsApp. Try again in a moment.",
        icon: Icons.error_outline_rounded);
  }

  Future<void> _editPublicProfile() async {
    final app = state!['application'] as Map;
    final name = TextEditingController(text: app['name'] as String? ?? '');
    final intro = TextEditingController(text: app['intro'] as String? ?? '');
    final result = await showDialog<Json>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Your first hello'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'First name')),
                const SizedBox(height: 16),
                TextField(
                    controller: intro,
                    maxLength: 160,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'My kind of afternoon…')),
              ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Back')),
                FilledButton(
                    onPressed: () {
                      if (name.text.trim().isNotEmpty) {
                        Navigator.pop(c, {
                          'name': name.text.trim(),
                          'intro': intro.text.trim()
                        });
                      }
                    },
                    child: const Text('Save'))
              ],
            ));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    intro.dispose();
    if (result != null && mounted) await safeAct('edit_circle_profile', result);
  }

  Future<void> _openAccount() async {
    final app = state!['application'] as Map? ?? {};
    final original = widget.session!.user;
    final user = User.fromJson({
      ...original.toJson(),
      'user_metadata': {
        ...original.userMetadata ?? {},
        'first_name': app['name'],
        'date_of_birth': app['date_of_birth'],
        'profile_photo_path': app['photo_path'],
        'has_profile_photo': app['photo_path'] != null,
      }
    })!;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Account & support')),
                  body: SafeArea(
                      child: ProfileScreen(
                          circleMode: true,
                          user: user,
                          onSignOut: () async {
                            await Supabase.instance.client.auth.signOut();
                            if (mounted) Navigator.pop(context);
                          },
                          onDeleteAccount: () async {
                            await AccountDeletionService(
                                    Supabase.instance.client)
                                .deleteCurrentAccount();
                            if (mounted) Navigator.pop(context);
                          },
                          isSigningOut: false,
                          unreadNotificationCount: 0,
                          onOpenNotifications: () => _notifications(context))),
                )));
    if (mounted && repo != null) await load(silent: true);
  }

  Future<Json?> _pickPhoto() async {
    String? uploaded;
    final client = Supabase.instance.client;
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
          withData: true);
      if (result == null) return null;
      final file = result.files.single, bytes = result.files.single.bytes;
      if (bytes == null ||
          !ProfilePhotoService.hasSupportedImageSignature(bytes)) {
        throw StateError('Choose a JPG, PNG or WebP photo.');
      }
      if (ProfilePhotoService.isTooLarge(bytes)) {
        throw StateError(ProfilePhotoService.tooLargeMessage(bytes.length));
      }
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1024);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
      uploaded = await ProfilePhotoService.uploadPhoto(
          supabase: client,
          userId: widget.session!.user.id,
          bytes: bytes,
          fileName: file.name,
          slot: 'profile');
      await client.from('profiles').update({
        'profile_photo_path': uploaded,
        'has_profile_photo': true,
        'profile_photo_name': file.name
      }).eq('id', widget.session!.user.id);
      final record = <String, dynamic>{'photo_path': uploaded};
      uploaded =
          null; // The profile owns this upload now; do not remove it on URL failure.
      try {
        record['photo_url'] = await ProfilePhotoService.createSignedPhotoUrl(
            supabase: client, path: record['photo_path'] as String);
      } catch (_) {}
      if (mounted && state != null) {
        setState(() => state!['application'] = {
              ...state!['application'] as Map,
              ...record
            });
      }
      return record;
    } catch (e) {
      if (uploaded != null) {
        try {
          await client.storage
              .from(ProfilePhotoService.bucketName)
              .remove([uploaded]);
        } catch (_) {}
      }
      final message = e is StateError
          ? e.message
          : ProfilePhotoService.uploadErrorMessage(e);
      if (mounted) {
        showCircleToast(context, message, icon: Icons.error_outline_rounded);
      }
      throw StateError(message);
    }
  }

  Future<void> _exportData() async {
    try {
      final data = await Supabase.instance.client.rpc('circle_export_data');
      final bytes = Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
      await FilePicker.platform.saveFile(
          dialogTitle: 'Save your VriendTime data',
          fileName: 'vriendtime-my-data.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: bytes);
    } catch (_) {
      if (mounted) {
        showCircleToast(
            context, 'Could not export your data. Please try again.',
            icon: Icons.error_outline_rounded);
      }
    }
  }

  Future<void> _report({String? messageId}) async {
    final reason = TextEditingController();
    final text = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Tell the organiser'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'Your report is private. Describe what happened so the organiser can help. For immediate danger, contact emergency services.'),
                const SizedBox(height: 16),
                TextField(
                    controller: reason,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    decoration:
                        const InputDecoration(labelText: 'Your concern')),
              ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Back')),
                FilledButton(
                    onPressed: () {
                      if (reason.text.trim().length >= 5) {
                        Navigator.pop(c, reason.text.trim());
                      }
                    },
                    child: const Text('Send private report'))
              ],
            ));
    // Dialog transitions can still reference its controller until the next frame.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    reason.dispose();
    if (text != null && mounted) {
      try {
        await act('report',
            {'reason': text, if (messageId != null) 'message_id': messageId});
        if (mounted) {
          showCircleToast(
              context, 'Your report has been sent to the organiser.');
        }
      } catch (_) {}
    }
  }

  Future<void> _notifications(BuildContext context) async {
    var notes = rows(state?['notifications']);
    if (repo?.isDemo != true && widget.session != null) {
      try {
        final result = await Supabase.instance.client
            .from('notifications')
            .select('id,title,body,created_at,read_at')
            .eq('recipient_profile_id', widget.session!.user.id)
            .order('created_at', ascending: false)
            .limit(20);
        notes = rows(result);
        final unread = notes
            .where((n) => n['read_at'] == null)
            .map((n) => n['id'] as String)
            .toList();
        if (unread.isNotEmpty) {
          await Supabase.instance.client
              .from('notifications')
              .update({'read_at': DateTime.now().toUtc().toIso8601String()})
              .eq('recipient_profile_id', widget.session!.user.id)
              .inFilter('id', unread);
          await load(silent: true);
        }
      } catch (_) {
        if (context.mounted) {
          showCircleToast(
              context, 'Could not load notifications. Please retry.',
              icon: Icons.error_outline_rounded);
        }
        return;
      }
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (c) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                    height: MediaQuery.sizeOf(c).height * .65,
                    child: ListView(children: [
                      Text('A little update',
                          style: Theme.of(c).textTheme.headlineSmall),
                      const SizedBox(height: 18),
                      if (notes.isEmpty)
                        const Text(
                            'You’re all caught up. Circle updates will appear here.'),
                      for (final n in notes)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(n['title'] as String),
                            subtitle: Text(n['body'] as String))
                    ])))));
  }
}
