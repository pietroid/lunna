import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/demo.dart';
import 'package:lunna/notifications/view/reminder_sheet.dart';
import 'package:notifications/notifications.dart';

/// The reminders' design, drawn by the app on the demo's day.
///
/// `?s=1` Agora with a block 12 minutes past its end; `?s=2` the sheet a
/// tap on a task's end reminder opens; `?s=3` a task's start; `?s=4` a
/// fixed block's start; `?s=5` the Lock Screen with the new copy. Nothing
/// ships from here.
void main() {
  runApp(const _PreviewApp());
}

final int _scene = int.tryParse(Uri.base.queryParameters['s'] ?? '') ?? 1;

final _navigator = GlobalKey<NavigatorState>();

class _PreviewApp extends StatefulWidget {
  const _PreviewApp();

  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> {
  @override
  void initState() {
    super.initState();
    if (_scene >= 2 && _scene <= 4) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    }
  }

  Future<void> _open() async {
    // Let the day load under it first.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final context = _navigator.currentContext;
    if (context == null || !context.mounted) return;

    final l10n = context.l10n;
    final now = clock.now();
    String at(int minutes) {
      final time = now.add(Duration(minutes: minutes));
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }

    final ask = switch (_scene) {
      2 => ReminderAsk(
        title: l10n.demoBuilding(AppBrand.id),
        card: NotificationCard.task,
        edge: NotificationEdge.end,
        hours: l10n.reminderHours(at(-45), at(0)),
      ),
      3 => ReminderAsk(
        title: l10n.demoGroceries,
        card: NotificationCard.task,
        edge: NotificationEdge.start,
        hours: l10n.reminderHours(at(0), at(30)),
      ),
      _ => ReminderAsk(
        title: l10n.demoStandup,
        card: NotificationCard.event,
        edge: NotificationEdge.start,
        hours: l10n.reminderHours(at(0), at(15)),
      ),
    };
    unawaited(ReminderSheet.show(context, ask));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: switch (_scene) {
        1 => const DemoApp(late: 12),
        2 => const DemoApp(),
        5 => const _LockScreen(),
        _ => const DemoApp(resting: true),
      },
    );
  }
}

/// The phone's Lock Screen, as iOS draws it, with the one reminder left on
/// it. Not the app: only here to show the reminder's words.
class _LockScreen extends StatelessWidget {
  const _LockScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = AppTypography.body.copyWith(color: const Color(0xFFFFFFFF));

    final now = clock.now();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A2A33), Color(0xFF15161E)],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.s8),
                Text(
                  '${now.hour.toString().padLeft(2, '0')}:'
                  '${now.minute.toString().padLeft(2, '0')}',
                  style: AppTypography.display.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontSize: 84,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _Banner(
                  title: l10n.demoBuilding(AppBrand.id),
                  body: l10n.reminderEnding,
                  style: white,
                ),
                const SizedBox(height: AppSpacing.s8 * 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.title, required this.body, required this.style});

  final String title;
  final String body;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Center(
              child: AppIcon(
                iconData: AppIcons.agent,
                size: 22,
                color: AppColors.onAccent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: style.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'agora',
                      style: AppTypography.label.copyWith(
                        color: const Color(0x99FFFFFF),
                      ),
                    ),
                  ],
                ),
                Text(body, style: style),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
