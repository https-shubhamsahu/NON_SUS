import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sealed_providers.dart';

/// Minimal Sealed home surface (M0 scaffold).
///
/// Shows the current user's matches (the reveal moment) and their own seals.
/// The seal-toward-someone flow, arena roster, and invite loop land in M1–M3.
class SealedHomeScreen extends ConsumerWidget {
  const SealedHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider);
    final mySeals = ref.watch(mySealsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sealed')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Matches', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          matches.when(
            data: (list) => list.isEmpty
                ? const Text('No matches yet. Seal an intent to begin.')
                : Column(
                    children: [
                      for (final m in list)
                        ListTile(
                          leading: const Icon(Icons.favorite),
                          title: Text('Mutual: ${m.intentKind.label}'),
                          subtitle: Text('Matched ${m.matchedAt.toLocal()}'),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load matches: $e'),
          ),
          const SizedBox(height: 24),
          Text('Your seals', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          mySeals.when(
            data: (list) => list.isEmpty
                ? const Text('You have not sealed anyone yet.')
                : Column(
                    children: [
                      for (final s in list)
                        ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: Text(s.intentKind.label),
                          subtitle: Text('Status: ${s.status}'),
                        ),
                    ],
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load your seals: $e'),
          ),
        ],
      ),
    );
  }
}
