import 'package:app_ui/app_ui.dart';

/// {@template app_title_tabs}
/// A screen's heading that is also its tabs: a few words side by side, the
/// one in front in ink and the others quiet.
///
/// It picks what a screen is about (Tarefas, Entregas, Objetivos), which is
/// a level above how a list is drawn ([AppSegmented]: Lista or Calendário).
/// So it is set as a heading, not as a control, and the two never look
/// alike when one sits over the other. Nothing here is coloured.
///
/// The words scroll sideways when the screen is too narrow for them, and
/// [trailing] (a search, say) keeps the end of the line.
/// {@endtemplate}
class AppTitleTabs extends StatelessWidget {
  /// {@macro app_title_tabs}
  const AppTitleTabs({
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.trailing,
    super.key,
  });

  /// The words, in order.
  final List<String> labels;

  /// Which one is in front.
  final int selected;

  /// Called with the index of the word that was tapped.
  final ValueChanged<int> onSelected;

  /// Drawn at the end of the line, for what belongs to the tab in front.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < labels.length; index++)
                  _Word(
                    label: labels[index],
                    isSelected: index == selected,
                    onTap: () => onSelected(index),
                  ),
              ],
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The room between one word and the next.
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s3),
      child: Semantics(
        selected: isSelected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s1,
              vertical: AppSpacing.s2,
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              style: AppTypography.title.copyWith(
                color: isSelected ? AppColors.ink : AppColors.ink3,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
