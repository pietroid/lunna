import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_agent.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/demo/data/demo_repositories.dart';
import 'package:timeline/timeline.dart';

/// Preview of the task page (#94): `?s=1` Notas empty, `2` Pendentes empty,
/// `3` subtasks, a swipe right and a drag, `4` a swipe left, `5` the
/// delete dialog.
void main() => runApp(const _App());

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.current,
    locale: const Locale('pt', 'BR'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const _Scene(),
  );
}

class _Scene extends StatefulWidget {
  const _Scene();

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  late final _timeline = DemoTimelineRepository(context.l10n);

  ArtifactTask _task(String id, String title, int minutes, {DateTime? at}) =>
      ArtifactTask(
        id: id,
        title: title,
        minutes: minutes,
        place: TaskPlace.backlog,
        at: at,
      );

  Artifact get _artifact {
    final now = clock.now();
    final tasks = _scene >= 3
        ? [
            _task('a', 'Levantar referências visuais', 45),
            _task('b', 'Montar a estrutura das páginas', 90),
            _task('c', 'Escrever os textos da home', 60),
            _task('d', 'Revisar com o cliente', 30),
          ]
        : <ArtifactTask>[];
    return Artifact(
      id: 'p',
      title: 'Site do estúdio',
      minutes: 225,
      createdAt: now.subtract(const Duration(days: 3)),
      deadline: now.add(const Duration(days: 12)),
      tasks: tasks,
    );
  }

  @override
  void initState() {
    super.initState();
    if (_scene == 5) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        confirmDelete(context, 'Escrever os textos da home');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final artifact = _artifact;
    final data = ArtifactsData(
      artifacts: [artifact],
      schedule: Schedule(
        needMinutes: 0,
        freeMinutes: 0,
        until: clock.now().add(const Duration(days: 30)),
      ),
    );
    return RepositoryProvider<VoiceRecognizer>.value(
      value: const DemoVoiceRecognizer(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<TimelineBloc>(
            create: (_) => TimelineBloc(repository: _timeline),
          ),
          BlocProvider<VoiceCubit>(
            create: (_) => VoiceCubit(recognizer: const DemoVoiceRecognizer()),
          ),
          BlocProvider<ArtifactsCubit>(
            create: (_) => ArtifactsCubit(
              repository: DemoArtifactsRepository(context.l10n),
              initial: ArtifactsState(
                status: ArtifactsStatus.ready,
                data: data,
              ),
            ),
          ),
        ],
        child: ArtifactPage(
          id: 'p',
          initialTab: _scene == 1 ? 0 : 1,
          previewSwipe: _scene == 3
              ? ('b', 80)
              : _scene == 4
              ? ('b', -80)
              : null,
          previewLifted: _scene == 3 ? 'd' : null,
        ),
      ),
    );
  }
}
