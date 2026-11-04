import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/artifacts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timeline/timeline.dart';

/// Writes a task down: the creation sheet, Tarefa or Evento, with the
/// catalogue's kinds on its Produto chip.
///
/// A task with no product goes on the day at [placement]
/// ([writeDownOnTimeline]). One with a product is a task the deliveries
/// keep (its kind, its time and value from the kind, its own tasks to
/// come), written at the end of the queue, so it waits in Para depois.
Future<void> writeTask(
  BuildContext context, {
  Placement placement = const Placement.backlog(),
  String? initialText,
}) {
  final cubit = context.read<ArtifactsCubit>();
  final kinds = [
    for (final shelf in cubit.state.data?.catalog ?? const <CatalogCategory>[])
      ...shelf.types,
  ];

  return writeDownOnTimeline(
    context,
    placement: placement,
    initialText: initialText,
    products: [for (final kind in kinds) kind.name],
    withProduct: (result) {
      final kind = kinds.where((k) => k.name == result.product).firstOrNull;
      unawaited(
        cubit.create(
          title: result.text,
          type: kind,
          minutes: result.duration.inMinutes,
        ),
      );
    },
  );
}
