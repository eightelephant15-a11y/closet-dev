import 'package:freezed_annotation/freezed_annotation.dart';

part 'remote_config.freezed.dart';
part 'remote_config.g.dart';

enum OnboardingVariant {
  @JsonValue('quiz_first')
  quizFirst,
  @JsonValue('closet_first')
  closetFirst,
}

@freezed
abstract class RemoteConfig with _$RemoteConfig {
  const factory RemoteConfig({
    @Default(true) bool guestModeEnabled,
    @Default(OnboardingVariant.quizFirst) OnboardingVariant onboardingVariant,
    @Default('2026-01') String policyVersion,
    @Default('https://example.com/privacy') String privacyPolicyUrl,
    @Default('https://example.com/terms') String termsUrl,
    @Default(16) int minAge,
  }) = _RemoteConfig;

  /// Parses the `GET /v1/config` payload, tolerating missing/unknown flags.
  factory RemoteConfig.fromApi(Map<String, dynamic> json) {
    final flags = (json['flags'] as Map?)?.cast<String, dynamic>() ?? const {};
    const d = RemoteConfig();
    return RemoteConfig(
      guestModeEnabled: flags['guest_mode_enabled'] is bool
          ? flags['guest_mode_enabled'] as bool
          : d.guestModeEnabled,
      onboardingVariant: flags['onboarding_variant'] == 'closet_first'
          ? OnboardingVariant.closetFirst
          : OnboardingVariant.quizFirst,
      policyVersion: json['policy_version'] as String? ?? d.policyVersion,
      privacyPolicyUrl:
          json['privacy_policy_url'] as String? ?? d.privacyPolicyUrl,
      termsUrl: json['terms_url'] as String? ?? d.termsUrl,
      minAge: json['min_age'] as int? ?? d.minAge,
    );
  }

  factory RemoteConfig.fromJson(Map<String, dynamic> json) =>
      _$RemoteConfigFromJson(json);
}

abstract class ConfigRepository {
  /// Fetches remote config; falls back to the last cached or default values offline.
  Future<RemoteConfig> load();
}
