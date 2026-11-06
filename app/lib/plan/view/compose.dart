import 'dart:async';

import 'package:agent/agent.dart';
import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:lunna/plan/view/write_task.dart';
import 'package:timeline/timeline.dart';

/// How long a task is when the words said nothing of it.
const kComposeTaskMinutes = 30;

/// How long an event is when the words said nothing of it.
const kComposeEventMinutes = 60;

/// Opens the composer (#81): one field, typed or spoken, read once into a
/// summary, and nothing written until Adicionar.
///
/// What the summary says is written through the routes the old sheet
/// used, so the time rules hold: a task on the day (in Para depois, or at
/// its hour), a task under a delivery, a task with subtasks as a delivery
/// with its tasks, an event at its hour, a goal. A plan is the agent's
/// turn, applied whole with its undo on the day ([UndoChip]). *Ajustar*
/// opens the old sheet filled with what was read; *Conversar* opens the
/// conversation with the words in its field. [about] is the page it was
/// opened on (a task's, a delivery's): the read knows it.
Future<void> openComposer(BuildContext context, {AgentSubject? about}) async {
  final repository = context.read<AgentRepository>();
  final cubit = ComposeCubit(
    read: (text) => repository.compose(text, about: about),
  );
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;

  void close() => navigator.pop();

  try {
    await showComposer(
      context,
      cubit: cubit,
      voice: context.read<VoiceCubit>(),
      onAdd: (draft) {
        close();
        unawaited(writeDraft(context, draft));
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.composeAdded)));
      },
      onAdjust: (draft) {
        close();
        final start = draft.start;
        unawaited(
          writeTask(
            context,
            initialText: draft.title,
            placement: start == null
                ? const Placement.backlog()
                : Placement.at(start, minutes: draft.minutes),
          ),
        );
      },
      onTalk: (draft) {
        final text = cubit.state.text.trim();
        close();
        unawaited(
          showAgentSheet(
            context,
            about: about,
            seed: [UserEntry(text), ComposedEntry(draft)],
          ),
        );
      },
    );
  } finally {
    await cubit.close();
  }
}

/// Writes down what [draft] says, through the day's own routes.
Future<void> writeDraft(BuildContext context, ComposeDraft draft) async {
  final timeline = context.read<TimelineBloc>();
  final artifacts = context.read<ArtifactsCubit>();
  final start = draft.start;

  switch (draft.kind) {
    case ComposeKind.event:
      if (start == null) return;
      timeline.add(
        EventCreated(
          title: draft.title,
          durationMinutes: draft.minutes ?? kComposeEventMinutes,
          fixed: true,
          startTime: start,
        ),
      );

    case ComposeKind.task when draft.subtasks.isNotEmpty:
      final said = [
        for (final it in draft.subtasks) ?it.minutes,
      ].fold(0, (sum, it) => sum + it);
      final minutes =
          draft.minutes ??
          (said > 0 ? said : kComposeTaskMinutes * draft.subtasks.length);
      await artifacts.createWithTasks(
        title: draft.title,
        minutes: minutes,
        tasks: [
          for (final it in draft.subtasks)
            (title: it.title, minutes: it.minutes),
        ],
      );

    case ComposeKind.task:
      timeline.add(
        EventCreated(
          title: draft.title,
          durationMinutes: draft.minutes ?? kComposeTaskMinutes,
          fixed: false,
          startTime: start,
          artifactId: draft.parentId,
        ),
      );

    case ComposeKind.goal:
      final value = draft.value;
      final due = draft.due;
      if (value == null || due == null) return;
      await artifacts.addGoal(target: value, deadline: due);

    case ComposeKind.plan:
      final planId = draft.planId;
      if (planId == null) return;
      try {
        final day = await context.read<AgentRepository>().apply(
          planId,
          days: timeline.state.days,
        );
        timeline.add(TimelineReplaced(day, undoable: planId));
      } on AgentFailure {
        // The summary said what it would do; a failed apply leaves the day
        // as it was, and the snackbar of the day's own failure says so.
      }
  }
}
