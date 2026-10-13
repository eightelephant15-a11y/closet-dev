import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stylist/core/app_config.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/auth/data/account_repositories.dart';
import 'package:stylist/features/auth/data/fake_auth_provider.dart';
import 'package:stylist/features/config/data/config_repositories.dart';
import 'package:stylist/features/config/domain/remote_config.dart';

class Harness {
  Harness({
    FakeAuthProvider? auth,
    RemoteConfig config = const RemoteConfig(),
    KeyValueStore? store,
  }) : store = store ?? MemoryKeyValueStore() {
    this.auth = auth ?? FakeAuthProvider(store: this.store);
    accounts = MockAccountRepository(this.auth, this.store);
    configRepo = MockConfigRepository(config);
  }

  final KeyValueStore store;
  late final FakeAuthProvider auth;
  late final MockAccountRepository accounts;
  late final MockConfigRepository configRepo;

  List<Override> get overrides => [
    appConfigProvider.overrideWithValue(AppConfig.forFlavor(Flavor.dev)),
    keyValueStoreProvider.overrideWithValue(store),
    authProviderProvider.overrideWithValue(auth),
    accountRepositoryProvider.overrideWithValue(accounts),
    configRepositoryProvider.overrideWithValue(configRepo),
  ];

  ProviderContainer container() => ProviderContainer(overrides: overrides);
}
