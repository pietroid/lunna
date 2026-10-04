import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lunna/app/app.dart';
import 'package:lunna/auth_token_provider.dart';
import 'package:lunna/bootstrap.dart';
import 'package:lunna/config.dart';
import 'package:lunna/notifications/background_refresh.dart';
import 'package:notifications/notifications.dart';
import 'package:timeline/timeline.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authRepository = BetterAuthRepository(
    apiBaseUrl: kApiBaseUrl,
    // The web build signs in through the redirect and needs no client id.
    // iOS reads its own from the reversed URL scheme in Info.plist when this
    // is null, but naming it here is what lets one build serve both flavors.
    googleClientId: kIsWeb ? null : nullIfEmpty(kGoogleIosClientId),
    // The ID token is minted for the web client, which is the one the
    // server always accepts.
    googleServerClientId: kIsWeb ? null : nullIfEmpty(kGoogleWebClientId),
  );
  final apiClient = ApiClient(
    baseUrl: kApiBaseUrl,
    tokenProvider: AuthTokenProvider(authRepository),
  );
  final timelineRepository = TimelineRepository(apiClient: apiClient);
  final routinesRepository = RoutinesRepository(apiClient: apiClient);
  final notificationScheduler = NotificationScheduler(
    repository: NotificationsRepository(apiClient: apiClient),
  );
  await notificationScheduler.initialize();
  unawaited(registerBackgroundRefresh());

  final initialUser = await authRepository.restore();
  final initialLocation = initialUser == null ? '/auth' : '/';

  await bootstrap(
    () => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => authRepository),
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
            create: (_) {
              final bloc = TimelineBloc(repository: timelineRepository);
              if (initialUser != null) bloc.add(const TimelineRequested());
              return bloc;
            },
          ),
        ],
        child: App(initialLocation: initialLocation),
      ),
    ),
  );
}
