import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/format.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/sheet_frame.dart';
import 'package:l10n/l10n.dart';

/// Opens the sheet that puts a delivery in the queue.
Future<void> showArtifactSheet(
  BuildContext context, {
  required List<CatalogCategory> categories,
  required List<Goal> goals,
  required DateTime now,
  CatalogCategory? initialCategory,
  CatalogType? initialType,
  String? initialName,
  DateTime? initialDeadline,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.bg.withValues(alpha: 0.72),
    builder: (_) => ArtifactSheet(
      categories: categories,
      goals: goals,
      now: now,
      initialCategory: initialCategory,
      initialType: initialType,
      initialName: initialName,
      initialDeadline: initialDeadline,
    ),
  );
}

/// {@template artifact_sheet}
/// A delivery in two steps: what kind it is, then who it is for.
///
/// It opens on the catalogue, since nearly everything she delivers is a
/// kind she has delivered before: picking one brings its time, its value
/// and how the day may cut it, and leaves only the name and the day to
/// write. A loose delivery, with no kind, is the last line of the
/// catalogue. The second step reads it all back as rows, each one changed
/// in place, and says which goal it will count towards.
/// {@endtemplate}
class ArtifactSheet extends StatefulWidget {
  /// {@macro artifact_sheet}
  const ArtifactSheet({
    required this.categories,
    required this.goals,
    required this.now,
    this.initialCategory,
    this.initialType,
    this.initialName,
    this.initialDeadline,
    super.key,
  });

  /// The catalogue.
  final List<CatalogCategory> categories;

  /// The goals a delivery may count towards.
  final List<Goal> goals;

  /// The moment it is drawn at.
  final DateTime now;

  /// The shelf of [initialType].
  final CatalogCategory? initialCategory;

  /// The kind already picked; null opens on the catalogue.
  final CatalogType? initialType;

  /// The name it starts with.
  final String? initialName;

  /// The day it starts due on.
  final DateTime? initialDeadline;

  @override
  State<ArtifactSheet> createState() => _ArtifactSheetState();
}

class _ArtifactSheetState extends State<ArtifactSheet> {
  late CatalogType? _type = widget.initialType;
  late CatalogCategory? _category = widget.initialCategory;
  late final _name = TextEditingController(text: widget.initialName);
  final _search = TextEditingController();
  late bool _split = widget.initialType?.blockMinutes != null;
  bool _top = true;

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  void _pick(CatalogCategory category, CatalogType type) {
    setState(() {
      _category = category;
      _type = type;
      _split = type.blockMinutes != null;
      _name.text = '${type.name} · ';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SheetFrame(
      title: l10n.artifactsNew,
      tall: _type == null,
      child: _type == null ? _catalog(l10n) : _details(l10n, _type!),
    );
  }

  Widget _catalog(AppLocalizations l10n) {
    final query = _search.text.trim().toLowerCase();
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      children: [
        AppTextField(
          controller: _search,
          hintText: l10n.artifactSheetSearchHint,
          onChanged: (_) => setState(() {}),
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
            Text(
              l10n.catalogEdit,
              style: AppTypography.label.copyWith(color: AppColors.ink3),
            ),
          ],
        ),
        for (final category in widget.categories) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s1,
              AppSpacing.s4,
              AppSpacing.s1,
              AppSpacing.s2,
            ),
            child: Text(category.name, style: AppTypography.caption),
          ),
          _Group(
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
        _Group(
          children: [
            InkWell(
              onTap: () {},
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
                            l10n.artifactSheetLooseHint,
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

  Widget _details(AppLocalizations l10n, CatalogType type) {
    final now = widget.now;
    final deadline = widget.initialDeadline;
    final block = type.blockMinutes ?? 60;
    final price = type.price;
    final goal = _goalFor(type, deadline ?? now);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppTag(
              text: [
                if (_category != null) _category!.name,
                type.name,
              ].join(' · '),
              iconData: AppIcons.catalog,
            ),
            const SizedBox(width: AppSpacing.s2),
            GestureDetector(
              onTap: () => setState(() => _type = null),
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
        _Group(
          children: [
            _FieldRow(
              iconData: AppIcons.timer,
              label: l10n.artifactTotalTime,
              value: formatMinutes(l10n, type.minutes),
              note: l10n.artifactTimeFromType(type.name),
            ),
            _FieldRow(
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
            if (price != null)
              _FieldRow(
                iconData: AppIcons.value,
                label: l10n.artifactValue,
                value: formatMoney(price),
              ),
            _FieldRow(
              iconData: AppIcons.calendar,
              label: l10n.artifactDeadline,
              value: deadline == null ? '—' : dayName(l10n, deadline, now),
            ),
            if (goal != null)
              _FieldRow(
                iconData: AppIcons.goal,
                label: l10n.artifactCountsFor,
                value: goalLabel(l10n, goal),
              ),
          ],
        ),
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
        const SizedBox(height: AppSpacing.s5),
        AppButton(
          text: l10n.artifactCreate,
          expand: true,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  /// The goal a delivery of [type] due on [day] counts towards: the money
  /// goal of that stretch when it is worth something, or the count goal of
  /// its kind.
  Goal? _goalFor(CatalogType type, DateTime day) {
    for (final goal in widget.goals) {
      final inStretch = !day.isBefore(goal.start) && day.isBefore(goal.end);
      if (!inStretch) continue;
      if (goal.kind == GoalKind.money && type.price != null) return goal;
      if (goal.kind == GoalKind.count && goal.type?.id == type.id) return goal;
    }
    return null;
  }
}

/// Rows on one fill, split by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fill,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.s4,
                color: AppColors.line,
              ),
            children[i],
          ],
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

/// One line of a delivery: an icon, what it is, and its value.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.iconData,
    required this.label,
    this.value,
    this.note,
    this.trailing,
  });

  final AppIconData iconData;
  final String label;
  final String? value;
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: trailing == null ? AppSpacing.s3 + 2 : AppSpacing.s2,
      ),
      child: Row(
        children: [
          AppIcon(
            iconData: iconData,
            size: AppSpacing.s5,
            color: AppColors.ink2,
          ),
          const SizedBox(width: AppSpacing.s3),
          Text(
            label,
            style: AppTypography.body.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  trailing ??
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        value ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong,
                      ),
                      if (note != null)
                        Text(
                          note!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.ink3,
                          ),
                        ),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
