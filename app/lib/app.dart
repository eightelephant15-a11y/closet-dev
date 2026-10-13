import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/analytics/abandonment_tracker.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/core/sync/sync_triggers.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/router/app_router.dart';
import 'package:stylist/theme/app_theme.dart';

class StylistApp extends ConsumerWidget {
  const StylistApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return MaterialApp.router(
      title: config.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => SyncTriggers(
        child: AbandonmentTracker(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
