import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// One task as the home draws it: what [TaskCard] reads.
class TaskView {
  /// A task for a [TaskCard].
  const TaskView({
    required this.title,
    this.subtitle,
    this.trailing,
    this.status,
    this.statusInk,
    this.bar,
    this.playing = false,
  });

  /// The task's name.
  final String title;

  /// Its task at work, or what it is of.
  final String? subtitle;

  /// Its hours or its length.
  final String? trailing;

  /// Where it stands.
  final String? status;

  /// [status]'s colour when it warns.
  final Color? statusInk;

  /// Its bar.
  final TaskBar? bar;

  /// Whether it runs.
  final bool playing;
}

/// What the home shows: the day's mark, Agora and the one after it,
/// Pendentes and the first of Para depois.
class HomeData {
  /// The home's content.
  const HomeData({
    this.mark,
    this.now,
    this.next,
    this.pending = const [],
    this.later = const [],
    this.laterMore = 0,
  });

  /// What today is beyond its hours (the cycle, a day off).
  final DayMark? mark;

  /// The running task, or none (the break).
  final TaskView? now;

  /// The first card after Agora.
  final TaskView? next;

  /// The tasks begun and not finished, Agora's left out.
  final List<TaskView> pending;

  /// The first four of the queue not begun.
  final List<TaskView> later;

  /// How many more the queue holds after [later].
  final int laterMore;
}

/// {@template home_page}
/// Plano: what to do now, what is under way, and what comes later.
///
/// No greeting and no clock. From the top: the agent's one offer, as it
/// was; **Agora**, with the day's mark beside its heading (the cycle, a
/// light day, a day off) and *Ver o dia*, which opens the calendar on a
/// page of its own, the running task and the one after it; **Pendentes**,
/// every task begun and not finished, drawn as Agora is, with −10, +10
/// and ✓ and its bar under it; **Para depois**, the first four of the
/// queue, and a row that opens the whole of it.
///
/// Every task has its play button on the left, which is letting it go on
/// Agora.
/// {@endtemplate}
class HomePage extends StatelessWidget {
  /// {@macro home_page}
  const HomePage({
    required this.data,
    this.onSeeDay,
    this.onOpenLater,
    this.controller,
    super.key,
  });

  /// What to draw.
  final HomeData data;

  /// Opens the calendar.
  final VoidCallback? onSeeDay;

  /// Opens Para depois whole.
  final VoidCallback? onOpenLater;

  /// The scroll of the page.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = data.now;
    final next = data.next;

    return SafeArea(
      bottom: false,
      child: ListView(
        controller: controller,
        padding: EdgeInsets.only(
          top: AppSpacing.s3,
          bottom: MediaQuery.paddingOf(context).bottom + kNotesDockClearance,
        ),
        children: [
          const SuggestionCard(),
          _Heading(
            title: l10n.feedNow,
            mark: data.mark,
            action: AppPillButton(
              label: l10n.feedSeeDay,
              iconData: AppIcons.calendar,
              onPressed: onSeeDay ?? () {},
            ),
          ),
          _Pad(
            child: now == null
                ? _Quiet(text: l10n.feedBreak)
                : _card(now, now: true, controls: true),
          ),
          if (next != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s6,
                AppSpacing.s4,
                AppSpacing.s6,
                AppSpacing.s2,
              ),
              child: Text(l10n.feedNext, style: AppTypography.caption),
            ),
            _Pad(child: _card(next)),
          ],
          if (data.pending.isNotEmpty) ...[
            _Heading(title: l10n.homePending),
            for (final task in data.pending)
              _Pad(child: _card(task, controls: true)),
          ],
          _Heading(title: l10n.stageBacklog),
          for (final task in data.later) _Pad(child: _card(task)),
          _Pad(
            child: _OpenRow(
              text: l10n.homeLaterOpen(data.laterMore),
              onTap: onOpenLater,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _card(
    TaskView task, {
    bool now = false,
    bool controls = false,
  }) => TaskCard(
    title: task.title,
    subtitle: task.subtitle,
    trailing: task.trailing,
    now: now,
    playing: task.playing,
    onPlay: () {},
    status: task.status,
    statusInk: task.statusInk,
    controls: controls,
    bar: task.bar,
    onTap: () {},
  );
}

/// A card's room in the column: the page's margin, and a gap under it.
class _Pad extends StatelessWidget {
  const _Pad({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s5,
        0,
        AppSpacing.s5,
        AppSpacing.s2,
      ),
      child: child,
    );
  }
}

/// A section's name; Agora's carries the day's mark beside it and the way
/// to the calendar.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.mark, this.action});

  final String title;
  final DayMark? mark;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s5,
        action == null ? AppSpacing.s6 : AppSpacing.s4,
        AppSpacing.s3,
      ),
      child: Row(
        children: [
          Text(title, style: AppTypography.title),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: mark == null ? null : TodayTag(mark: mark),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// {@template today_tag}
/// What today is beyond its hours, as one tag: the day of the cycle and
/// what the day is ("Dia 2 · dia leve"), or its phase on a working day;
/// without a cycle, the day's own tag ("Folga"); on a plain working day,
/// nothing.
/// {@endtemplate}
class TodayTag extends StatelessWidget {
  /// {@macro today_tag}
  const TodayTag({required this.mark, super.key});

  /// Today's mark.
  final DayMark? mark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mark = this.mark;
    final day = mark?.cycleDay;
    final phase = mark?.phase;
    if (mark != null && day != null && phase != null) {
      return AppTag(
        text: l10n.homeCycleTag(day, switch (mark.kind) {
          DayKind.light => l10n.dayLightShort,
          DayKind.off => l10n.dayOffShort,
          DayKind.work => phase.label(l10n),
        }),
        iconData: phase.icon,
        fill: phase.fill,
        ink: phase.ink,
      );
    }
    if (mark != null && mark.restricted) return DayMarkTag(mark: mark);
    return const SizedBox.shrink();
  }
}

/// The row under Para depois's four that opens the whole queue.
class _OpenRow extends StatelessWidget {
  const _OpenRow({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: AppTypography.labelStrong.copyWith(
                  color: AppColors.ink2,
                ),
              ),
            ),
            const AppIcon(
              iconData: AppIcons.chevronRight,
              size: AppSpacing.s4,
              color: AppColors.ink3,
            ),
          ],
        ),
      ),
    );
  }
}

/// A section with nothing in it, said in a line.
class _Quiet extends StatelessWidget {
  const _Quiet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(text, style: AppTypography.label),
    );
  }
}
