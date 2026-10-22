import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/demo/data/demo_agent.dart';
import 'package:lunna/demo/data/demo_artifacts.dart';
import 'package:lunna/demo/demo.dart';

/// The icon, the name and the one line of each chapter.
extension DemoChapterCopy on DemoChapter {
  AppIconData get icon => switch (this) {
    DemoChapter.ask => AppIcons.agent,
    DemoChapter.time => AppIcons.time,
    DemoChapter.deliveries => AppIcons.artifacts,
  };

  String title(AppLocalizations l10n) => switch (this) {
    DemoChapter.ask => l10n.landingChapterAskTitle,
    DemoChapter.time => l10n.landingChapterTimeTitle,
    DemoChapter.deliveries => l10n.landingChapterDeliveriesTitle,
  };

  String text(AppLocalizations l10n) => switch (this) {
    DemoChapter.ask => l10n.landingChapterAskText(AppBrand.id),
    DemoChapter.time => l10n.landingChapterTimeText,
    DemoChapter.deliveries => l10n.landingChapterDeliveriesText,
  };
}

/// {@template chapter_list}
/// The three things the app does, beside the phone, one under the other:
/// the one chosen is what the phone shows.
///
/// They are the tabs of the phone said in words. Choosing one changes the
/// phone, and a tab tapped in the phone changes the choice here. Under Peça
/// are the example asks, each sent to the phone's agent as if typed there.
/// {@endtemplate}
class ChapterList extends StatelessWidget {
  /// {@macro chapter_list}
  const ChapterList({required this.controller, super.key});

  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final chapter in DemoChapter.values)
            _ChapterTile(
              chapter: chapter,
              selected: controller.chapter == chapter,
              onTap: () => controller.show(chapter),
              footer: chapter == DemoChapter.ask
                  ? _Asks(onAsk: controller.ask)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.chapter,
    required this.selected,
    required this.onTap,
    this.footer,
  });

  final DemoChapter chapter;
  final bool selected;
  final VoidCallback onTap;

  /// Drawn under the line while the chapter is chosen.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ink = selected ? AppColors.ink : AppColors.ink3;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Material(
        color: selected ? AppColors.fill : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(
                  iconData: chapter.icon,
                  color: selected ? AppColors.accent : AppColors.ink3,
                ),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title(l10n),
                        style: AppTypography.title.copyWith(color: ink),
                      ),
                      // Only the chosen one says what it is: the others are
                      // a name to tap.
                      if (selected) ...[
                        const SizedBox(height: AppSpacing.s1),
                        Text(
                          chapter.text(l10n),
                          style: AppTypography.label.copyWith(height: 1.6),
                        ),
                        if (footer case final footer?) ...[
                          const SizedBox(height: AppSpacing.s4),
                          footer,
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The example asks, each a pill that asks the phone's agent.
class _Asks extends StatelessWidget {
  const _Asks({required this.onAsk});

  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.landingTry,
          style: AppTypography.caption.copyWith(color: AppColors.ink3),
        ),
        const SizedBox(height: AppSpacing.s2),
        for (final ask in DemoAgentRepository.asks(l10n))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s2),
            child: _AskPill(text: ask, onTap: () => onAsk(ask)),
          ),
      ],
    );
  }
}

class _AskPill extends StatelessWidget {
  const _AskPill({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  style: AppTypography.label.copyWith(color: AppColors.ink),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              const AppIcon(
                iconData: AppIcons.arrowUp,
                size: AppSpacing.s4,
                color: AppColors.ink3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// {@template chapter_pieces}
/// The three chapters on a narrow screen, where there is no phone: each one
/// with the piece of the app it is about, drawn by the app's own widgets.
///
/// Peça shows what was asked and the plan that came back, which can be
/// applied right here; Entregas shows the month's goal and the next
/// deliveries. Tempo is the one a phone already knows, and is said in words.
/// {@endtemplate}
class ChapterPieces extends StatelessWidget {
  /// {@macro chapter_pieces}
  const ChapterPieces({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final chapter in DemoChapter.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AppIcon(
                      iconData: chapter.icon,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Text(chapter.title(l10n), style: AppTypography.title),
                  ],
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  chapter.text(l10n),
                  style: AppTypography.label.copyWith(height: 1.65),
                ),
                switch (chapter) {
                  DemoChapter.ask => const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.s5),
                    child: _AskPiece(),
                  ),
                  DemoChapter.deliveries => const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.s5),
                    child: _DeliveriesPiece(),
                  ),
                  DemoChapter.time => const SizedBox.shrink(),
                },
              ],
            ),
          ),
      ],
    );
  }
}

/// The first example ask, and the plan it gets.
class _AskPiece extends StatefulWidget {
  const _AskPiece();

  @override
  State<_AskPiece> createState() => _AskPieceState();
}

class _AskPieceState extends State<_AskPiece> {
  PlanStatus _status = PlanStatus.pending;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ask = DemoAgentRepository.asks(l10n).first;
    final reply = demoReply(l10n, ask);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // What was asked, as the sheet draws it: on the right, in a fill.
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4,
                  vertical: AppSpacing.s3,
                ),
                child: Text(ask, style: AppTypography.body),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(reply.text, style: AppTypography.body),
        const SizedBox(height: AppSpacing.s3),
        PlanCard(
          plan: reply.plan!,
          status: _status,
          // Applied here it only says so: the day it would change is the
          // one the person has once signed in.
          onApply: () => setState(() => _status = PlanStatus.applied),
          onAdjust: () {},
        ),
      ],
    );
  }
}

/// The month's goal and the two next deliveries.
class _DeliveriesPiece extends StatelessWidget {
  const _DeliveriesPiece();

  @override
  Widget build(BuildContext context) {
    final data = demoArtifacts(context.l10n);
    final now = clock.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GoalCard(goal: data.goals.first, now: now),
        const SizedBox(height: AppSpacing.s3),
        for (final artifact in data.queue.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s2),
            child: ArtifactRow(artifact: artifact, now: now),
          ),
      ],
    );
  }
}
