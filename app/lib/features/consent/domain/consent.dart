class ConsentState {
  const ConsentState({
    this.analyticsOptIn,
    this.noAiTraining = true,
    this.policyVersion = '2026-01',
    this.locationExplained = false,
  });

  factory ConsentState.fromJson(Map<String, dynamic> j) => ConsentState(
    analyticsOptIn: j['analytics_opt_in'] as bool?,
    noAiTraining: j['no_ai_training'] as bool? ?? true,
    policyVersion: j['policy_version'] as String? ?? '2026-01',
    locationExplained:
        j['location_explained_at'] != null || j['location_explained'] == true,
  );

  /// null = not decided yet. Nothing is sent to analytics until true.
  final bool? analyticsOptIn;

  /// "Do not use my photos to train AI models": ON by default.
  final bool noAiTraining;
  final String policyVersion;
  final bool locationExplained;

  bool get analyticsDecided => analyticsOptIn != null;

  ConsentState copyWith({
    bool? analyticsOptIn,
    bool? noAiTraining,
    String? policyVersion,
    bool? locationExplained,
  }) => ConsentState(
    analyticsOptIn: analyticsOptIn ?? this.analyticsOptIn,
    noAiTraining: noAiTraining ?? this.noAiTraining,
    policyVersion: policyVersion ?? this.policyVersion,
    locationExplained: locationExplained ?? this.locationExplained,
  );

  Map<String, dynamic> toJson() => {
    'analytics_opt_in': analyticsOptIn,
    'no_ai_training': noAiTraining,
    'policy_version': policyVersion,
    'location_explained': locationExplained,
  };
}

abstract class ConsentRepository {
  Future<ConsentState> get();

  /// Only non-null fields are changed; the server stamps time and policy version.
  Future<ConsentState> put({
    bool? analyticsOptIn,
    bool? noAiTraining,
    bool? locationExplained,
  });
}
