import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/section_card.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final success = Theme.of(context).extension<AppColors>()?.success ?? const Color(0xFF2F6B57);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upcoming meetup', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text('Friday social dinner', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  height: 190,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFD9BCA8), Color(0xFF8D6247)],
                    ),
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text('Exact venue revealed 24h before', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      const Text('6 confirmed • 2 on waitlist', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      const Text('Dinner in central Alkmaar', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      _detailRow(Icons.schedule_outlined, 'Friday, 28 March', '19:00–21:00'),
                      const SizedBox(height: 14),
                      _detailRow(Icons.location_on_outlined, 'Approximate area', 'Waagplein / old town'),
                      const SizedBox(height: 14),
                      _detailRow(Icons.payments_outlined, 'Payment', 'Pay at venue'),
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
                Text('Assignment logic', style: theme.textTheme.titleLarge),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Chip(selected: true, label: Text('Dinner')),
                    Chip(selected: true, label: Text('Evening')),
                    Chip(label: Text('Weekdays')),
                    Chip(selected: true, label: Text('Mixed group')),
                    Chip(selected: true, label: Text('Age 25–35')),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Assignments are automatic for members, but shaped by your stated preferences and admin oversight. We do not reveal the other attendees before the event.',
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
                Text('Event rules', style: theme.textTheme.titleLarge),
                const SizedBox(height: 14),
                _rule(success, 'You can request cancellation only if at least 4 attendees remain.'),
                _rule(success, 'The exact venue is shared one day before the meetup.'),
                _rule(success, 'Group chat unlocks only after the meetup has been completed.'),
                _rule(success, 'No-shows and reports are tracked to keep the community safe.'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: () {}, child: const Text('Keep my spot'))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Report issue'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Color(0xFF6E655F))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rule(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
