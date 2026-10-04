import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart' show AppUser;

/// {@template user_repository}
/// Repository that handles user profile operations on the backend.
/// {@endtemplate}
class UserRepository {
  /// {@macro user_repository}
  UserRepository({required this.apiClient});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// Creates or updates the user record on the backend when the user signs
  /// in.
  Future<AppUser> signUpUserIfNeeded(AppUser user) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/users/signup',
      data: user.toJson(),
    );

    final data = response.data;
    if (data == null) return user;
    return AppUser.fromJson(data);
  }

  /// Returns the current user profile from the backend.
  Future<AppUser?> getMe() async {
    final response = await apiClient.get<Map<String, dynamic>>('/users/me');
    final data = response.data;
    if (data == null) return null;
    return AppUser.fromJson(data);
  }
}
