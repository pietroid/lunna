import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';

/// What the new project sheet came back with.
typedef ProjectDraft = ({String title, DateTime? deadline});

/// How long a new project is given, before anyone picks a day.
enum DeadlineChoice {
  /// No deadline at all.
  none,

  /// A week from today.
  week,

  /// A month from today.
  month,
}

/// Opens the sheet that writes a project down.
Future<ProjectDraft?> showProjectSheet(
  BuildContext context, {
  String? initialText,
  DeadlineChoice initialChoice = DeadlineChoice.none,
}) {
  return showModalBottomSheet<ProjectDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) =>
        ProjectSheet(initialText: initialText, initialChoice: initialChoice),
  );
}

/// {@template project_sheet}
/// A project in one line: its name and, if it has one, its deadline.
///
/// The same sheet as writing a task down: a bare field, one line of
/// controls, and the line that reads back what it will be. No deadline is a
/// choice like any other, and the first one.
/// {@endtemplate}
class ProjectSheet extends StatefulWidget {
  /// {@macro project_sheet}
  const ProjectSheet({
    this.initialText,
    this.initialChoice = DeadlineChoice.none,
    super.key,
  });

  /// What the field starts with.
  final String? initialText;

  /// The deadline it starts with.
  final DeadlineChoice initialChoice;

  @override
  State<ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends State<ProjectSheet> {
  late final _controller = TextEditingController(text: widget.initialText);
  late DateTime? _deadline = _dayFor(widget.initialChoice);

  /// The choice the deadline matches, or null for a day picked by hand.
  DeadlineChoice? get _choice {
    for (final choice in DeadlineChoice.values) {
      if (_dayFor(choice) == _deadline) return choice;
    }
    return null;
  }

  static DateTime? _dayFor(DeadlineChoice choice) {
    final now = clock.now();
    return switch (choice) {
      DeadlineChoice.none => null,
      DeadlineChoice.week => DateTime(now.year, now.month, now.day + 7),
      DeadlineChoice.month => DateTime(now.year, now.month + 1, now.day),
    };
  }

  Future<void> _pickDay() async {
    final now = clock.now();
    final picked = await AppWheelPicker.dayAndTime(
      context,
      initial: _deadline ?? now.add(const Duration(days: 7)),
      earliest: now,
    );
    if (picked == null) return;
    setState(() => _deadline = DateTime(picked.year, picked.month, picked.day));
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop((title: title, deadline: _deadline));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final deadline = _deadline;
    final now = clock.now();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ColoredBox(
        color: AppColors.bg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s5,
              AppSpacing.s3,
              AppSpacing.s5,
              AppSpacing.s3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _submit(),
                  cursorColor: AppColors.ink,
                  cursorWidth: 1.5,
                  style: AppTypography.body,
                  decoration: InputDecoration(
                    hintText: l10n.projectSheetHint,
                    hintStyle: AppTypography.body.copyWith(
                      color: AppColors.ink3,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s3,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                AppSegmented(
                  selected: _choice?.index ?? -1,
                  onSelected: (index) => setState(
                    () => _deadline = _dayFor(DeadlineChoice.values[index]),
                  ),
                  segments: [
                    AppSegment(label: l10n.projectNoDeadline),
                    AppSegment(label: l10n.projectWeek),
                    AppSegment(label: l10n.projectMonth),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.s2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (deadline == null)
                            Text(
                              l10n.projectSheetOpenEnded,
                              style: AppTypography.body.copyWith(
                                color: AppColors.ink3,
                              ),
                            ),
                          AppPillButton(
                            iconData: AppIcons.calendar,
                            label: deadline == null
                                ? l10n.projectPickDay
                                : l10n.projectUntil(
                                    AppWheelPicker.dayLabel(
                                      l10n,
                                      deadline,
                                      now: now,
                                    ).toLowerCase(),
                                  ),
                            onPressed: _pickDay,
                          ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        final enabled = value.text.trim().isNotEmpty;
                        return IconButton(
                          onPressed: enabled ? _submit : null,
                          icon: Opacity(
                            opacity: enabled ? 1 : 0.35,
                            child: const AppIcon(
                              iconData: AppIcons.check,
                              size: AppSpacing.s5,
                              color: AppColors.ink,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks before a project is removed. Resolves to true only on the button.
///
/// What only the project could see goes with it; what it let out onto the
/// day stays there, and the sheet says so.
Future<bool> confirmProjectDelete(BuildContext context, String title) async {
  final l10n = context.l10n;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (sheetContext) => Material(
      color: AppColors.bg,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.cardRadius),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s6,
            AppSpacing.s5,
            AppSpacing.s6,
            AppSpacing.s4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.confirmDeleteTitle(title), style: AppTypography.title),
              const SizedBox(height: AppSpacing.s1),
              Text(
                l10n.projectDeleteBody,
                style: AppTypography.body.copyWith(color: AppColors.ink2),
              ),
              const SizedBox(height: AppSpacing.s5),
              AppButton(
                text: l10n.confirmDeleteAction,
                color: AppColors.dangerInk,
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: AppSpacing.s2),
              AppButton.text(
                text: l10n.commonCancel,
                color: AppColors.ink2,
                expand: true,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return confirmed ?? false;
}
