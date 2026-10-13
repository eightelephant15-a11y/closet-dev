import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.isAnonymous,
    this.email,
    this.displayName,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final bool isAnonymous;
}

/// Thrown by [AuthProvider.linkWithGoogle] when the Google account already
/// belongs to another user. [signInToExisting] completes sign-in to it.
class CredentialAlreadyInUse implements Exception {
  const CredentialAlreadyInUse(this.signInToExisting);
  final Future<AuthUser> Function() signInToExisting;
}

class AuthCancelled implements Exception {
  const AuthCancelled();
}

/// Sign-in abstraction. Apple / email link can be added as new methods or
/// implementations without touching onboarding code.
abstract class AuthProvider {
  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges;

  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signInAnonymously();

  /// Links Google to the current anonymous user, keeping the same uid.
  Future<AuthUser> linkWithGoogle();

  Future<String?> idToken({bool forceRefresh = false});
  Future<void> signOut();
}
