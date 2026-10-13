import 'package:stylist/features/auth/domain/app_user.dart';

abstract class AccountRepository {
  /// `POST /v1/auth/session`: provisions the internal user for the signed-in identity.
  Future<AppUser> createSession();

  /// `POST /v1/auth/upgrade`; [mergeFromGuestToken] merges a guest into an existing account.
  Future<AppUser> upgrade({String? mergeFromGuestToken});

  Future<AppUser> me();
  Future<AppUser> patchMe(UserPatch patch);
  Future<void> signOut();
}
