import 'package:flutter/material.dart';

import '../widgets/section_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenEvent});

  final VoidCallback onOpenEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good evening, Anya', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text('Your next meetup is taking shape.', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 18),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F1A17),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statusPill('Assigned automatically • 6 seats currently filled'),
                      const SizedBox(height: 16),
                      const Text('Friday social dinner', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text('Friday, 28 March • 19:00–21:00\nNear the old town, Alkmaar', style: TextStyle(color: Color(0xFFE5D9D0), height: 1.5)),
                      const SizedBox(height: 16),
                      Row(
                        children: const [
                          _Metric(label: 'Age bracket', value: '25–35'),
                          SizedBox(width: 12),
                          _Metric(label: 'Vibe', value: 'Dinner'),
                          SizedBox(width: 12),
                          _Metric(label: 'Policy', value: '4+ to go'),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onOpenEvent,
                          child: const Text('View meetup'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          child: const Text('Request cancel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your preferences', style: theme.textTheme.titleLarge),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Chip(label: Text('Coffee')),
                    Chip(label: Text('Dinner')),
                    Chip(label: Text('Walks')),
                    Chip(label: Text('Evening 17:00–21:00')),
                    Chip(label: Text('Weekends')),
                    Chip(label: Text('English + Dutch')),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'We use these preferences to place you in curated mixed groups, but matching still depends on enough people being available.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How BakkieBond works', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                const _TimelineTile(
                  index: '01',
                  title: 'Build your profile',
                  subtitle: 'Photos, age, language preferences, interests, and the kinds of outings you enjoy.',
                ),
                const _TimelineTile(
                  index: '02',
                  title: 'Get assigned to a circle',
                  subtitle: 'Our prototype groups people automatically using availability, activity preferences, and age brackets.',
                ),
                const _TimelineTile(
                  index: '03',
                  title: 'Meet first, then chat',
                  subtitle: 'You only see the event type, time, and area ahead of time. Group chat unlocks after the meetup.',
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statusPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFD5C4B8), fontSize: 12)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.index,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final String index;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: const BoxDecoration(color: Color(0xFF1F1A17), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(index, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            if (!isLast)
              Container(width: 2, height: 50, color: const Color(0xFFE7D9CC)),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
