import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:chat/chat.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template things_page}
/// Coisas: what the user means to do and has not given an hour.
///
/// The timeline with the clock taken out. The orb on this tab writes a thing
/// down, a thing is dragged into order, carried off to be done or deleted,
/// and moved onto the day with its one button. Tapping one renames it or
/// changes how long it takes.
/// {@endtemplate}
class ThingsPage extends StatelessWidget {
  /// {@macro things_page}
  const ThingsPage({super.key});

  Future<void> _edit(BuildContext context, Thing thing) async {
    final bloc = context.read<ThingsBloc>();
    final result = await AppPromptSheet.show(
      context,
      initialText: thing.title,
      initialDuration: Duration(minutes: thing.durationMinutes),
    );
    if (result == null) return;

    final title = result.text == thing.title ? null : result.text;
    final minutes = result.duration.inMinutes == thing.durationMinutes
        ? null
        : result.duration.inMinutes;
    if (title == null && minutes == null) return;

    bloc.add(ThingEdited(thing.id, title: title, durationMinutes: minutes));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ThingsBloc, ThingsState>(
      listenWhen: (previous, current) =>
          previous.scheduledCount != current.scheduledCount,
      listener: (context, state) {
        // The day just gained a block, and the timeline is kept alive behind
        // the bar, so it is told rather than left to notice.
        context.read<TimelineBloc>().add(const TimelineRequested());

        final title = state.scheduled?.title;
        if (title == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('“$title” foi para o Tempo.')));
      },
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.s5,
                      bottom: AppSpacing.s2,
                    ),
                    child: Text('Coisas', style: AppTypography.headline),
                  ),
                  Expanded(
                    child: ThingsList(
                      onThingTap: (thing) => unawaited(_edit(context, thing)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
