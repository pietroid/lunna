import 'package:app_ui/app_ui.dart';
import 'package:chat/src/data/chat_repository.dart';
import 'package:chat/src/models/models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template solved_section}
/// Everything that has been solved.
///
/// It reads its own list rather than sharing the timeline's. The timeline is
/// what is still ahead, and since a solved thread leaves it entirely there is
/// nothing left there to filter: these are a different set of threads, so
/// they come from a different request.
///
/// A thread solved by mistake is one tap from coming back, because a gesture
/// that removes something from the only screen that shows it has to be as
/// easy to undo as it was to do.
/// {@endtemplate}
class SolvedSection extends StatefulWidget {
  /// {@macro solved_section}
  const SolvedSection({required this.onThreadTap, super.key});

  /// Called with a thread's slug when its row is tapped.
  final ValueChanged<String> onThreadTap;

  @override
  State<SolvedSection> createState() => _SolvedSectionState();
}

class _SolvedSectionState extends State<SolvedSection> {
  late Future<List<ThreadItem>> _items = _load();

  Future<List<ThreadItem>> _load() =>
      context.read<ChatRepository>().fetchSolved();

  Future<void> _recover(String slug) async {
    await context.read<ChatRepository>().setSolved(slug, solved: false);
    if (mounted) setState(() => _items = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ThreadItem>>(
      future: _items,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null) return const _Loading();
        if (items.isEmpty) return const _Empty();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s6,
            AppSpacing.s2,
            AppSpacing.s6,
            // Room under the last row so the bar never covers it.
            AppSpacing.s16 + AppSpacing.s12,
          ),
          itemCount: items.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.s1),
          itemBuilder: (context, index) => _Row(
            item: items[index],
            onTap: () => widget.onThreadTap(items[index].slug),
            onRecover: () => _recover(items[index].slug),
          ),
        );
      },
    );
  }
}

/// One solved thread: the row, and the way back out of here.
class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.onTap,
    required this.onRecover,
  });

  final ThreadItem item;
  final VoidCallback onTap;
  final VoidCallback onRecover;

  @override
  Widget build(BuildContext context) {
    final start = item.startTime;

    return Row(
      children: [
        Expanded(
          child: Material(
            color: AppColors.fill,
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4,
                  vertical: AppSpacing.s3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppTypography.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (start != null) ...[
                      const SizedBox(width: AppSpacing.s3),
                      Text(
                        _hhmm(start),
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        AppIconButton(
          iconData: AppIcons.undo,
          onPressed: onRecover,
          size: AppSpacing.s5,
          color: AppColors.ink2,
        ),
      ],
    );
  }

  static String _hhmm(DateTime at) {
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.s6),
      child: Column(
        children: [
          AppSkeleton(height: AppSpacing.s12, radius: AppSpacing.chipRadius),
          SizedBox(height: AppSpacing.s1),
          AppSkeleton(height: AppSpacing.s12, radius: AppSpacing.chipRadius),
        ],
      ),
    );
  }
}

/// What the screen says before anything has been solved.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
      child: Text(
        'Nada concluído ainda. Arraste um item para o lado para concluí-lo.',
        style: AppTypography.body.copyWith(color: AppColors.ink3),
      ),
    );
  }
}
