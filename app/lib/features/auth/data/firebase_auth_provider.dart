import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:stylist/features/auth/domain/auth_provider.dart';

/// Firebase implementation. Requires Firebase project config files (not in repo).
class FirebaseAuthProvider implements AuthProvider {
  FirebaseAuthProvider({fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;

  AuthUser? _map(fb.User? u) => u == null
      ? null
      : AuthUser(
          uid: u.uid,
          isAnonymous: u.isAnonymous,
          email: u.email,
          displayName: u.displayName,
        );

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges => _auth.authStateChanges().map(_map);

  Future<fb.AuthCredential> _googleCredential() async {
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    return fb.GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      final cred = await _googleCredential();
      final result = await _auth.signInWithCredential(cred);
      return _map(result.user)!;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelled();
      }
      rethrow;
    }
  }

  @override
  Future<AuthUser> signInAnonymously() async =>
      _map((await _auth.signInAnonymously()).user)!;

  @override
  Future<AuthUser> linkWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No user to link');
    try {
      final cred = await _googleCredential();
      try {
        final result = await user.linkWithCredential(cred);
        await user.reload();
        await _auth.currentUser?.getIdToken(true); // pick up provider claims
        return _map(result.user)!;
      } on fb.FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          throw CredentialAlreadyInUse(() async {
            final r = await _auth.signInWithCredential(e.credential ?? cred);
            return _map(r.user)!;
          });
        }
        rethrow;
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelled();
      }
      rethrow;
    }
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) async =>
      _auth.currentUser?.getIdToken(forceRefresh);

  @override
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
