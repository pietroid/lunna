import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/bloc/artifacts_cubit.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/view/artifact_page.dart';
import 'package:artifacts/src/view/value_sheet.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/timeline.dart';

/// {@template task_page}
/// A task, opened (#118): it always reads as a delivery does, its notes,
/// what is still to do of it (Pendentes) and what was done (Feitas), the
/// three tabs there from the first minute.
///
/// A loose task keeps its own summary (its hour, its length, play), and
/// its Pendentes is the home's Adicionar, which writes its first subtask.
/// That makes it a task with tasks, and the page becomes the delivery's,
/// on Pendentes. A task of a delivery opens the delivery; a fixed block
/// keeps its own page ([EventPage]).
/// {@endtemplate}
class TaskPage extends StatelessWidget {
  /// {@macro task_page}
  const TaskPage({required this.id, this.dock, this.initialTab, super.key});

  /// The card's id: a task's or an event's.
  final String id;

  /// What floats at the foot of the notes.
  final NotesDockBuilder? dock;

  /// Which tab a loose task opens on, as [ArtifactPage.initialTab]: 0 the
  /// notes (when null), 1 Pendentes, 2 Feitas.
  final int? initialTab;

  @override
  Widget build(BuildContext context) {
    final artifactId = context.select<TimelineBloc, String?>(
      (bloc) => bloc.state.byId(id)?.artifactId,
    );
    if (artifactId != null) return ArtifactPage(id: artifactId, initialTab: 1);
    return EventPage(
      id: id,
      dock: dock,
      details: _looseDetails,
      tabs: (context, card, notes) =>
          _LooseTabs(card: card, notes: notes, tab: initialTab ?? 0),
    );
  }
}

/// A delivery's three tabs over a loose task: the notes, an empty
/// Pendentes and an empty Feitas.
class _LooseTabs extends StatefulWidget {
  const _LooseTabs({
    required this.card,
    required this.notes,
    required this.tab,
  });

  final int tab;

  final TimelineEvent card;

  final Widget notes;

  @override
  State<_LooseTabs> createState() => _LooseTabsState();
}

class _LooseTabsState extends State<_LooseTabs> {
  late int _tab = widget.tab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s6,
            AppSpacing.s3,
            AppSpacing.s6,
            AppSpacing.s2,
          ),
          // As the delivery's: they shrink to fit a narrow phone.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AppSegmented(
              selected: _tab,
              onSelected: (tab) => setState(() => _tab = tab),
              segments: [
                AppSegment(
                  label: l10n.artifactNotesTab,
                  iconData: AppIcons.pen,
                ),
                AppSegment(
                  label: l10n.artifactPendingTab(0),
                  iconData: AppIcons.time,
                ),
                AppSegment(
                  label: l10n.artifactDoneTab(0),
                  iconData: AppIcons.check,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            1 => _NoSubtasks(card: widget.card),
            2 => const SizedBox.shrink(),
            _ => widget.notes,
          },
        ),
      ],
    );
  }
}

/// A loose task's Pendentes: the delivery's empty one, Para depois and the
/// home's Adicionar, with the composer's + floating where the notes' dock
/// floats.
class _NoSubtasks extends StatelessWidget {
  const _NoSubtasks({required this.card});

  final TimelineEvent card;

  /// Asks the subtask's name and length, and writes it: the first one
  /// makes the task a task with tasks.
  Future<void> _add(BuildContext context) async {
    final cubit = context.read<ArtifactsCubit>();
    final result = await AppPromptSheet.show(
      context,
      fixable: false,
      initialDuration: const Duration(minutes: 30),
    );
    final title = result?.text.trim() ?? '';
    if (result == null || title.isEmpty) return;
    await cubit.addSubtask(card.id, title, minutes: result.duration.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s5,
              0,
              AppSpacing.s5,
              kNotesDockClearance,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s1,
                  AppSpacing.s4,
                  0,
                  AppSpacing.s3,
                ),
                child: Text(
                  context.l10n.stageBacklog,
                  style: AppTypography.title,
                ),
              ),
              AppAddRow(onTap: () => unawaited(_add(context))),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: kFloatingActionButtonMargin,
          child: Center(child: AskDock(about: AgentSubject.task(card.id))),
        ),
      ],
    );
  }
}

/// A loose task's Data, Tipo and Valor, as a delivery's page draws them
/// with none set (#126): a task and a delivery are one thing, so setting
/// either makes a delivery of the task, and the page becomes the delivery's.
List<(String, Widget)> _looseDetails(BuildContext context, TimelineEvent card) {
  final l10n = context.l10n;
  return [
    (
      l10n.artifactDeadlineLabel,
      _Add(
        text: l10n.artifactGiveDeadline,
        onTap: () => unawaited(_pickDeadline(context, card.id)),
      ),
    ),
    (
      l10n.artifactKindLabel,
      Text(
        [
          l10n.artifactLoose,
          if (card.workMinutes > 0) formatMinutes(l10n, card.workMinutes),
        ].join(' · '),
        style: AppTypography.labelStrong.copyWith(color: AppColors.ink),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    (
      l10n.artifactValue,
      _Add(
        text: l10n.artifactValueAdd,
        onTap: () => unawaited(showTaskValueSheet(context, card.id)),
      ),
    ),
  ];
}

Future<void> _pickDeadline(BuildContext context, String taskId) async {
  final cubit = context.read<ArtifactsCubit>();
  final now = clock.now();
  final picked = await AppWheelPicker.dayAndTime(
    context,
    initial: now.add(const Duration(days: 7)),
    earliest: now,
  );
  if (picked == null) return;

  await cubit.setTaskDeadline(
    taskId,
    DateTime(picked.year, picked.month, picked.day),
  );
}

/// A field not set yet, in the accent, a tap from its picker.
class _Add extends StatelessWidget {
  const _Add({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
          child: Text(
            text,
            style: AppTypography.labelStrong.copyWith(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}
