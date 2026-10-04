import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:chat/chat.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/app.dart';
import 'package:focus/auth_token_provider.dart';
import 'package:focus/bootstrap.dart';
import 'package:focus/firebase_options_production.dart' as prod;
import 'package:focus/firebase_options_dev.dart' as dev;
import 'package:focus/notifications/background_refresh.dart';
import 'package:notifications/notifications.dart';
import 'package:user/user.dart';

const _kGoogleSignInClientId = String.fromEnvironment(
  'GOOGLE_SIGN_IN_CLIENT_ID',
);
const _kApiBaseUrl = String.fromEnvironment('API_BASE_URL');

const _kFlavor = String.fromEnvironment('FLAVOR', defaultValue: 'production');

Future<void> main() async {
  // The flavor selects the Firebase project. Production uses focus-production
  // and the dev build uses focus-local-dev.
  final FirebaseOptions options;
  switch (_kFlavor) {
    case 'dev':
      options = dev.DefaultFirebaseOptions.currentPlatform;
    case 'production':
    default:
      options = prod.DefaultFirebaseOptions.currentPlatform;
  }

  await _runAppWithFirebaseOptions(options);
}

Future<void> _runAppWithFirebaseOptions(FirebaseOptions firebaseOptions) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);

  final authRepository = FirebaseAuthRepository(
    clientId: kIsWeb ? _kGoogleSignInClientId : null,
  );
  final apiClient = ApiClient(
    baseUrl: _kApiBaseUrl,
    tokenProvider: AuthTokenProvider(authRepository),
  );
  final userRepository = UserRepository(apiClient: apiClient);
  final chatRepository = ChatRepository(apiClient: apiClient);
  final timelineRepository = TimelineRepository(apiClient: apiClient);
  final thingsRepository = ThingsRepository(apiClient: apiClient);
  final routinesRepository = RoutinesRepository(apiClient: apiClient);
  final notificationScheduler = NotificationScheduler(
    repository: NotificationsRepository(apiClient: apiClient),
  );
  await notificationScheduler.initialize();
  unawaited(registerBackgroundRefresh());

  final initialUser = await authRepository.user.first;
  final initialLocation = initialUser == null ? '/auth' : '/';

  await bootstrap(
    () => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => authRepository),
        RepositoryProvider<ChatRepository>(create: (_) => chatRepository),
        RepositoryProvider<TimelineRepository>(
          create: (_) => timelineRepository,
        ),
        RepositoryProvider<RoutinesRepository>(
          create: (_) => routinesRepository,
        ),
        RepositoryProvider<NotificationScheduler>(
          create: (_) => notificationScheduler,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AppBloc>(
            create: (_) => AppBloc(
              authRepository: authRepository,
              initialUser: initialUser,
            ),
          ),
          BlocProvider<TimelineBloc>(
            create: (_) =>
                TimelineBloc(repository: timelineRepository)
                  ..add(const TimelineRequested()),
          ),
          BlocProvider<ThingsBloc>(
            create: (_) =>
                ThingsBloc(repository: thingsRepository)
                  ..add(const ThingsRequested()),
          ),
        ],
        child: App(
          initialLocation: initialLocation,
          onUserAuthenticated: userRepository.signUpUserIfNeeded,
        ),
      ),
    ),
  );
}
