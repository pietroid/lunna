import 'package:auth/src/data/auth_repository.dart';

/// Whether the current user is signed in.
///
/// Waits for Firebase Auth to restore the persisted auth state before
/// returning.
Future<bool> isUserAuthenticated() {
  return FirebaseAuthRepository().isAuthenticated();
}
