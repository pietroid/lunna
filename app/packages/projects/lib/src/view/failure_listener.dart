import 'package:app_ui/app_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:projects/src/bloc/projects_cubit.dart';

/// {@template projects_failure_listener}
/// Says what the server refused, in its own words, at the foot of the
/// screen, once.
/// {@endtemplate}
class ProjectsFailureListener extends StatelessWidget {
  /// {@macro projects_failure_listener}
  const ProjectsFailureListener({required this.child, super.key});

  /// The screen.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProjectsCubit, ProjectsState>(
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
        context.read<ProjectsCubit>().failureShown();
      },
      child: child,
    );
  }
}
