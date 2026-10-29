import 'package:agent/src/surface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template agent_links}
/// What an answer opens in the app around the agent: the pages this package
/// cannot import (artifacts depends on agent, not the other way round).
///
/// The app shell provides one; without it, nothing in an answer opens.
/// {@endtemplate}
class AgentLinks {
  /// {@macro agent_links}
  const AgentLinks({this.openArtifact, this.preview});

  /// The links above [context], or none.
  factory AgentLinks.of(BuildContext context) {
    try {
      return context.read<AgentLinks>();
    } on ProviderNotFoundException {
      return const AgentLinks();
    }
  }

  /// Opens the page of the artifact with this id.
  final void Function(String id)? openArtifact;

  /// Draws a [PreviewItem] with the widget of the tab it lands on (a goal
  /// as `GoalCard`, a delivery as `ArtifactRow`); null for one it does not
  /// draw, which the agent then draws itself.
  final Widget? Function(BuildContext context, PreviewItem item)? preview;
}
