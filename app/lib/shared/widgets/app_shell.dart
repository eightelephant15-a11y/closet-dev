import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/theme/tokens.dart';

/// The four main tabs: Home, My Closet, Outfits, Settings. Every other screen (capture, review, item
/// detail, onboarding...) is pushed full screen on top of this.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l10n.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.checkroom_outlined),
              selectedIcon: const Icon(Icons.checkroom),
              label: l10n.navCloset,
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: const Icon(Icons.auto_awesome),
              label: l10n.navOutfits,
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_outlined),
              selectedIcon: const Icon(Icons.tune),
              label: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}

/// Space the floating "Add item" button needs so it never covers the last row.
const double fabClearance = Spacing.xxl + Spacing.xl;
