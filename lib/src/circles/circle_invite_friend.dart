import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/i18n.dart';
import '../core/system_share.dart';
import 'circle_widgets.dart';

/// Word of mouth: a ready-made message with the link to VriendTime.
String circleInviteMessage() => t(
    'I’m doing VriendTime: small groups of five or six who meet every week in Alkmaar to make new friends. Have a look: https://vriendtime.com');

Future<void> showInviteFriend(BuildContext context) => showModalBottomSheet<
        void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite a friend',
                          style: Theme.of(sheet).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text(
                          'Know someone who’d enjoy this? They apply themselves and join their own Circle with new people.'),
                      const SizedBox(height: 16),
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF7F5EF),
                              borderRadius: BorderRadius.circular(14)),
                          child: Text(circleInviteMessage(),
                              style: const TextStyle(fontSize: 14))),
                      const SizedBox(height: 16),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        if (canSystemShare)
                          FilledButton.icon(
                              icon:
                                  const Icon(Icons.ios_share_rounded, size: 18),
                              label: const Text('Share…'),
                              onPressed: () async {
                                if (await systemShare(circleInviteMessage()) &&
                                    sheet.mounted) {
                                  Navigator.pop(sheet);
                                }
                              })
                        else
                          FilledButton.icon(
                              icon: const Icon(Icons.chat_outlined, size: 18),
                              label: const Text('Share on WhatsApp'),
                              onPressed: () => launchUrl(
                                  Uri.https('wa.me', '/',
                                      {'text': circleInviteMessage()}),
                                  mode: LaunchMode.externalApplication)),
                        OutlinedButton.icon(
                            icon: const Icon(Icons.link_rounded, size: 18),
                            label: const Text('Copy message'),
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: circleInviteMessage()));
                              if (sheet.mounted) {
                                Navigator.pop(sheet);
                                showCircleToast(
                                    context, t('Copied. Paste it anywhere.'),
                                    icon: Icons.check_circle_outline_rounded);
                              }
                            }),
                      ]),
                    ])))));
