import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/demo.dart';
import 'package:lunna/plan/view/play_sheet.dart';

/// #89's design: play's questions over the demo's day at 10:00 (Fazendo a
/// Lunna runs until 10:33, the Standup is at 12:00). `?s=<n>` picks the
/// scene. Not committed.
void main() => withClock(DemoClock.around(clock), () {
  DemoClock.pin();
  runApp(const _PreviewApp());
});

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

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
      home: const _Scene(),
    );
  }
}

class _Scene extends StatelessWidget {
  const _Scene();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = clock.now();
    DateTime at(int h, int m) => DateTime(now.year, now.month, now.day, h, m);
    const report = 'Escrever o relatório do trimestre';
    final running = l10n.demoBuilding(AppBrand.id);
    final standup = l10n.playMuchUntil(l10n.demoStandup, '12:00');

    final sheet = switch (_scene) {
      // Nothing runs: now, or 15 minutes from now.
      1 => PlayWhenQuestion(
        title: report,
        owed: 240,
        later: PlayLater.soon,
        laterAt: at(10, 15),
      ),
      // Something runs: now, or right after it.
      2 => PlayWhenQuestion(
        title: report,
        owed: 240,
        running: running,
        runningEnd: at(10, 33),
        later: PlayLater.after,
        laterAt: at(10, 38),
      ),
      // Now, while something runs: pause it, yes or no.
      3 => PauseQuestion(current: running),
      // How much, now: 4 h with 1h55 free before the standup.
      4 => PlayMuchQuestion(
        title: report,
        owed: 240,
        room: 115,
        until: standup,
      ),
      // An hour that does not fit: only the room there is.
      _ => PlayMuchQuestion(
        title: l10n.demoBacklog,
        owed: 60,
        room: 20,
        until: standup,
        at: at(11, 35),
      ),
    };

    return Stack(
      children: [
        Positioned.fill(child: DemoApp(resting: _scene == 1 || _scene == 5)),
        Positioned.fill(
          child: ColoredBox(color: AppColors.bg.withValues(alpha: 0.72)),
        ),
        Align(alignment: Alignment.bottomCenter, child: sheet),
      ],
    );
  }
}
