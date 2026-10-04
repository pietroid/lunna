import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';

/// Hands the API client the signed-in user's Firebase token.
///
/// Shared by the app and the background refresh in
/// `notifications/background_refresh.dart`, which builds its own client
/// in an isolate of its own.
class AuthTokenProvider implements TokenProvider {
  /// Reads tokens off the given auth repository.
  AuthTokenProvider(this._authRepository);

  final AuthRepository _authRepository;

  @override
  Future<String?> getToken() async {
    return _authRepository.currentUser?.getIdToken();
  }

  @override
  Future<String?> refreshToken() async {
    return _authRepository.currentUser?.getIdToken(true);
  }
}
