import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth/auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/app/app.dart';
import 'package:lunna/landing/landing.dart';
import 'package:lunna/routines/routines.dart';
import 'package:lunna/shell/shell.dart';
import 'package:notifications/notifications.dart';
import 'package:timeline/timeline.dart';

/// {@template app}
/// Root widget for the Lunna application.
/// {@endtemplate}
class App extends StatelessWidget {
  /// {@macro app}
  App({required String initialLocation, super.key})
    : _router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(path: '/', builder: (context, state) => const ShellPage()),
          // One block of time, opened from the timeline.
          GoRoute(
            path: '/evento/:id',
            builder: (context, state) =>
                EventPage(id: state.pathParameters['id']!),
          ),
          // The routines: what happens every day, and on which days.
          GoRoute(
            path: '/rotina',
            builder: (context, state) => const RoutinesPage(),
          ),
          // Signed out, the app is its own landing page.
          GoRoute(
            path: '/auth',
            builder: (context, state) => AuthScreen(
              authRepository: context.read<AuthRepository>(),
              onAuthenticated: () => context.go('/'),
              child: const LandingPage(),
            ),
          ),
        ],
      );

  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listenWhen: (previous, current) =>
          (previous.status != AppStatus.authenticated &&
              current.status == AppStatus.authenticated) ||
          current.status == AppStatus.unauthenticated,
      listener: (context, state) {
        if (state.status == AppStatus.unauthenticated) {
          _router.go('/auth');
        } else {
          // The day is per user, so it is fetched once the user is known
          // rather than when the home screen happens to be built.
          context.read<TimelineBloc>().add(const TimelineRequested());
          // The reminder queue is per user too, and mirrors the day.
          unawaited(context.read<NotificationScheduler>().sync());
        }
      },
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => context.l10n.appName,
        theme: AppTheme.dark,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
      ),
    );
  }
}
