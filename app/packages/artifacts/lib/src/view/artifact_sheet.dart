import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/bloc/artifacts_cubit.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/sheet_frame.dart';
import 'package:artifacts/src/view/sheet_rows.dart';
import 'package:artifacts/src/view/type_sheet.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';

/// Opens the sheet that puts a delivery in the queue, or, [started],
/// straight into Em andamento.
///
/// The sheet is its own route, so it is handed the cubit it writes with.
Future<void> showArtifactSheet(
  BuildContext context, {
  CatalogCategory? initialCategory,
  CatalogType? initialType,
  String? initialName,
  DateTime? initialDeadline,
  bool started = false,
  bool top = true,
}) {
  final cubit = context.read<ArtifactsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: ArtifactSheet(
        initialCategory: initialCategory,
        initialType: initialType,
        initialName: initialName,
        initialDeadline: initialDeadline,
        started: started,
        top: top,
      ),
    ),
  );
}

/// {@template artifact_sheet}
/// A delivery in two steps: what kind it is, then who it is for.
///
/// It opens on the catalogue, since nearly everything she delivers is a
/// kind she has delivered before: picking one brings its time, its value
/// and how the day may cut it, and leaves only the name and the day to
/// write. A one-off delivery, with no kind, is the last line of the
/// catalogue, and is timed and priced by hand. The second step reads it all
/// back as rows, each one changed in place, and says which goal it will
/// count towards.
/// {@endtemplate}
class ArtifactSheet extends StatefulWidget {
  /// {@macro artifact_sheet}
  const ArtifactSheet({
    this.initialCategory,
    this.initialType,
    this.initialName,
    this.initialDeadline,
    this.started = false,
    this.top = true,
    super.key,
  });

  /// The shelf of [initialType].
  final CatalogCategory? initialCategory;

  /// The kind already picked; null opens on the catalogue.
  final CatalogType? initialType;

  /// The name it starts with.
  final String? initialName;

  /// The day it starts due on.
  final DateTime? initialDeadline;

  /// Whether it is begun as it is written down (Em andamento's +): its
  /// time runs from now, so it must have a day, a week out unless picked,
  /// and it takes no place in the queue.
  final bool started;

  /// Whether it enters the queue at the top rather than the end, until
  /// she picks.
  final bool top;

  @override
  State<ArtifactSheet> createState() => _ArtifactSheetState();
}

class _ArtifactSheetState extends State<ArtifactSheet> {
  /// How long a one-off takes until she says otherwise.
  static const _looseMinutes = 60;

  /// The block a one-off, or a kind with none, is cut in.
  static const _defaultBlock = 60;

  late CatalogType? _type = widget.initialType;
  late CatalogCategory? _category = widget.initialCategory;

  /// Whether she chose a one-off delivery, with no kind.
  bool _loose = false;
  late final _name = TextEditingController(text: widget.initialName);
  final _search = TextEditingController();
  final _value = TextEditingController();
  late bool _split = widget.initialType?.blockMinutes != null;
  late bool _top = widget.top;
  late DateTime? _deadline =
      widget.initialDeadline ?? (widget.started ? _aWeekOut() : null);

