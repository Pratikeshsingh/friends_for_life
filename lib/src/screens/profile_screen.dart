import 'package:flutter/material.dart';

import '../widgets/section_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prototype profile', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text('Your membership setup', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      height: 84,
                      width: 84,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFF3B2F29), Color(0xFFC79577)]),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.person, color: Colors.white, size: 38),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Anya • 29', style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text('Alkmaar', style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              Chip(label: Text('Woman')),
                              Chip(label: Text('English')),
                              Chip(label: Text('Dutch')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Moved here two years ago and looking for a genuine circle to do dinners, coffee catchups, and low-pressure weekend plans with.',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Interests', style: theme.textTheme.titleLarge),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Chip(label: Text('Coffee spots')),
                    Chip(label: Text('Dinner nights')),
                    Chip(label: Text('Walks')),
                    Chip(label: Text('Museums')),
                    Chip(label: Text('Board games')),
                    Chip(label: Text('Live music')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Availability & preferences', style: theme.textTheme.titleLarge),
                const SizedBox(height: 14),
                const _PreferenceRow(label: 'Activities', value: 'Coffee, dinner, drinks'),
                const _PreferenceRow(label: 'Time', value: 'Evening (17:00–21:00)'),
                const _PreferenceRow(label: 'Days', value: 'Weekend preferred'),
                const _PreferenceRow(label: 'Group policy', value: 'Mixed groups only'),
                const _PreferenceRow(label: 'Photos', value: '3 uploaded'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Safety controls', style: theme.textTheme.titleLarge),
                const SizedBox(height: 14),
                const _PreferenceRow(label: 'Blocked members', value: '2 hidden from future assignments'),
                const _PreferenceRow(label: 'Reports filed', value: '0'),
                const _PreferenceRow(label: 'No-show score', value: 'Excellent standing'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Manage blocked list'))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(onPressed: () {}, child: const Text('Edit profile'))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(value, textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
