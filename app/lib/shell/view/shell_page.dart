import 'package:app_ui/app_ui.dart';
import 'package:chat/chat.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/conversations/conversations.dart';
import 'package:focus/home/home.dart';
import 'package:focus/menu/menu.dart';
import 'package:focus/notifications/notifications.dart';
import 'package:focus/things/things.dart';
import 'package:go_router/go_router.dart';

/// {@template shell_page}
/// The four destinations of the app, and the orb that starts something new.
///
/// The destinations are kept alive behind an [IndexedStack] rather than
/// rebuilt on every tap: moving between them is not navigation, it is looking
/// somewhere else, and a list should be where it was left.
///
/// The orb is the app's one action from anywhere, and it does the thing the
/// screen under it is about. On Tempo that is writing something down with an
/// hour on it, and on Coisas writing something down without one; neither
/// involves the model. On Conversas, and everywhere else, it is starting a
/// conversation. The tab bar underneath already says which one is live.
/// {@endtemplate}
class ShellPage extends StatefulWidget {
  /// {@macro shell_page}
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  /// Tempo, where the orb writes something straight onto the timeline.
  static const _timelineIndex = 0;

  /// Coisas, where the orb writes down something with no hour.
  static const _thingsIndex = 1;

  int _index = 0;

  /// How many conversations have been started from the orb.
  ///
  /// Conversas is kept alive behind the bar, so it cannot notice a thread that
  /// appeared while it was off screen. This is how it is told.
  int _conversations = 0;

  Future<void> _onOrbTapped() async {
    if (_index == _timelineIndex) {
      await _schedule();
      return;
    }

    if (_index == _thingsIndex) {
      await _note();
      return;
    }

    await _converse();
  }

  /// Writes a thing down on Coisas: what it is and how long, no hour.
  Future<void> _note() async {
    final bloc = context.read<ThingsBloc>();
    final result = await AppPromptSheet.show(context);
    if (result == null) return;

    bloc.add(
      ThingAdded(
        title: result.text,
        durationMinutes: result.duration.inMinutes,
      ),
    );
  }

  /// Writes something down with an hour on it. No conversation.
  Future<void> _schedule() => writeDownOnTimeline(context);

  /// Opens a new thread on whatever the user typed.
  Future<void> _converse() async {
    final text = await AppTextPromptSheet.show(context);
    if (text == null || !mounted) return;

    await context.push<void>('/chat', extra: text);
    if (mounted) {
      context.read<TimelineBloc>().add(const TimelineRequested());
      setState(() => _conversations++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RemindersListener(
      child: Scaffold(
        // The bar fogs whatever runs under it, so the body runs under it.
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: [
            const HomePage(),
            const ThingsPage(),
            ConversationsPage(reloadToken: _conversations),
            const MenuPage(),
          ],
        ),
        bottomNavigationBar: AppBottomBar(
          currentIndex: _index,
          onSelected: (index) => setState(() => _index = index),
          center: AppOrb(onTap: _onOrbTapped),
          items: const [
            AppBottomBarItem(iconData: AppIcons.time, label: 'Tempo'),
            AppBottomBarItem(iconData: AppIcons.things, label: 'Coisas'),
            AppBottomBarItem(
              iconData: AppIcons.conversations,
              label: 'Conversas',
            ),
            AppBottomBarItem(iconData: AppIcons.menu, label: 'Menu'),
          ],
        ),
      ),
    );
  }
}
