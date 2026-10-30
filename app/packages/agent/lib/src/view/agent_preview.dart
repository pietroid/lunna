import 'package:agent/src/agent_links.dart';
import 'package:agent/src/surface.dart';
import 'package:app_ui/app_ui.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// {@template agent_preview}
/// What a plan would make, drawn as the tabs will draw it once it is
/// applied, on the page's own background: never inside the agent's wash,
/// so a goal or a delivery keeps the contrast it has on its tab.
///
/// Goals and deliveries are drawn by the app ([AgentLinks.preview]), since
/// their widgets live in a package that depends on this one; a routine is
/// drawn here as Rotina draws its block.
/// {@endtemplate}
class AgentPreview extends StatelessWidget {
  /// {@macro agent_preview}
  const AgentPreview({required this.block, super.key});

  final PreviewBlock block;

  @override
  Widget build(BuildContext context) {
    final draw = AgentLinks.of(context).preview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in block.items.indexed) ...[
          if (i > 0)
            SizedBox(
              height: item is GoalPreview || block.items[i - 1] is GoalPreview
                  ? AppSpacing.s4
                  : AppSpacing.s2,
            ),
          draw?.call(context, item) ?? _Fallback(item: item),
        ],
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.item});

  final PreviewItem item;

  @override
  Widget build(BuildContext context) => switch (item) {
    final RoutinePreview routine => RoutinePreviewRow(routine: routine),
    // Where no tab draws them (a test, a page with no links), a line each.
    GoalPreview(:final target) => Text(
      context.l10n.agentWelcomeAmount(target),
      style: AppTypography.bodyStrong,
    ),
    ArtifactPreview(:final title) => Text(title, style: AppTypography.body),
  };
}

/// {@template routine_preview_row}
/// A routine the plan would write, as Rotina's day draws its block (the
/// routine's fill, its name, its hour), with the days it repeats on and
/// its checklist under it.
/// {@endtemplate}
class RoutinePreviewRow extends StatelessWidget {
  /// {@macro routine_preview_row}
  const RoutinePreviewRow({required this.routine, super.key});

  final RoutinePreview routine;

  static String _hour(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final quiet = AppTypography.label.copyWith(color: AppColors.routineInk);
    final checklist = routine.checklist;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: AppColors.routineFill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  routine.title,
                  style: AppTypography.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                '${_hour(routine.startMinute)}–'
                '${_hour(routine.startMinute + routine.minutes)}',
                style: quiet,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              l10n.routineDaysLabel(routine.days),
              if (checklist.isNotEmpty)
                l10n.agentPreviewItems(checklist.length),
            ].join(' · '),
            style: quiet,
          ),
          if (checklist.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            for (final item in checklist)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s1),
                child: Row(
                  children: [
                    // The empty box the day's copy will tick.
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.routineInk,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(child: Text(item, style: AppTypography.label)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
