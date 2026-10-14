import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/features/auth/application/session_controller.dart';
import 'package:stylist/features/closet/presentation/closet_routes.dart';
import 'package:stylist/features/optional/optional_screens.dart';
import 'package:stylist/features/settings/settings_screen.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final name = session.user?.displayName;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          IconButton(
            tooltip: l10n.homeSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(SettingsRoutes.root),
          ),
        ],
      ),
      body: PageBody(
        child: ListView(
          children: [
            if (session.offline) const OfflineBanner(),
            Text(
              name == null || name.isEmpty
                  ? l10n.homeGreetingNoName
                  : l10n.homeGreeting(name),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: Spacing.sm),
            Text(l10n.homePlaceholder),
            const SizedBox(height: Spacing.md),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                minVerticalPadding: Spacing.md,
                leading: const Icon(Icons.checkroom_outlined),
                title: Text(l10n.homeClosetCard),
                subtitle: Text(l10n.homeClosetCardBody),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(ClosetRoutes.root),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              l10n.homeFinishSetup,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.sm),
            const OptionalTiles(),
          ],
        ),
      ),
    );
  }
}
