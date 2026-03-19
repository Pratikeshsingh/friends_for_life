import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                height: 360,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF211D1A), Color(0xFF78523F), Color(0xFFD6B5A0)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 28,
                      left: 28,
                      child: _badge('Alkmaar launch'),
                    ),
                    Positioned(
                      right: 28,
                      top: 90,
                      child: _floatingPill('4–8 people'),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 24,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BakkieBond', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                            SizedBox(height: 10),
                            Text(
                              'Curated friendship circles for adults who want real connection — not endless swiping.',
                              style: TextStyle(color: Colors.white, height: 1.5, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('Meet your next circle.', style: theme.textTheme.displayMedium),
              const SizedBox(height: 12),
              Text(
                'Join premium small-group meetups around coffee, dinner, drinks, and easy social activities. We reveal the exact spot a day before, then open the chat after you meet.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _InfoChip(icon: Icons.coffee_outlined, label: 'Coffee & dinner'),
                  _InfoChip(icon: Icons.schedule_outlined, label: 'Day or evening'),
                  _InfoChip(icon: Icons.diversity_3_outlined, label: 'Mixed groups'),
                  _InfoChip(icon: Icons.lock_outline, label: 'Chat unlocks later'),
                ],
              ),
              const Spacer(),
              ElevatedButton(onPressed: onStart, child: const Text('Preview the prototype')),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () {}, child: const Text('Continue with Apple / Google / Email')),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }

  static Widget _floatingPill(String label) {
    return Transform.rotate(
      angle: -0.10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8EFE8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
