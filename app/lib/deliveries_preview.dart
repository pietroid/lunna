import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// Entregas, simplified, against fixed data, at Tuesday 27 October, 10:00.
///
/// `?s=1` the list: what is under way with its day, the late one first and
/// red; `?s=2` a delivery with no day dropped into Em andamento, asking
/// for one; `?s=3` the list once it is begun. Nothing ships from here.
void main() => withClock(
  Clock.fixed(DateTime(2026, 10, 27, 10)),
  () => runApp(const _PreviewApp()),
);

final int _scene =
    int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => ArtifactsCubit(
          repository: _Repository(),
          initial: ArtifactsState(
            status: ArtifactsStatus.ready,
            data: _data(begun: _scene == 3),
          ),
        ),
        child: const _Scene(),
      ),
    );
  }
}

class _Scene extends StatefulWidget {
  const _Scene();

  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  @override
  void initState() {
    super.initState();
    if (_scene == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final sinastria = context.read<ArtifactsCubit>().state.byId('ana');
        unawaited(showStartSheet(context, sinastria!));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: ArtifactsPage(shown: 10));
  }
}

/// Three under way (one late), three not begun; [begun], the synastry with
/// no day has been begun with a week.
ArtifactsData _data({required bool begun}) {
  final now = clock.now();
  DateTime day(int month, int d, [int hour = 0]) =>
      DateTime(2026, month, d, hour);

  final sinastria = Artifact(
    id: 'ana',
    title: 'Sinastria Ana e Leo',
    minutes: 120,
    createdAt: day(10, 12),
    startedAt: begun ? now : null,
    deadline: begun ? day(11, 3) : null,
    value: 280,
  );

  return ArtifactsData(
    artifacts: [
      Artifact(
        id: 'renata',
        title: 'Mapa astral da Renata',
        minutes: 180,
        doneMinutes: 60,
        createdAt: day(10, 14),
        startedAt: day(10, 21, 9),
        deadline: day(10, 28),
        value: 350,
      ),
      Artifact(
        id: 'taro',
        title: 'Curso de tarô · módulo 2',
        minutes: 600,
        doneMinutes: 240,
        createdAt: day(10, 2),
        startedAt: day(10, 20, 9),
        deadline: day(11, 6),
        value: 1200,
      ),
      Artifact(
        id: 'post',
        title: 'Post da lua cheia',
        minutes: 60,
        doneMinutes: 30,
        createdAt: day(10, 20),
        startedAt: day(10, 26, 14),
        deadline: day(10, 31),
      ),
      Artifact(
        id: 'julia',
        title: 'Mapa astral da Júlia',
        minutes: 180,
        createdAt: day(10, 22),
        deadline: day(11, 3),
        value: 350,
      ),
      sinastria,
      Artifact(
        id: 'pedro',
        title: 'Trânsitos do Pedro',
        minutes: 150,
        createdAt: day(10, 25),
        deadline: day(11, 10),
        value: 300,
      ),
    ],
    schedule: Schedule(
      needMinutes: 14 * 60 + 30,
      freeMinutes: 31 * 60,
      until: day(10, 31),
    ),
  );
}

class _Repository implements ArtifactsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<ArtifactsData>.value(_data(begun: false));
}
