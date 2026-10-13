enum Flavor { dev, staging, prod }

/// Build-time configuration. Values come from `--dart-define` and flavor entrypoints.
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.apiBaseUrl,
    required this.useMock,
    this.sentryDsn = const String.fromEnvironment('SENTRY_DSN'),
    this.posthogKey = const String.fromEnvironment('POSTHOG_KEY'),
    this.googleServerClientId = const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
    ),
    this.privacyUrl = 'https://example.com/privacy',
    this.termsUrl = 'https://example.com/terms',
  });

  factory AppConfig.forFlavor(Flavor flavor) {
    const useMockDefine = bool.fromEnvironment('USE_MOCK', defaultValue: true);
    const apiOverride = String.fromEnvironment('API_BASE_URL');
    return switch (flavor) {
      Flavor.dev => AppConfig(
        flavor: flavor,
        appName: 'Stylist Dev',
        apiBaseUrl: apiOverride.isEmpty ? 'http://localhost:8000' : apiOverride,
        useMock: useMockDefine,
      ),
      Flavor.staging => AppConfig(
        flavor: flavor,
        appName: 'Stylist Staging',
        apiBaseUrl: apiOverride.isEmpty
            ? 'https://api.staging.example.com'
            : apiOverride,
        useMock: const bool.fromEnvironment('USE_MOCK'),
      ),
      Flavor.prod => AppConfig(
        flavor: flavor,
        appName: 'Stylist',
        apiBaseUrl: apiOverride.isEmpty
            ? 'https://api.example.com'
            : apiOverride,
        useMock: false,
      ),
    };
  }

  final Flavor flavor;
  final String appName;
  final String apiBaseUrl;
  final bool useMock;
  final String sentryDsn;
  final String posthogKey;

  /// OAuth *web* client ID from the Firebase project (Google sign-in).
  final String googleServerClientId;
  final String privacyUrl;
  final String termsUrl;
}
