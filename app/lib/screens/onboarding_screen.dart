import 'package:flutter/material.dart';

/// First-run walkthrough (spec phase 6), also reachable any time from the
/// level list's help button.
///
/// Static copy on purpose: it explains the two extension mechanics the
/// ruleset actually has (one-ways, switch/gate channels) and the one thing
/// about share codes a player must understand — every code proves its own
/// solution, so an unsolvable level cannot be handed to you.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.onDone});

  /// Fired when the player dismisses the walkthrough. The caller decides
  /// what "done" means (record the flag, or nothing when re-reading it).
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const ValueKey('onboarding'),
      appBar: AppBar(title: const Text('How to play')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Sokode', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Push every crate onto a target. That is the whole win '
            'condition — nothing else is scored.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          const _Rule(
            icon: Icons.swipe,
            title: 'Moving',
            body:
                'Swipe, or use the arrow keys. You push one crate at a time, '
                'never two, and never into a wall or a closed gate. Undo and '
                'reset are always available.',
          ),
          const _Rule(
            icon: Icons.arrow_forward,
            title: 'One-way tiles',
            body:
                'An arrow tile can only be entered from the direction it '
                'points. That applies to crates you push as well as to you. '
                'Leaving is unrestricted.',
          ),
          const _Rule(
            icon: Icons.toggle_on,
            title: 'Switches and gates',
            body:
                'Stepping onto a switch flips every gate on its channel: '
                'closed gates open, open gates close. A gate with something '
                'standing on it stays open — nothing gets crushed.',
          ),
          const _Rule(
            icon: Icons.qr_code,
            title: 'Share codes',
            body:
                'Levels travel as codes. Every code carries the solution its '
                'author actually played, and your device replays that proof '
                'before the level opens — so an impossible level cannot be '
                'shared to you.',
          ),
          const _Rule(
            icon: Icons.build,
            title: 'Making levels',
            body:
                'Paint a board, place a player and crates, then solve it '
                'yourself. Publishing unlocks only once your own solve is '
                'verified; editing afterwards clears it.',
          ),
        ],
      ),
      // Pinned rather than appended to the list: the walkthrough is five
      // sections long, and a dismissal you have to scroll to find is a
      // dismissal players will fight with on a phone.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('onboarding-done'),
              onPressed: () {
                onDone?.call();
                Navigator.of(context).maybePop();
              },
              child: const Text('Start playing'),
            ),
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
