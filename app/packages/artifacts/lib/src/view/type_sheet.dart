import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/bloc/artifacts_cubit.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/view/sheet_frame.dart';
import 'package:artifacts/src/view/sheet_rows.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// Opens the sheet that writes a kind down in the catalogue.
///
/// The sheet is its own route, so it is handed the cubit it writes with.
Future<void> showTypeSheet(BuildContext context) {
  final cubit = context.read<ArtifactsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) => BlocProvider.value(value: cubit, child: const TypeSheet()),
  );
}

/// {@template type_sheet}
/// The least that fills the catalogue: a kind's name, its shelf, how long
/// one takes, what it is worth and how the day may cut it.
///
/// The shelf is one she has, or a new one named here, which is how the
/// first kind makes the first shelf. Editing and ordering the catalogue
/// belong to its own page, later.
/// {@endtemplate}
class TypeSheet extends StatefulWidget {
  /// {@macro type_sheet}
  const TypeSheet({super.key});

  @override
  State<TypeSheet> createState() => _TypeSheetState();
}

class _TypeSheetState extends State<TypeSheet> {
  static const _block = 60;

  final _name = TextEditingController();
  final _newCategory = TextEditingController();
  final _price = TextEditingController();

  /// The shelf picked, by its place in the catalogue; null is a new one.
  int? _category = 0;
  int _minutes = 60;
  bool _split = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _newCategory.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickMinutes() async {
    final picked = await AppWheelPicker.duration(
      context,
      initial: Duration(minutes: _minutes),
    );
    if (picked == null || picked.inMinutes <= 0 || !mounted) return;
    setState(() => _minutes = picked.inMinutes);
  }

  Future<void> _save(String? categoryId) async {
    final cubit = context.read<ArtifactsCubit>();
    setState(() => _busy = true);
    final made = await cubit.addType(
      name: _name.text.trim(),
      minutes: _minutes,
      price: int.tryParse(_price.text.trim()),
      blockMinutes: _split ? _block : null,
      categoryId: categoryId,
      category: categoryId == null ? _newCategory.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (made) unawaited(Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = context.watch<ArtifactsCubit>().state.catalog;
    final picked = categories.isEmpty ? null : _category;
    final categoryId = picked == null ? null : categories[picked].id;
    final ready =
        _name.text.trim().isNotEmpty &&
        (categoryId != null || _newCategory.text.trim().isNotEmpty) &&
        !_busy;

    return SheetFrame(
      title: l10n.catalogAddType,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: AppColors.ink,
            cursorWidth: 1.5,
            style: AppTypography.title,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration.collapsed(
              hintText: l10n.typeNameHint,
              hintStyle: AppTypography.title.copyWith(color: AppColors.ink3),
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          Text(l10n.typeCategory, style: AppTypography.label),
          const SizedBox(height: AppSpacing.s2),
          if (categories.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: AppSegmented(
                selected: picked ?? categories.length,
                onSelected: (index) => setState(
                  () => _category = index < categories.length ? index : null,
                ),
                segments: [
                  for (final category in categories)
                    AppSegment(
                      label: category.name,
                      iconData: AppIcons.category,
                    ),
                  AppSegment(
                    label: l10n.typeNewCategory,
                    iconData: AppIcons.plus,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
          if (picked == null)
            AppTextField(
              controller: _newCategory,
              hintText: l10n.typeCategoryHint,
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: AppSpacing.s4),
          SheetGroup(
            children: [
              SheetRow(
                iconData: AppIcons.timer,
                label: l10n.artifactTotalTime,
                value: formatMinutes(l10n, _minutes),
                onTap: () => unawaited(_pickMinutes()),
              ),
              SheetRow(
                iconData: AppIcons.value,
                label: l10n.artifactValue,
                trailing: MoneyField(
                  controller: _price,
                  onChanged: () => setState(() {}),
                ),
              ),
              SheetRow(
                iconData: AppIcons.split,
                label: l10n.artifactSplit,
                trailing: AppSegmented(
                  selected: _split ? 1 : 0,
                  onSelected: (index) => setState(() => _split = index == 1),
                  segments: [
                    AppSegment(label: l10n.artifactSplitWhole),
                    AppSegment(
                      label: l10n.artifactSplitBlocks(
                        formatMinutes(l10n, _block),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s5),
          AppButton(
            text: l10n.typeCreate,
            expand: true,
            onPressed: ready ? () => unawaited(_save(categoryId)) : null,
          ),
        ],
      ),
    );
  }
}
