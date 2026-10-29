import 'dart:async';

import 'package:agent/agent.dart';
import 'package:analytics/analytics.dart';
import 'package:api_client/api_client.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:auth/auth.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lunna/app/app.dart';
import 'package:lunna/auth_token_provider.dart';
import 'package:lunna/bootstrap.dart';
import 'package:lunna/config.dart';
import 'package:lunna/demo/demo_clock.dart';
import 'package:lunna/links/api_link_previews.dart';
import 'package:lunna/notifications/background_refresh.dart';
import 'package:lunna/notifications/live_activity.dart';
import 'package:notifications/notifications.dart';
import 'package:timeline/timeline.dart';

// The whole app runs on a clock the landing page's demo can move to a
// working hour; signed in, nothing moves it.
Future<void> main() => withClock(DemoClock.around(clock), _main);

Future<void> _main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Off without a key: dev builds, CI and the previews send nothing.
  final analytics = kPostHogKey.isEmpty
      ? const NoAnalytics()
      : await PostHogAnalytics.start(key: kPostHogKey, host: kPostHogHost);

  final authRepository = BetterAuthRepository(
    apiBaseUrl: kApiBaseUrl,
    // The web build signs in through the redirect and needs no client id.
    // iOS reads its own from the reversed URL scheme in Info.plist when this
    // is null, but naming it here is what lets one build serve both flavors.
    googleClientId: kIsWeb ? null : nullIfEmpty(kGoogleIosClientId),
    // The ID token is minted for the web client, which is the one the
    // server always accepts.
    googleServerClientId: kIsWeb ? null : nullIfEmpty(kGoogleWebClientId),
    // Per brand and env, from the define; only equal to the default here.
    // ignore: avoid_redundant_argument_values
    googleWebProvider: kGoogleWebProvider,
  );
  final apiClient = ApiClient(
    baseUrl: kApiBaseUrl,
    tokenProvider: AuthTokenProvider(authRepository),
    // A 5xx is the server's failure, which the person saw; a dropped
    // network is not.
    onServerError: (error) => unawaited(
      analytics.captureException(
        error,
        stackTrace: error.stackTrace,
        properties: {
          'method': error.requestOptions.method,
          'path': error.requestOptions.path,
          'status': error.response?.statusCode ?? 0,
        },
      ),
    ),
  );
  final timelineRepository = TimelineRepository(apiClient: apiClient);
  final agentRepository = AgentRepository(apiClient: apiClient);
  final routinesRepository = RoutinesRepository(apiClient: apiClient);
  final artifactsRepository = ArtifactsRepository(apiClient: apiClient);
  final linkPreviews = ApiLinkPreviews(
    apiClient: apiClient,
    apiBaseUrl: kApiBaseUrl,
  );
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
        RepositoryProvider<AgentRepository>(create: (_) => agentRepository),
        RepositoryProvider<VoiceRecognizer>(
          create: (_) => SpeechVoiceRecognizer(),
        ),
        RepositoryProvider<RoutinesRepository>(
          create: (_) => routinesRepository,
        ),
        RepositoryProvider<ArtifactsRepository>(
          create: (_) => artifactsRepository,
        ),
        RepositoryProvider<NotificationScheduler>(
          create: (_) => notificationScheduler,
        ),
        RepositoryProvider<LiveActivity>(
          create: (_) => LiveActivity(apiBaseUrl: kApiBaseUrl),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AppBloc>(
            create: (_) => AppBloc(
              authRepository: authRepository,
              initialUser: initialUser,
              analytics: analytics,
            ),
          ),
          // The conversations of the session: each opening of the sheet
          // starts a new one, with the ones before it above.
          BlocProvider<AgentCubit>(
            create: (_) => AgentCubit(repository: agentRepository),
          ),
          // One recording for the app, so one started on Tempo's bar
          // carries on in the conversation.
          BlocProvider<VoiceCubit>(
            create: (context) =>
                VoiceCubit(recognizer: context.read<VoiceRecognizer>()),
          ),
          BlocProvider<TimelineBloc>(
            create: (_) {
              final bloc = TimelineBloc(repository: timelineRepository);
              if (initialUser != null) bloc.add(const TimelineRequested());
              return bloc;
            },
          ),
          // A task let out of an artifact lands on the day, so the day is
          // read again whenever one moves.
          BlocProvider<ArtifactsCubit>(
            create: (context) => ArtifactsCubit(
              repository: artifactsRepository,
              onDayChanged: () =>
                  context.read<TimelineBloc>().add(const TimelineRequested()),
            ),
          ),
        ],
        // Above the router, so the notes of every page draw their links.
        child: LinkPreviewScope(
          previews: linkPreviews,
          child: AnalyticsScope(
            analytics: analytics,
            child: App(initialLocation: initialLocation, analytics: analytics),
          ),
        ),
      ),
    ),
    analytics: analytics,
  );
}
