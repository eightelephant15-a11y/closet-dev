import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/core/app_config.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/core/storage/key_value_store.dart';
import 'package:stylist/features/auth/data/dev_auth_provider.dart';

/// Stands in for the local API's `POST /dev/token`.
class _FakeTokenServer implements HttpClientAdapter {
  final requests = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.path, '/dev/token');
    final body = options.data as Map<String, dynamic>;
    requests.add(body);
    final uid = (body['uid'] as String?) ?? 'dev-generated';
    final email = body['email'] as String?;
    return ResponseBody.fromString(
      jsonEncode({
        'token': 'dev.token.${requests.length}',
        'uid': uid,
        'email': email,
        'name': body['name'],
        'is_anonymous': email == null,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AppConfig config({
  required Flavor flavor,
  String authMode = 'dev',
  bool useMock = false,
}) => AppConfig(
  flavor: flavor,
  appName: 'x',
  apiBaseUrl: 'http://localhost:8000',
  useMock: useMock,
  authMode: authMode,
);

void main() {
  group('dev auth can never leak into real flavors', () {
    test('only the dev flavor honours AUTH_MODE=dev', () {
      expect(config(flavor: Flavor.dev).useDevAuth, isTrue);
      expect(config(flavor: Flavor.staging).useDevAuth, isFalse);
      expect(config(flavor: Flavor.prod).useDevAuth, isFalse);
    });

    test('firebase mode and mock mode never use dev auth', () {
      expect(
        config(flavor: Flavor.dev, authMode: 'firebase').useDevAuth,
        isFalse,
      );
      expect(config(flavor: Flavor.dev, useMock: true).useDevAuth, isFalse);
    });

    test('prod flavor config ignores dart-define overrides for mock', () {
      expect(AppConfig.forFlavor(Flavor.prod).useMock, isFalse);
      expect(AppConfig.forFlavor(Flavor.prod).useDevAuth, isFalse);
    });
  });

  group('API base URL for emulators', () {
    test('android emulator reaches the host through 10.0.2.2', () {
      expect(
        resolveApiBaseUrl('http://localhost:8000', isAndroid: true),
        'http://10.0.2.2:8000',
      );
      expect(
        resolveApiBaseUrl('http://127.0.0.1:9000/x', isAndroid: true),
        'http://10.0.2.2:9000/x',
      );
    });

    test('other hosts and platforms are untouched', () {
      expect(
        resolveApiBaseUrl('http://localhost:8000', isAndroid: false),
        'http://localhost:8000',
      );
      expect(
        resolveApiBaseUrl('https://api.example.com', isAndroid: true),
        'https://api.example.com',
      );
      expect(
        resolveApiBaseUrl('http://192.168.1.20:8000', isAndroid: true),
        'http://192.168.1.20:8000',
      );
    });
  });

  group('DevAuthProvider', () {
    late _FakeTokenServer server;
    late MemoryKeyValueStore store;
    late DevAuthProvider auth;

    DevAuthProvider make() => DevAuthProvider(
      baseUrl: 'http://localhost:8000',
      store: store,
      dio: Dio(BaseOptions(baseUrl: 'http://localhost:8000'))
        ..httpClientAdapter = server,
    );

    setUp(() {
      server = _FakeTokenServer();
      store = MemoryKeyValueStore();
      auth = make();
    });

    test('guest then link keeps the same uid and adds the email', () async {
      final guest = await auth.signInAnonymously();
      expect(guest.isAnonymous, isTrue);
      final linked = await auth.linkWithGoogle();
      expect(linked.uid, guest.uid);
      expect(linked.isAnonymous, isFalse);
      expect(linked.email, 'ada@example.com');
      expect(server.requests.last['uid'], guest.uid);
    });

    test(
      'google sign-in uses a stable uid; tokens come from the server',
      () async {
        final u = await auth.signInWithGoogle();
        expect(u.uid, 'dev-google-ada');
        expect(await auth.idToken(), startsWith('dev.token.'));
      },
    );

    test('forceRefresh mints a new token for the same user', () async {
      await auth.signInWithGoogle();
      final first = await auth.idToken();
      final second = await auth.idToken(forceRefresh: true);
      expect(second, isNot(first));
      expect(auth.currentUser!.uid, 'dev-google-ada');
    });

    test('linking without an anonymous user is an error', () async {
      expect(auth.linkWithGoogle, throwsStateError);
      await auth.signInWithGoogle();
      expect(auth.linkWithGoogle, throwsStateError);
    });

    test('session survives a restart and sign-out clears it', () async {
      await auth.signInAnonymously();
      final restarted = make();
      expect(restarted.currentUser!.isAnonymous, isTrue);
      expect(await restarted.idToken(), isNotNull);
      await restarted.signOut();
      expect(restarted.currentUser, isNull);
      expect(await restarted.idToken(), isNull);
      expect(make().currentUser, isNull);
    });
  });
}
