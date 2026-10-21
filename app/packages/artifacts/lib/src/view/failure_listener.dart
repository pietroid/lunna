import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/bloc/artifacts_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// {@template artifacts_failure_listener}
/// Says what the server refused, in its own words, at the foot of the
/// screen, once.
/// {@endtemplate}
class ArtifactsFailureListener extends StatelessWidget {
  /// {@macro artifacts_failure_listener}
  const ArtifactsFailureListener({required this.child, super.key});

  /// The screen.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ArtifactsCubit, ArtifactsState>(
      listenWhen: (before, after) =>
          after.failure != null && before.failure != after.failure,
      listener: (context, state) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              state.failure?.message ?? context.l10n.failureUnreachable,
            ),
          ),
        );
        context.read<ArtifactsCubit>().failureShown();
      },
      child: child,
    );
  }
}
