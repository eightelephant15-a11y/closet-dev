import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:stylist/app.dart';
import 'package:stylist/core/app_config.dart';
import 'package:stylist/core/providers.dart';

Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.forFlavor(flavor);
  if (!config.useMock && !config.useDevAuth) {
    await Firebase.initializeApp();
    await GoogleSignIn.instance.initialize(
      serverClientId: config.googleServerClientId.isEmpty
          ? null
          : config.googleServerClientId,
    );
  }
  final store = await openPrefsStore();
  final app = ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      keyValueStoreProvider.overrideWithValue(store),
    ],
    child: const StylistApp(),
  );
  if (config.sentryDsn.isEmpty) {
    runApp(app);
    return;
  }
  // Crash reporting: no PII, errors and slow-start traces only.
  await SentryFlutter.init((options) {
    options
      ..dsn = config.sentryDsn
      ..environment = config.flavor.name
      ..sendDefaultPii = false
      ..tracesSampleRate = 0.1;
  }, appRunner: () => runApp(app));
}
