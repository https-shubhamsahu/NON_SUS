import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/intent_kind.dart';
import '../providers/sealed_providers.dart';

/// Sealed — the reciprocity-gated intent graph (M1–M4 surface).
///
/// Flow: claim a handle → create/join an arena → pick a member + intent →
/// SEAL. Nothing is revealed unless it's mutual; matches arrive live via the
/// realtime stream. Seals never expire (the Someday List): an old seal can
/// match years later the moment the other person seals you back.
class SealedHomeScreen extends ConsumerStatefulWidget {
  const SealedHomeScreen({super.key});

  @override
  ConsumerState<SealedHomeScreen> createState() => _SealedHomeScreenState();
}

class _SealedHomeScreenState extends ConsumerState<SealedHomeScreen> {
  bool _busy = false;

  Future<void> _guard(Future<void> Function() op) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await op();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Handle onboarding ──────────────────────────────────────────────────────

  Future<void> _claimHandle() async {
    final controller = TextEditingController();
    final handle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Claim your handle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(prefixText: '@', hintText: 'yourname'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Claim'),
          ),
        ],
      ),
    );
    if (handle == null || handle.isEmpty) return;
    await _guard(() async {
      await ref.read(sealedRepositoryProvider).saveProfile(handle: handle);
      ref.invalidate(myHandleProvider);
    });
  }

  // ── Arena create / invite / claim ──────────────────────────────────────────

  Future<void> _createArena() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New arena'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. CS Batch of 2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _guard(() async {
      await ref.read(sealedRepositoryProvider).createArena(name);
      ref.invalidate(myArenasProvider);
    });
  }

  Future<void> _shareInvite(String arenaId, String arenaName) async {
    await _guard(() async {
      final code =
          await ref.read(sealedRepositoryProvider).createInvite(arenaId: arenaId);
      // The growth loop: the invite IS the product's distribution.
      await SharePlus.instance.share(
        ShareParams(
          text: 'Someone in "$arenaName" may have sealed you on Sealed. '
              'Join with code $code to find out — it only reveals if it\'s mutual.',
        ),
      );
    });
  }

  Future<void> _claimInvite() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter invite code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    await _guard(() async {
      await ref.read(sealedRepositoryProvider).claimInvite(code);
      ref.invalidate(myArenasProvider);
    });
  }

  // ── The seal flow ──────────────────────────────────────────────────────────

  Future<void> _sealSomeone(String arenaId, int myPublicId) async {
    final members = await ref.read(arenaMembersProvider(arenaId).future);
    final candidates =
        members.where((m) => m.arenaPublicId != myPublicId).toList();
    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No one else here yet — share an invite first.'),
        ));
      }
      return;
    }
    if (!mounted) return;

    int? targetId;
    IntentKind intent = IntentKind.crush;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seal an intent',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'They will never know — unless they seal you back.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final m in candidates)
                RadioListTile<int>(
                  value: m.arenaPublicId,
                  // ignore: deprecated_member_use
                  groupValue: targetId,
                  // ignore: deprecated_member_use
                  onChanged: (v) => setSheet(() => targetId = v),
                  title: Text(m.displayName ?? '#${m.arenaPublicId}'),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final k in IntentKind.values)
                    ChoiceChip(
                      label: Text(k.label),
                      selected: intent == k,
                      onSelected: (_) => setSheet(() => intent = k),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.lock),
                  label: const Text('SEAL IT'),
                  onPressed:
                      targetId == null ? null : () => Navigator.pop(ctx, true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || targetId == null) return;

    await _guard(() async {
      final matched = await ref.read(sealedRepositoryProvider).sealChoice(
            arenaId: arenaId,
            targetPublicId: targetId!,
            intentKind: intent,
          );
      ref.invalidate(mySealsProvider);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(matched
            ? 'IT\'S MUTUAL. Check your matches.'
            : 'Sealed. It stays secret unless it\'s ever mutual.'),
      ));
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final handle = ref.watch(myHandleProvider);
    final arenas = ref.watch(myArenasProvider);
    final matches = ref.watch(matchesProvider);
    final mySeals = ref.watch(mySealsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sealed'),
        actions: [
          IconButton(
            tooltip: 'Join with invite code',
            icon: const Icon(Icons.key),
            onPressed: _busy ? null : _claimInvite,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _createArena,
        icon: const Icon(Icons.add),
        label: const Text('New arena'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myArenasProvider);
          ref.invalidate(mySealsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Onboarding: claim a handle ────────────────────────────────
            handle.when(
              data: (h) => h == null
                  ? Card(
                      child: ListTile(
                        leading: const Icon(Icons.alternate_email),
                        title: const Text('Claim your handle'),
                        subtitle: const Text(
                            'So people can find you to seal you.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy ? null : _claimHandle,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('@$h', style: theme.textTheme.titleLarge),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('Profile error: $e'),
            ),
            const SizedBox(height: 16),

            // ── Matches: the reveal moment ────────────────────────────────
            Text('MATCHES', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            matches.when(
              data: (list) => list.isEmpty
                  ? Text(
                      'Nothing yet. A match appears the instant a seal is mutual — even one from years ago.',
                      style: theme.textTheme.bodySmall,
                    )
                  : Column(
                      children: [
                        for (final m in list)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.favorite),
                              title: Text('Mutual — ${m.intentKind.label}'),
                              subtitle: Text(
                                  'Matched ${m.matchedAt.toLocal().toString().split('.').first}'),
                            ),
                          ),
                      ],
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load matches: $e'),
            ),
            const SizedBox(height: 24),

            // ── Arenas ────────────────────────────────────────────────────
            Text('ARENAS', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            arenas.when(
              data: (list) => list.isEmpty
                  ? Text(
                      'Create an arena for your group, then invite them in.',
                      style: theme.textTheme.bodySmall,
                    )
                  : Column(
                      children: [
                        for (final a in list)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.groups),
                              title: Text(a.name),
                              subtitle: Text('You are #${a.myPublicId}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Share invite',
                                    icon: const Icon(Icons.ios_share),
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                            _shareInvite(a.arenaId, a.name),
                                  ),
                                  IconButton(
                                    tooltip: 'Seal someone',
                                    icon: const Icon(Icons.lock_outline),
                                    onPressed: _busy
                                        ? null
                                        : () => _sealSomeone(
                                            a.arenaId, a.myPublicId),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load arenas: $e'),
            ),
            const SizedBox(height: 24),

            // ── The Someday List: your seals wait forever ─────────────────
            Text('YOUR SEALS', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            mySeals.when(
              data: (list) => list.isEmpty
                  ? Text(
                      'Zero risk: a seal costs nothing, is never revealed one-sided, and waits for years.',
                      style: theme.textTheme.bodySmall,
                    )
                  : Column(
                      children: [
                        for (final s in list)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              s.isMatched ? Icons.favorite : Icons.lock,
                              size: 18,
                            ),
                            title: Text(s.intentKind.label),
                            subtitle: Text(
                              s.isMatched
                                  ? 'Matched!'
                                  : 'Sealed ${s.createdAt.toLocal().toString().split(' ').first} — waiting silently',
                            ),
                          ),
                      ],
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load your seals: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
