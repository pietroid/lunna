import 'package:auth/src/models/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// {@template auth_repository}
/// Repository that abstracts authentication operations.
/// {@endtemplate}
abstract class AuthRepository {
  /// {@macro auth_repository}
  const AuthRepository();

  /// Stream of the currently signed-in [AppUser].
  ///
  /// Emits `null` when no user is signed in.
  Stream<AppUser?> get user;

  /// The currently signed-in [FirebaseAuth] user, if any.
  User? get currentUser;

  /// Whether the current user is signed in.
  Future<bool> isAuthenticated();

  /// Signs in with Google.
  Future<void> signInWithGoogle();

  /// Signs the current user out.
  Future<void> signOut();
}

/// {@template firebase_auth_repository}
/// [AuthRepository] implementation backed by Firebase Authentication.
/// {@endtemplate}
class FirebaseAuthRepository implements AuthRepository {
  /// {@macro firebase_auth_repository}
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    String? clientId,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(clientId: clientId);

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Stream<AppUser?> get user => _firebaseAuth.authStateChanges().map(
    (firebaseUser) {
      if (firebaseUser == null) return null;
      return AppUser(
        id: firebaseUser.uid,
        name: firebaseUser.displayName,
        email: firebaseUser.email,
        photoUrl: firebaseUser.photoURL,
      );
    },
  );

  @override
  Future<bool> isAuthenticated() async {
    final user = await _firebaseAuth.authStateChanges().first;
    return user != null;
  }

  @override
  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    await _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
