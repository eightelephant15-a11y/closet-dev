import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/settings/account_actions.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/atelier.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(accountActionsProvider).deleteAccount();
      messenger.showSnackBar(SnackBar(content: Text(l10n.deleteDone)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final confirmed = _controller.text.trim() == l10n.deleteConfirmWord;
    final garments = ref.watch(closetSummaryProvider).valueOrNull?.total;
    Widget bullet(IconData icon, String label) => Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 20, color: scheme.error)),
          const SizedBox(width: Spacing.sm + 4),
          Expanded(child: Text(label, style: text.bodyMedium)),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteTitle)),
      body: PageBody(
        child: ListView(
          children: [
            Eyebrow(l10n.deleteEyebrow, color: scheme.error),
            const SizedBox(height: Spacing.xs),
            Text(l10n.deleteBody, style: text.bodyLarge),
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(RadiusTokens.lg),
                border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: scheme.error,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            l10n.deleteListTitle,
                            style: text.titleMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                  bullet(
                    Icons.checkroom_outlined,
                    l10n.deleteListGarments(garments ?? 0),
                  ),
                  bullet(Icons.palette_outlined, l10n.deleteListProfile),
                  bullet(Icons.person_outline, l10n.deleteListAccount),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            NoteCard(
              icon: Icons.schedule,
              title: l10n.deleteGraceTitle,
              child: Text(l10n.deleteGraceBody),
            ),
            const SizedBox(height: Spacing.lg),
            TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: l10n.deleteTypePrompt),
            ),
            const SizedBox(height: Spacing.lg),
            if (_busy)
              const LoadingView()
            else ...[
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  onPressed: confirmed ? _delete : null,
                  child: Text(l10n.deleteButton),
                ),
              ),
              const SizedBox(height: Spacing.sm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: scheme.surfaceContainerLowest,
                  foregroundColor: scheme.onSurface,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l10n.deleteKeep),
              ),
            ],
            const SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }
}
