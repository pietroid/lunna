import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/bloc/artifacts_cubit.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/sheet_frame.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// Opens the sheet that gives [artifact] its value.
///
/// The sheet is its own route, so it is handed the cubit it writes with.
Future<void> showValueSheet(BuildContext context, Artifact artifact) =>
    _showValueSheet(
      context,
      artifact.value,
      (cubit, value) => cubit.setValue(artifact.id, value),
    );

/// Opens the same sheet over a loose task: a value makes it a delivery.
Future<void> showTaskValueSheet(BuildContext context, String taskId) =>
    _showValueSheet(
      context,
      null,
      (cubit, value) => cubit.setTaskValue(taskId, value),
    );

Future<void> _showValueSheet(
  BuildContext context,
  int? value,
  Future<void> Function(ArtifactsCubit cubit, int? value) save,
) {
  final cubit = context.read<ArtifactsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: ValueSheet(value: value, save: save),
    ),
  );
}

/// {@template value_sheet}
/// What a delivery is worth, in whole reais: the money a goal counts once
/// it is delivered. One field, Salvar, and, when it has one, a way to take
/// it away.
/// {@endtemplate}
class ValueSheet extends StatefulWidget {
  /// {@macro value_sheet}
  const ValueSheet({required this.value, required this.save, super.key});

  /// What it is worth now, if anything.
  final int? value;

  /// Writes the value (null takes it away).
  final Future<void> Function(ArtifactsCubit cubit, int? value) save;

  @override
  State<ValueSheet> createState() => _ValueSheetState();
}

class _ValueSheetState extends State<ValueSheet> {
  late final _amount = TextEditingController(
    text: widget.value?.toString(),
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save(int? value) {
    unawaited(
      widget.save(context.read<ArtifactsCubit>(), value),
    );
    unawaited(Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = int.tryParse(_amount.text.trim()) ?? 0;

    return SheetFrame(
      title: l10n.artifactValue,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTypography.headline,
            cursorColor: AppColors.ink,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => value > 0 ? _save(value) : null,
            decoration: InputDecoration(
              hintText: '350',
              hintStyle: AppTypography.headline.copyWith(color: AppColors.ink3),
              prefixText: r'R$ ',
              prefixStyle: AppTypography.headline,
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
          Text(
            l10n.artifactValueHint,
            style: AppTypography.label.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(height: AppSpacing.s5),
          AppButton(
            text: l10n.commonSave,
            expand: true,
            onPressed: value > 0 ? () => _save(value) : null,
          ),
          if (widget.value != null) ...[
            const SizedBox(height: AppSpacing.s2),
            AppButton(
              text: l10n.artifactValueClear,
              variant: AppButtonVariant.tertiary,
              expand: true,
              onPressed: () => _save(null),
            ),
          ],
        ],
      ),
    );
  }
}