  static DateTime _aWeekOut() {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day + 7);
  }

  int _minutes = _looseMinutes;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    _value.dispose();
    super.dispose();
  }

  void _pick(CatalogCategory category, CatalogType type) {
    setState(() {
      _category = category;
      _type = type;
      _loose = false;
      _split = type.blockMinutes != null;
      _name.text = '${type.name} · ';
    });
  }

  void _pickLoose() {
    setState(() {
      _type = null;
      _category = null;
      _loose = true;
      _split = false;
      // The one field both searched the catalogue and named the delivery.
      if (_name.text.isEmpty) _name.text = _search.text.trim();
    });
  }

  void _back() => setState(() {
    _type = null;
    _loose = false;
  });

  Future<void> _pickDeadline() async {
    final now = clock.now();
    final picked = await AppWheelPicker.dayAndTime(
      context,
      initial: _deadline ?? now.add(const Duration(days: 7)),
      earliest: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _deadline = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickMinutes() async {
    final picked = await AppWheelPicker.duration(
      context,
      initial: Duration(minutes: _minutes),
    );
    if (picked == null || picked.inMinutes <= 0 || !mounted) return;
    setState(() => _minutes = picked.inMinutes);
  }

  int? get _looseValue => int.tryParse(_value.text.trim());

  Future<void> _create() async {
    final title = _name.text.trim();
    if (title.isEmpty || _busy) return;
    final type = _type;
    setState(() => _busy = true);
    final made = await context.read<ArtifactsCubit>().create(
      title: title,
      type: type,
      minutes: type == null ? _minutes : null,
      value: type == null ? _looseValue : null,
      blockMinutes: _split ? (type?.blockMinutes ?? _defaultBlock) : null,
      deadline: _deadline,
      top: _top,
      started: widget.started,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (made) unawaited(Navigator.of(context).maybePop());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ArtifactsCubit>().state;
    final picking = _type == null && !_loose;
    return SheetFrame(
      title: l10n.artifactsNew,
      tall: picking,
      child: picking
          ? _catalog(l10n, state.catalog)
          : _details(l10n, state.goals),
    );
  }

  Widget _catalog(AppLocalizations l10n, List<CatalogCategory> categories) {
    final query = _search.text.trim().toLowerCase();
    // Everyone starts with an empty catalogue: it fills with her own kinds.
    final empty = categories.isEmpty;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      children: [
        AppTextField(
          controller: _search,
          hintText: empty
              ? l10n.artifactNameHint
              : l10n.artifactSheetSearchHint,
          onChanged: (_) => setState(() {}),
          onSubmitted: empty ? (_) => _pickLoose() : null,
        ),
        const SizedBox(height: AppSpacing.s5),
        Row(
          children: [
            const AppIcon(
              iconData: AppIcons.catalog,
              size: AppSpacing.s4,
              color: AppColors.ink2,
            ),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Text(l10n.catalogTitle, style: AppTypography.labelStrong),
            ),
            if (!empty)
              GestureDetector(
                onTap: () => unawaited(showTypeSheet(context)),
                child: Text(
                  l10n.catalogAddType,
                  style: AppTypography.label.copyWith(color: AppColors.ink3),
                ),
              ),
          ],
        ),
        if (empty) ...[
          const SizedBox(height: AppSpacing.s3),
          _EmptyCatalog(
            onNewType: () => unawaited(showTypeSheet(context)),
          ),
        ],
        for (final category in categories) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s1,
              AppSpacing.s4,
              AppSpacing.s1,
              AppSpacing.s2,
            ),
            child: Text(category.name, style: AppTypography.caption),
          ),
          SheetGroup(
            children: [
              for (final type in category.types)
                if (query.isEmpty || type.name.toLowerCase().contains(query))
                  _TypeRow(
                    type: type,
                    onTap: () => _pick(category, type),
                  ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.s4),
        SheetGroup(
          children: [
            InkWell(
              onTap: _pickLoose,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Row(
                  children: [
                    const AppIcon(
                      iconData: AppIcons.plus,
                      size: AppSpacing.s5,
                      color: AppColors.ink,
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.artifactSheetLoose,
                            style: AppTypography.bodyStrong,
                          ),
                          Text(
                            empty
                                ? l10n.catalogEmptyLooseHint
                                : l10n.artifactSheetLooseHint,
                            style: AppTypography.label,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _details(AppLocalizations l10n, List<Goal> goals) {
    final now = clock.now();
    final type = _type;
    final deadline = _deadline;
    final block = type?.blockMinutes ?? _defaultBlock;
    final price = type == null ? _looseValue : type.price;
    final goal = _goalFor(goals, type, price, deadline ?? now);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: AppTag(
                text: type == null
                    ? l10n.artifactLoose
                    : [
                        if (_category != null) _category!.name,
                        type.name,
                      ].join(' · '),
                iconData: AppIcons.catalog,
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            GestureDetector(
              onTap: _back,
              child: Text(
                l10n.artifactChangeType,
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
            ),
          ],
        ),
        TextField(
          controller: _name,
          autofocus: widget.initialName == null,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: AppColors.ink,
          cursorWidth: 1.5,
          style: AppTypography.title,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l10n.artifactNameHint,
            hintStyle: AppTypography.title.copyWith(color: AppColors.ink3),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: AppSpacing.s4,
            ),
          ),
        ),
        SheetGroup(
          children: [
            SheetRow(
              iconData: AppIcons.timer,
              label: l10n.artifactTotalTime,
              value: formatMinutes(l10n, type?.minutes ?? _minutes),
              note: type == null ? null : l10n.artifactTimeFromType(type.name),
              onTap: type == null ? () => unawaited(_pickMinutes()) : null,
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
                      formatMinutes(l10n, block),
                    ),
                  ),
                ],
              ),
            ),
            if (type == null)
              SheetRow(
                iconData: AppIcons.value,
                label: l10n.artifactValue,
                trailing: MoneyField(
                  controller: _value,
                  onChanged: () => setState(() {}),
                ),
              )
            else if (price != null)
              SheetRow(
                iconData: AppIcons.value,
                label: l10n.artifactValue,
                value: formatMoney(price),
              ),
            SheetRow(
              iconData: AppIcons.calendar,
              label: l10n.artifactDeadline,
              value: deadline == null
                  ? l10n.artifactNoDeadline
                  : dayName(l10n, deadline, now),
              onTap: () => unawaited(_pickDeadline()),
            ),
            if (goal != null)
              SheetRow(
                iconData: AppIcons.goal,
                label: l10n.artifactCountsFor,
                value: goalLabel(l10n, goal),
              ),
          ],
        ),
        // Begun at once, it is placed by how late it is, not in the queue.
        if (!widget.started) ...[
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: Text(l10n.artifactPlace, style: AppTypography.label),
              ),
              AppSegmented(
                selected: _top ? 0 : 1,
                onSelected: (index) => setState(() => _top = index == 0),
                segments: [
                  AppSegment(label: l10n.artifactPlaceTop),
                  AppSegment(label: l10n.artifactPlaceEnd),
                ],
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.s5),
        AppButton(
          text: widget.started ? l10n.artifactStart : l10n.artifactCreate,
          expand: true,
          onPressed: _name.text.trim().isEmpty || _busy
              ? null
              : () => unawaited(_create()),
        ),
      ],
    );
  }

  /// The goal a delivery due on [day] counts towards: the money goal of
  /// that stretch when it is worth something, or the count goal of its kind.
  Goal? _goalFor(
    List<Goal> goals,
    CatalogType? type,
    int? value,
    DateTime day,
  ) {
    for (final goal in goals) {
      final inStretch = !day.isBefore(goal.start) && day.isBefore(goal.end);
      if (!inStretch) continue;
      if (goal.kind == GoalKind.money && (value ?? 0) > 0) return goal;
      if (goal.kind == GoalKind.count &&
          type != null &&
          goal.type?.id == type.id) {
        return goal;
      }
    }
    return null;
  }
}

/// What the catalogue says before it holds anything: what a kind is for,
/// and the way to write the first one.
class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.onNewType});

  final VoidCallback onNewType;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s1,
        AppSpacing.s1,
        AppSpacing.s1,
        AppSpacing.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.catalogEmptyTitle, style: AppTypography.bodyStrong),
          const SizedBox(height: AppSpacing.s1),
          Text(
            l10n.catalogEmptyBody,
            style: AppTypography.label.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(height: AppSpacing.s4),
          AppPillButton(
            iconData: AppIcons.plus,
            label: l10n.catalogNewType,
            onPressed: onNewType,
          ),
        ],
      ),
    );
  }
}

/// One kind in the catalogue: its name, its time and its value.
class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type, required this.onTap});

  final CatalogType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final price = type.price;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3 + 2,
        ),
        child: Row(
          children: [
            Expanded(child: Text(type.name, style: AppTypography.body)),
            Text(
              [
                formatMinutes(l10n, type.minutes),
                if (price != null) formatMoney(price),
              ].join(' · '),
              style: AppTypography.label.copyWith(color: AppColors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
