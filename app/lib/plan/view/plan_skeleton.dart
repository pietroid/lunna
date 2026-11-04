import 'package:app_ui/app_ui.dart';
import 'package:timeline/timeline.dart';

/// {@template plan_skeleton_card}
/// Where a card of Plano will be while the day is on its way: a card's
/// fill, the play's round room, a line for the name and one for the hours,
/// pulsing ([AppSkeleton]). [tall] is Agora's, with its controls' line.
/// {@endtemplate}
class PlanSkeletonCard extends StatelessWidget {
  /// {@macro plan_skeleton_card}
  const PlanSkeletonCard({this.title = 0.55, this.tall = false, super.key});

  /// How much of the line the name takes.
  final double title;

  /// Whether it is Agora's card, a line taller.
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s3,
        AppSpacing.s3,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppSkeleton(
                width: TaskPlayButton.size,
                height: TaskPlayButton.size,
                radius: TaskPlayButton.size / 2,
                onFill: true,
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: title,
                  child: const AppSkeleton(height: 14, onFill: true),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              const AppSkeleton(width: 72, height: 12, onFill: true),
            ],
          ),
          if (tall) ...[
            const SizedBox(height: AppSpacing.s3),
            const Row(
              children: [
                AppSkeleton(width: 96, height: 12, onFill: true),
                Spacer(),
                AppSkeleton(width: 108, height: 24, onFill: true),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            const AppSkeleton(height: 3, radius: 2, onFill: true),
          ],
        ],
      ),
    );
  }
}
