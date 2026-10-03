import 'dart:async';
import 'dart:convert';
import '../core/app_diagnostics.dart';
import 'circle_meetup_detail.dart';
import 'circle_save_dialog.dart';
import 'dart:typed_data';
import '../core/photo_preparation.dart';
import '../core/profile_photo_service.dart';
import 'circle_profile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../core/i18n.dart';
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
  int _loadGeneration = 0;
  bool _loading = false;
  bool _stale = false;
  var _applicationKey = GlobalKey();
  String? _sendId, _sendBody;
  final List<Json> _olderMessages = [];
  bool _loadingOlder = false, _hasOlder = true;

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
      if (repo != null && !busy && !_loading) load(silent: true);
    });
  }

  @override
  void didUpdateWidget(covariant CircleShell old) {
    super.didUpdateWidget(old);
    if (old.session?.user.id != widget.session?.user.id &&
        repo?.isDemo != true) {
      _loadGeneration++;
      _olderMessages.clear();
      _sendId = _sendBody = null;
      message.clear();
      editing = false;
      applicationParked = false;
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
    final generation = ++_loadGeneration;
    _loading = true;
    try {
      final value = await source.load().timeout(const Duration(seconds: 20));
      if (mounted && identical(repo, source) && generation == _loadGeneration) {
        setState(() {
          state = value;
          error = null;
          _stale = false;
        });
      }
    } catch (e) {
      AppDiagnostics.record(e, area: 'circle_load');
      if (mounted && identical(repo, source) && generation == _loadGeneration) {
        setState(() {
          _stale = true;
          if (!silent || state == null) {
            error =
                'We couldn’t load your Circle right now. Please try again in a moment.';
          }
        });
      }
    } finally {
      if (generation == _loadGeneration) _loading = false;
    }
  }

  Future<void> act(String action, [Json data = const {}]) async {
    if (busy) throw StateError('Another change is still saving. Please wait.');
    _loadGeneration++;
    setState(() => busy = true);
    try {
      await repo!.act(action, data).timeout(const Duration(seconds: 25),
          onTimeout: () => throw StateError(
              'Confirmation is taking longer than expected. Refresh before trying again.'));
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
          'check_in',
          'outcome',
          'schedule',
          'request_move',
          'refresh_commitment',
          'exclude',
          'email_notifications',
          'leave_circle'
        ].contains(action)) {
          showCircleToast(
              context,
              switch (action) {
                'refresh_commitment' => 'Availability confirmed.',
                'exclude' => 'Noted. This stays between you and us.',
                'request_move' =>
                  'You’re moving to a new group. Your €19 carries over.',
                'email_notifications' => data['enabled'] == true
                    ? 'We’ll email you about your Circle.'
                    : 'Emails turned off. Your Circle updates stay in the app.',
                'leave_circle' =>
                  'You’ve left the Circle. We’ll be in touch about anything outstanding.',
                _ => _stale
                    ? 'Saved. Refresh to see the latest version.'
                    : 'Saved.'
              });
        }
      }
    } catch (e) {
      AppDiagnostics.record(e, area: 'circle_action');
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
                  if (_stale && state != null)
                    MaterialBanner(
                        content: const Text(
                            'Updates paused. Showing your last loaded Circle.'),
                        actions: [
                          TextButton(
                              onPressed: () => load(),
                              child: const Text('Retry'))
                        ]),
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
                              tooltip: t('Explore preview stages'),
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
                  Container(
                      // Solid, so the scene's lamp never sits behind the
                      // icons and content never looks cut off under it.
                      decoration: const BoxDecoration(
                          color: Color(0xF2FFFAF4),
                          border: Border(
                              bottom: BorderSide(color: Color(0x14062B55)))),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      child: Row(children: [
                        const Expanded(
                            child: BrandLockup(
                                logoSize: 38, foregroundColor: circleNavy)),
                        if (state?['is_admin'] == true)
                          IconButton(
                              onPressed: openAdmin,
                              tooltip: t('Circle organiser'),
                              icon: const Icon(Icons.tune_rounded)),
                        IconButton(
                            onPressed: () => _notifications(context),
                            tooltip: t('Notifications'),
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
                              tooltip: t('Exit preview'),
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
                                  padding: EdgeInsets.fromLTRB(
                                      22, 16, 22, chatOpen ? 220 : 130),
                                  child: Center(
                                      child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxWidth: 900),
                                          child: Column(children: [
                                            if (editing ||
                                                (state!['stage'] == 'apply' &&
                                                    !applicationParked))
                                              Offstage(
                                                  offstage: tab != 0,
                                                  child: TickerMode(
                                                      enabled: tab == 0,
                                                      child: _application(
                                                          context))),
                                            if (tab != 0 ||
                                                !(editing ||
                                                    (state!['stage'] ==
                                                            'apply' &&
                                                        !applicationParked)))
                                              _body(context),
                                          ])))))),
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
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (chatOpen) _composer(context),
                                  FloatingGlassNavigation(
                                      height: 70,
                                      circleMode: true,
                                      showMessages: hasChat,
                                      homeLabel: hasChat ? null : 'Home',
                                      selectedIndex: tab,
                                      onDestinationSelected: (v) {
                                        setState(() => tab = v);
                                        if (v == 1) {
                                          _scrollToLatest();
                                        } else if (scroll.hasClients) {
                                          scroll.jumpTo(0);
                                        }
                                      }),
                                ]))))));
  }

  /// The group chat exists once someone has joined a Circle.
  bool get hasChat => ['active', 'completed'].contains(state?['stage']);
  bool get chatOpen => tab == 1 && hasChat;

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = message.text.trim();
    if (text.isEmpty || busy) return;
    try {
      if (_sendBody != text) {
        _sendId = circleRequestId();
        _sendBody = text;
      }
      await act('message', {'body': text, 'request_id': _sendId});
      _sendId = _sendBody = null;
      message.clear();
      _scrollToLatest();
    } catch (_) {}
  }

  /// Pinned above the bottom menu, so it never scrolls away from the
  /// conversation.
  Widget _composer(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
          color: Colors.white,
          elevation: 3,
          shadowColor: const Color(0x33062B55),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: message,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                            hintText: t('Message your Circle…'),
                            counterText: '',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none))),
                IconButton.filled(
                    style: IconButton.styleFrom(
                        backgroundColor: circleNavy,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0x33062B55),
                        disabledForegroundColor: Colors.white),
                    tooltip: t('Send'),
                    onPressed: busy ? null : _send,
                    icon: const Icon(Icons.send_rounded)),
              ]))));

  void _openApplication(int step) => setState(() {
        _applicationKey = GlobalKey();
        editing = true;
        editStep = step;
        applicationParked = false;
        tab = 0;
      });

  Widget _body(BuildContext context) {
    if (tab == 1 && hasChat) return _messages(context);
    if (tab == 2) return _profile(context);
    return CircleHome(
        state: state!,
        demo: repo!.isDemo,
        busy: busy,
        act: safeAct,
        savePlan: act,
        onEdit: _openApplication,
        onMessages: () {
          setState(() => tab = 1);
          _scrollToLatest();
        });
  }

  Widget _application(BuildContext context) {
    // A focused edit is one answer being changed from the profile or home
    // — never "Continue my application" or "Finish my profile", which both
    // open at step 0 and must keep the whole four-step walk.
    final focused = editing && editStep > 0;
    return CircleApplication(
        key: _applicationKey,
        initial: Map<String, dynamic>.from(state!['application'] as Map? ??
            {'name': widget.session?.user.userMetadata?['first_name'] ?? ''}),
        busy: busy,
        initialStep: editing ? editStep : 0,
        focusedEdit: focused,
        onDone: () {
          showCircleToast(context, 'Saved.');
          setState(() {
            editing = false;
            editStep = 0;
            // Closing a focused edit is not enough on its own: an
            // application still in the 'apply' stage matches the second
            // clause of the condition above, so the full four-step form
            // would re-open at step 0 the instant this one closed —
            // which reads as "saving my availability restarted my
            // onboarding". Park it so they land on the home card.
            if (state?['stage'] == 'apply') applicationParked = true;
          });
        },
        onCancel: () => setState(() {
              editing = false;
              editStep = 0;
              if (state?['stage'] == 'apply') applicationParked = true;
            }),
        onPhoto: repo!.isDemo ? null : _pickPhoto,
        onSave: (d) => act('draft', d),
        onSubmit: (d) => act('apply', d),
        // Leaving the form needs somewhere to land; for an unsubmitted
        // application that is the home tab's "continue" card.
        onSaveForLater: () {
          setState(() {
            editing = false;
            editStep = 0;
            applicationParked = true;
          });
          showCircleToast(context, 'Saved. Pick up where you left off.');
        });
  }

  String _messageTime(String? raw) {
    final at = DateTime.tryParse(raw ?? '')?.toLocal();
    if (at == null) return '';
    final hm =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return sameDay ? hm : '${circleDate(at.toIso8601String())} · $hm';
  }

  Widget _messages(BuildContext context) {
    final all = [..._olderMessages, ...rows(state!['messages'])];
    final byId = <String, Json>{
      for (var i = 0; i < all.length; i++)
        '${all[i]['id'] ?? 'local-$i'}': all[i]
    };
    final messages = byId.values.toList()
      ..sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CircleHeading('A little hello goes a long way.',
          eyebrow: 'Circle messages',
          subtitle:
              'Plans, small updates and “see you Thursday”. Only your Circle can read this. Be kind, and ask before sharing someone’s details.'),
      if (messages.isEmpty)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No messages yet. Be the first to say hello.')),
      if (_hasOlder && messages.length >= 100)
        TextButton(
            onPressed: _loadingOlder ? null : _loadOlderMessages,
            child: Text(_loadingOlder ? 'Loading…' : 'Load earlier messages')),
      for (final m in messages) _bubble(context, m),
    ]);
  }

  Future<void> _loadOlderMessages() async {
    if (repo is! SupabaseCircleRepository || _loadingOlder) return;
    final messages = [..._olderMessages, ...rows(state!['messages'])]
      ..sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));
    if (messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await (repo as SupabaseCircleRepository)
          .olderMessages(messages.first);
      if (mounted) {
        setState(() {
          _olderMessages.insertAll(0, page);
          _hasOlder = page.length == 100;
        });
      }
    } catch (_) {
      if (mounted) {
        showCircleToast(
            context, 'Could not load earlier messages. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Widget _bubble(BuildContext context, Json m) {
    final own = m['own'] == true;
    final time = _messageTime(m['created_at']?.toString());
    return Align(
        alignment: own ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(
                color: own ? const Color(0xFFDFF1EA) : Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(own ? 18 : 4),
                    bottomRight: Radius.circular(own ? 4 : 18)),
                border: Border.all(color: const Color(0xFFDDE7E3))),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                      child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!own)
                                  Text(m['name'] as String? ?? 'Circle member',
                                      style: const TextStyle(
                                          color: circleTeal,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800)),
                                SelectableText(m['body'] as String? ?? ''),
                                if (time.isNotEmpty)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(time,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF66727C)))),
                              ]))),
                  if (!own && m['id'] != null)
                    PopupMenuButton<String>(
                        tooltip: t('Message options'),
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(Icons.more_horiz_rounded,
                            color: Color(0xFF66727C)),
                        onSelected: (_) =>
                            _report(messageId: m['id'] as String),
                        itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'report',
                                  child: Text('Report this message'))
                            ]),
                ])));
  }

  Widget _profile(BuildContext context) => CircleProfile(
        state: state!,
        act: safeAct,
        busy: busy,
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
        onWithdraw: state!['stage'] == 'waiting'
            ? () async {
                if (await confirmWithdraw(context)) await safeAct('withdraw');
              }
            : null,
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
                    decoration: InputDecoration(labelText: t('First name'))),
                const SizedBox(height: 16),
                TextField(
                    controller: intro,
                    maxLength: 160,
                    minLines: 2,
                    maxLines: 3,
                    decoration: InputDecoration(
                        labelText: t('A line about you (optional)'),
                        hintText:
                            t('e.g. A long walk, a good coffee, no rush.'))),
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
          type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.single;
      if (file.bytes == null) {
        throw const PhotoPreparationException(
            'We could not read this photo. Please choose it again.');
      }
      final prepared = await prepareProfilePhoto(file.bytes!);
      final oldPhoto =
          (state?['application'] as Map?)?['photo_path'] as String?;
      uploaded = await ProfilePhotoService.uploadPhoto(
          supabase: client,
          userId: widget.session!.user.id,
          bytes: prepared,
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
      if (oldPhoto != null && oldPhoto != record['photo_path']) {
        try {
          await client.storage
              .from(ProfilePhotoService.bucketName)
              .remove([oldPhoto]);
        } catch (_) {}
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
    final requestId = circleRequestId();
    await showCircleSaveDialog(context,
        title: 'Tell the organiser',
        description:
            'Your report is private. Tell us what happened. For immediate danger, contact emergency services. For urgent help, use Help & contact in Profile.',
        fields: const {'reason': 'Your concern'},
        multiline: true,
        saveLabel: 'Send private report', onSave: (data) async {
      if ('${data['reason']}'.trim().length < 5) {
        throw StateError(
            'Please describe your concern in at least five characters.');
      }
      await act('report', {
        ...data,
        'request_id': requestId,
        if (messageId != null) 'message_id': messageId
      });
    });
  }

  /// "Just now", "3 h ago", "Yesterday", or a date.
  String _ago(String? raw) {
    final at = DateTime.tryParse(raw ?? '')?.toLocal();
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return circleDate(at.toIso8601String());
  }

  Future<void> _markRead(List<String> ids) async {
    if (ids.isEmpty || repo?.isDemo == true || widget.session == null) return;
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('recipient_profile_id', widget.session!.user.id)
          .inFilter('id', ids);
      await load(silent: true);
    } catch (_) {}
  }

  /// Where a notification leads. Organiser alerts ('support') open the
  /// organiser panel; everything else is about the person's own Circle.
  void _openNotification(Json n) {
    if (n['kind'] == 'support' && state?['is_admin'] == true) {
      openAdmin();
      return;
    }
    final meetup = rows(state?['meetups'])
        .where((m) => m['id'] == n['event_id'])
        .firstOrNull;
    if (meetup != null) {
      openCircleMeetup(context, meetup);
      return;
    }
    setState(() => tab = 0);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  /// New (unread) on top, Earlier (read) below. Opening the list no longer
  /// marks everything read: a notification is read once it is opened, or
  /// with "Mark all as read".
  Future<void> _notifications(BuildContext context) async {
    var notes = rows(state?['notifications']);
    if (repo?.isDemo != true && widget.session != null) {
      try {
        final result = await Supabase.instance.client
            .from('notifications')
            .select('id,kind,title,body,created_at,read_at,event_id')
            .eq('recipient_profile_id', widget.session!.user.id)
            .order('created_at', ascending: false)
            .limit(60);
        notes = rows(result);
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
        builder: (sheet) => StatefulBuilder(builder: (sheet, update) {
              final unread = [
                for (final n in notes)
                  if (n['read_at'] == null) n
              ];
              final read = [
                for (final n in notes)
                  if (n['read_at'] != null) n
              ];
              void markLocal(Iterable<Json> items) {
                final now = DateTime.now().toUtc().toIso8601String();
                for (final n in items) {
                  n['read_at'] = now;
                }
              }

              Widget tile(Json n) {
                final isNew = n['read_at'] == null;
                final leadsToAdmin =
                    n['kind'] == 'support' && state?['is_admin'] == true;
                return Material(
                    color: isNew ? const Color(0xFFEAF7F5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (isNew) {
                            update(() => markLocal([n]));
                            _markRead(['${n['id']}']);
                          }
                          Navigator.pop(sheet);
                          _openNotification(n);
                        },
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isNew
                                                  ? circleCoral
                                                  : Colors.transparent))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text('${n['title'] ?? ''}',
                                            style: TextStyle(
                                                fontWeight: isNew
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                                color: circleNavy)),
                                        const SizedBox(height: 2),
                                        Text('${n['body'] ?? ''}',
                                            style: const TextStyle(
                                                color: Color(0xFF4F5D66),
                                                height: 1.35)),
                                        const SizedBox(height: 4),
                                        Text(_ago(n['created_at']?.toString()),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF66727C))),
                                      ])),
                                  Icon(
                                      leadsToAdmin
                                          ? Icons.admin_panel_settings_outlined
                                          : Icons.chevron_right_rounded,
                                      color: const Color(0xFF66727C)),
                                ]))));
              }

              Widget label(String text) => Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(t(text).toUpperCase(),
                      style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4F5D66))));

              return SafeArea(
                  child: SizedBox(
                      height: MediaQuery.sizeOf(sheet).height * .75,
                      child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text('Notifications',
                                      style: Theme.of(sheet)
                                          .textTheme
                                          .headlineSmall)),
                              if (unread.isNotEmpty)
                                TextButton(
                                    onPressed: () {
                                      final ids = [
                                        for (final n in unread) '${n['id']}'
                                      ];
                                      update(() => markLocal(unread));
                                      _markRead(ids);
                                    },
                                    child: const Text('Mark all as read')),
                            ]),
                            if (notes.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                      'You’re all caught up. Circle updates will appear here.')),
                            if (notes.isNotEmpty) ...[
                              label('New'),
                              if (unread.isEmpty)
                                const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 4),
                                    child: Text(
                                        'Nothing new. You’re all caught up.',
                                        style: TextStyle(
                                            color: Color(0xFF66727C))))
                              else
                                for (final n in unread)
                                  Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: tile(n)),
                              if (read.isNotEmpty) ...[
                                label('Earlier'),
                                for (final n in read)
                                  Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: tile(n)),
                              ],
                            ],
                          ])));
            }));
  }
}
