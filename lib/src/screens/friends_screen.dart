import 'package:flutter/material.dart';

import '../widgets/section_card.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('After the meetup', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text('Chats and connections', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Friday dinner circle', style: theme.textTheme.titleLarge),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F2EC),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text('Chat unlocked', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2F6B57))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Once your meetup is completed, the shared group chat opens automatically. You can also send a 1:1 chat request to people you connected with.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                ...const [
                  _ChatBubble(name: 'Liv', message: 'Loved meeting everyone — same time next month?', mine: false),
                  _ChatBubble(name: 'You', message: 'Yes please. Coffee or a walk next time?', mine: true),
                  _ChatBubble(name: 'Noah', message: 'I can do Sunday afternoon. This was much nicer than an app.', mine: false),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('People you have met', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                ...const [
                  _FriendTile(name: 'Liv', subtitle: 'Matched at Friday dinner • Loves museums', action: 'Chat request'),
                  _FriendTile(name: 'Noah', subtitle: 'Matched at Friday dinner • Into cycling', action: 'Add friend'),
                  _FriendTile(name: 'Sara', subtitle: 'Matched at Friday dinner • Speaks Dutch & English', action: 'Already friends'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.name, required this.message, required this.mine});

  final String name;
  final String message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF1F1A17) : const Color(0xFFF1E7DE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(color: mine ? Colors.white70 : const Color(0xFF6E655F), fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(color: mine ? Colors.white : const Color(0xFF1C1A19), height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.name, required this.subtitle, required this.action});

  final String name;
  final String subtitle;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: const BoxDecoration(color: Color(0xFFD7B8A2), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: () {}, child: Text(action)),
        ],
      ),
    );
  }
}
