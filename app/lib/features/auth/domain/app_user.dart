import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

enum Units { imperial, metric }

enum UserStatus {
  active,
  @JsonValue('pending_deletion')
  pendingDeletion,
  deleted,
}

enum ClothingDepartment { menswear, womenswear, both, everything }

@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required bool isAnonymous,
    @Default('en-US') String locale,
    @Default(Units.imperial) Units units,
    @Default(UserStatus.active) UserStatus status,
    String? email,
    String? displayName,
    String? city,
    ClothingDepartment? clothingDepartment,
    DateTime? ageConfirmedAt,
    String? dailyOutfitTime,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}

/// Partial update for `PATCH /v1/me`; null fields are not sent.
class UserPatch {
  const UserPatch({
    this.displayName,
    this.units,
    this.city,
    this.clothingDepartment,
    this.dailyOutfitTime,
  });

  final String? displayName;
  final Units? units;
  final String? city;
  final ClothingDepartment? clothingDepartment;
  final String? dailyOutfitTime;

  Map<String, dynamic> toJson() => {
    if (displayName != null) 'display_name': displayName,
    if (units != null) 'units': units!.name,
    if (city != null) 'city': city,
    if (clothingDepartment != null)
      'clothing_department': clothingDepartment!.name,
    if (dailyOutfitTime != null) 'daily_outfit_time': dailyOutfitTime,
  };
}
