import 'dart:async';

import 'package:agent/agent.dart';
import 'package:analytics/analytics.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth/auth.dart';
import 'package:cycle/cycle.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/app/app.dart';
import 'package:lunna/landing/landing.dart';
import 'package:lunna/notifications/live_activity.dart';
import 'package:lunna/routines/routines.dart';
import 'package:lunna/shell/shell.dart';
import 'package:notifications/notifications.dart';
import 'package:timeline/timeline.dart';

/// {@template app}
/// Root widget for the Lunna application.
/// {@endtemplate}
class App extends StatelessWidget {
  /// {@macro app}
  ///
  /// Each route has a `name`, which is the screen PostHog reports.
  App({
    required String initialLocation,
    this.analytics = const NoAnalytics(),
    super.key,
  }) : _router = GoRouter(
         initialLocation: initialLocation,
         observers: analytics.navigatorObservers,
         routes: [
           // The tabs are one route; ShellPage reports each as a screen.
           GoRoute(
             path: '/',
             name: 'Inicio',
             builder: (context, state) => const ShellPage(),
           ),
           // One block of time, opened from the timeline.
           GoRoute(
             path: '/evento/:id',
             name: 'Evento',
             builder: (context, state) => EventPage(
               id: state.pathParameters['id']!,
               dock: NotesDock.task,
             ),
           ),
           // The routines: what happens every day, and on which days.
           GoRoute(
             path: '/rotina',
             name: 'Rotina',
             builder: (context, state) => const RoutinesPage(),
           ),
           // The cycle and the days off, opened from Menu's Ritmo. The
           // rhythm's cubit is the app's, so a weekend put back to work on
           // the calendar and here are one.
           GoRoute(
             path: '/ciclo',
             name: 'Ciclo',
             builder: (context, state) => _Rhythm(
               child: CyclePage(dock: _dockOnTheDay(context)),
             ),
           ),
           GoRoute(
             path: '/folgas',
             name: 'Folgas',
             builder: (context, state) => _Rhythm(
               child: DaysOffPage(dock: _dockOnTheDay(context)),
             ),
           ),
           // Everything done, opened from Menu.
           GoRoute(
             path: '/feitas',
             name: 'Feitas',
             builder: (context, state) => BlocProvider(
               create: (context) {
                 final cubit = DoneArchiveCubit(
                   repository: context.read<TimelineRepository>(),
                 );
                 unawaited(cubit.load());
                 return cubit;
               },
               child: DoneArchivePage(
                 // Nothing here to write down but the day's: the + puts a
                 // task in Para depois, as it would from anywhere.
                 dock: AskDock(
                   fab: AppFab(
                     tooltip: context.l10n.shellWriteDown,
                     onPressed: () => unawaited(writeDownOnTimeline(context)),
                   ),
                 ),
                 // A finished task is not on the timeline, so its page is
                 // handed the card the archive drew.
                 onOpen: (card) => Navigator.of(context).push(
                   MaterialPageRoute<void>(
                     builder: (_) => EventPage(
                       id: card.id,
                       finished: card,
                       dock: NotesDock.task,
                     ),
                   ),
                 ),
               ),
             ),
           ),
           // Signed out, the app is its own landing page.
           GoRoute(
             path: '/auth',
             name: 'Entrada',
             builder: (context, state) => AuthScreen(
               authRepository: context.read<AuthRepository>(),
               onAuthenticated: () => context.go('/'),
               child: const LandingPage(),
             ),
           ),
         ],
       );

  /// The agent's bar on a page with nothing of its own to write: the +
  /// writes something down on the day, as from anywhere.
  static Widget _dockOnTheDay(BuildContext context) => AskDock(
    fab: AppFab(
      tooltip: context.l10n.shellWriteDown,
      onPressed: () => unawaited(writeDownOnTimeline(context)),
    ),
  );

  /// Where screens are reported, and what wraps the app for replays.
  final Analytics analytics;

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
          // Nobody's block runs on a signed-out phone.
          unawaited(context.read<LiveActivity>().sync());
          _router.go('/auth');
        } else {
          // The day is per user, so it is fetched once the user is known
          // rather than when the home screen happens to be built.
          context.read<TimelineBloc>().add(const TimelineRequested());
          // The reminder queue is per user too, and mirrors the day.
          unawaited(context.read<NotificationScheduler>().sync());
        }
      },
      child: analytics.wrap(
        MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => context.l10n.appName(AppBrand.id),
          theme: AppTheme.current,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: _router,
        ),
      ),
    );
  }
}

/// [child], with the rhythm read again as it opens: Ciclo and Folgas draw
/// what the server has now.
class _Rhythm extends StatefulWidget {
  const _Rhythm({required this.child});

  final Widget child;

  @override
  State<_Rhythm> createState() => _RhythmState();
}

class _RhythmState extends State<_Rhythm> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<CycleCubit>().load());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
