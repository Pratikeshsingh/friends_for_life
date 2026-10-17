import 'package:flutter/material.dart' hide Text;

import '../core/destructive.dart';
import '../core/i18n.dart';
import '../widgets/circle_loading.dart';
import 'circle_repository.dart';
import 'circle_widgets.dart';

/// The text a removed message is replaced with (see admin_hide_message).
const _removed = '[Message removed by the organiser]';

/// A Circle's chat, as the members see it, for the organiser to read.
/// Read-only: organisers moderate, they don't take part. Older messages
/// load on request; any member's message can be removed, after a check.
Future<void> openOrganiserChat(BuildContext context,
        {required CircleRepository repository,
        required Json circle,
        required Future<void> Function(String action, Json payload) act}) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            _OrganiserChat(repository: repository, circle: circle, act: act)));

class _OrganiserChat extends StatefulWidget {
  const _OrganiserChat(
      {required this.repository, required this.circle, required this.act});
  final CircleRepository repository;
  final Json circle;
  final Future<void> Function(String action, Json payload) act;

  @override
  State<_OrganiserChat> createState() => _OrganiserChatState();
}

class _OrganiserChatState extends State<_OrganiserChat> {
  final scroll = ScrollController();
  List<Json>? messages;
  bool more = false, loadingOlder = false, failed = false;

  String get circleId => '${widget.circle['id']}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => failed = false);
    try {
      final list = await widget.repository.adminMessages(circleId);
      if (!mounted) return;
      setState(() {
        messages = list;
        more = list.length >= 200;
      });
      if (scroll.hasClients) scroll.jumpTo(0);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> _older() async {
    final list = messages;
    if (list == null || list.isEmpty || loadingOlder) return;
    setState(() => loadingOlder = true);
    try {
      final page =
          await widget.repository.adminMessagesBefore(circleId, list.first);
      if (!mounted) return;
      // The list grows upwards, so the reader keeps their place.
      setState(() {
        messages = [...page, ...list];
        more = page.length >= 200;
      });
    } catch (_) {
      if (mounted) {
        showCircleToast(
            context, 'Could not load earlier messages. Please retry.');
      }
    } finally {
      if (mounted) setState(() => loadingOlder = false);
    }
  }

  Future<void> _remove(Json m) async {
    final sure = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                scrollable: true,
                title: const Text('Remove this message?'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF3EEE6),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text('${m['body'] ?? ''}',
                              maxLines: 6, overflow: TextOverflow.ellipsis)),
                      const SizedBox(height: 12),
                      const Text(
                          'Everyone in the Circle will see “Message removed by the organiser” in its place. This can’t be undone.'),
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Back')),
                  FilledButton(
                      style: destructiveFilledStyle,
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Remove')),
                ]));
    if (sure != true || !mounted) return;
    try {
      await widget.act('admin_hide_message', {'id': m['id']});
      if (!mounted) return;
      setState(() => messages = [
            for (final x in messages!)
              x['id'] == m['id'] ? {...x, 'body': _removed} : x
          ]);
      showCircleToast(context, 'Message removed.');
    } catch (_) {
      if (mounted) {
        showCircleToast(
            context, 'The message could not be removed. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = messages;
    return Scaffold(
        backgroundColor: const Color(0xFFFBF7F0),
        appBar: AppBar(
            title:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${widget.circle['name'] ?? t('Circle')}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const Text('Read only · you can remove messages',
                  style: TextStyle(fontSize: 12, color: Color(0xFF66727C))),
            ]),
            actions: [
              IconButton(
                  onPressed: _load,
                  tooltip: t('Refresh'),
                  icon: const Icon(Icons.refresh))
            ]),
        body: failed
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('The chat could not be loaded. Please try again.'),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: _load, child: const Text('Try again')),
              ]))
            : list == null
                ? const Center(
                    child: CircleLoading(
                        compact: true,
                        label: 'Opening the chat…',
                        phrases: ['Opening the chat…']))
                : list.isEmpty
                    ? const Center(child: Text('No messages yet.'))
                    : Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 760),
                            // Anchored at the bottom: opens at the newest
                            // message, like the members' chat, and older ones
                            // load above without moving what's on screen.
                            child: ListView(
                                controller: scroll,
                                reverse: true,
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 32),
                                children: [
                                  ..._withDays(list).reversed,
                                  if (more)
                                    Center(
                                        child: TextButton(
                                            onPressed:
                                                loadingOlder ? null : _older,
                                            child: Text(loadingOlder
                                                ? 'Loading…'
                                                : 'Load earlier messages'))),
                                ]))));
  }

  List<Widget> _withDays(List<Json> list) {
    final out = <Widget>[];
    String? last;
    for (final m in list) {
      final at = DateTime.tryParse('${m['created_at'] ?? ''}')?.toLocal();
      if (at != null) {
        final label =
            circleDate(DateTime(at.year, at.month, at.day).toIso8601String());
        if (label != last) {
          out.add(Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDDE7E3))),
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F5D66)))))));
          last = label;
        }
      }
      out.add(_bubble(m, at));
    }
    return out;
  }

  Widget _bubble(Json m, DateTime? at) {
    final time = at == null
        ? ''
        : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    if (m['system'] == true) {
      return Center(
          child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
              decoration: BoxDecoration(
                  color: const Color(0xFFF3EEE6),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('VriendTime · $time',
                    style: const TextStyle(
                        color: circleTealText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${m['body'] ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: Color(0xFF3F4C55))),
              ])));
    }
    final removed = m['body'] == _removed;
    return Align(
        alignment: Alignment.centerLeft,
        child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(18)),
                border: Border.all(color: const Color(0xFFDDE7E3))),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('${m['name'] ?? 'Member'} · $time',
                            style: const TextStyle(
                                color: circleTealText,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        SelectableText(
                            removed
                                ? t('Message removed by the organiser')
                                : '${m['body'] ?? ''}',
                            style: removed
                                ? const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF66727C))
                                : null),
                      ])),
                  if (!removed && m['id'] != null)
                    PopupMenuButton<String>(
                        tooltip: t('Message options'),
                        icon: const Icon(Icons.more_vert_rounded,
                            size: 18, color: Color(0xFF66727C)),
                        onSelected: (_) => _remove(m),
                        itemBuilder: (_) => [
                              PopupMenuItem(
                                  value: 'remove',
                                  child: Row(children: [
                                    const Icon(Icons.delete_outline_rounded,
                                        color: destructiveRed, size: 20),
                                    const SizedBox(width: 10),
                                    Text(t('Remove message'),
                                        style: const TextStyle(
                                            color: destructiveRed)),
                                  ])),
                            ])
                  else
                    const SizedBox(width: 10),
                ])));
  }
}
