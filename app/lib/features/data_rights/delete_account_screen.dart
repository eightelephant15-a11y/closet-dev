import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/features/settings/account_actions.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
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
    final confirmed = _controller.text.trim() == l10n.deleteConfirmWord;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteTitle)),
      body: PageBody(
        child: ListView(
          children: [
            Text(l10n.deleteBody, style: Theme.of(context).textTheme.bodyLarge),
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
            else
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: confirmed ? _delete : null,
                child: Text(l10n.deleteButton),
              ),
          ],
        ),
      ),
    );
  }
}
