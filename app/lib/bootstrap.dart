import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/app.dart';
import 'package:stylist/core/app_config.dart';
import 'package:stylist/core/providers.dart';

Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.forFlavor(flavor);
  if (!config.useMock) await Firebase.initializeApp();
  final store = await openPrefsStore();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        keyValueStoreProvider.overrideWithValue(store),
      ],
      child: const StylistApp(),
    ),
  );
}
