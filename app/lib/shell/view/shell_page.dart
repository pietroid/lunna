import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/home/home.dart';
import 'package:lunna/notifications/notifications.dart';
import 'package:timeline/timeline.dart';

/// {@template shell_page}
/// The app's three destinations, and the button that writes something down.
///
/// The destinations are kept alive behind an [IndexedStack] rather than
/// rebuilt on every tap: moving between them is not navigation, it is looking
/// somewhere else, and a list should be where it was left.
///
/// Only Tempo is built so far. The other two are placeholders that hold
/// their places in the bar.
///
/// The [AppFab] writes something down on the timeline from anywhere. From a
/// tab other than Tempo it brings Tempo forward first, so the new block is on
/// screen when the sheet closes.
/// {@endtemplate}
class ShellPage extends StatefulWidget {
  /// {@macro shell_page}
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  /// Tempo, the timeline.
  static const _timelineIndex = 0;

  int _index = _timelineIndex;

  Future<void> _onFabPressed() async {
    if (_index != _timelineIndex) setState(() => _index = _timelineIndex);
    await writeDownOnTimeline(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return RemindersListener(
      child: Scaffold(
        // The bar fogs whatever runs under it, so the body runs under it.
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: [
            const HomePage(),
            _Placeholder(title: l10n.shellSecondTab),
            _Placeholder(title: l10n.shellThirdTab),
          ],
        ),
        floatingActionButton: AppFab(
          tooltip: l10n.shellWriteDown,
          onPressed: () => unawaited(_onFabPressed()),
        ),
        bottomNavigationBar: AppBottomBar(
          currentIndex: _index,
          onSelected: (index) => setState(() => _index = index),
          items: [
            AppBottomBarItem(
              iconData: AppIcons.time,
              label: l10n.shellTimelineTab,
            ),
            AppBottomBarItem(
              iconData: AppIcons.things,
              label: l10n.shellSecondTab,
            ),
            AppBottomBarItem(
              iconData: AppIcons.menu,
              label: l10n.shellThirdTab,
            ),
          ],
        ),
      ),
    );
  }
}

/// A destination that is not built yet.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppTypography.headline),
              const SizedBox(height: AppSpacing.s2),
              Text(
                context.l10n.shellComingSoon,
                style: AppTypography.body.copyWith(color: AppColors.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
