import 'package:app_ui/app_ui.dart';
import 'package:chat/chat.dart';
import 'package:go_router/go_router.dart';

/// {@template solved_page}
/// The solved threads, reached from the menu.
///
/// A screen of its own rather than a fourth list on the timeline: the
/// timeline is what is still ahead, and a list of what is behind would make
/// it longer every day without ever making it more useful.
/// {@endtemplate}
class SolvedPage extends StatelessWidget {
  /// {@macro solved_page}
  const SolvedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          iconData: AppIcons.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Itens concluídos'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: SolvedSection(
              onThreadTap: (slug) => context.push<void>('/chat/$slug'),
            ),
          ),
        ),
      ),
    );
  }
}
