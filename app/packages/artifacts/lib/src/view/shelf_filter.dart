import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:l10n/l10n.dart';

/// What a list of deliveries is kept to: a shelf of the catalogue, and
/// within it one kind. Both null, everything.
class Shelf {
  /// Creates a filter.
  const Shelf({this.category, this.type});

  /// The shelf's id; null, every shelf.
  final String? category;

  /// The kind's id, always one on [category]; null, every kind on it.
  final String? type;

  /// Whether [artifact] is kept.
  bool keeps(Artifact artifact) =>
      (category == null || artifact.category?.id == category) &&
      (type == null || artifact.type?.id == type);
}

/// {@template shelf_filter}
/// The catalogue's two levels as a filter: the shelves on one line and,
/// once a shelf is picked, its kinds on a second line under it.
///
/// The second line only exists for a picked shelf, so with "Todas" the
/// filter is a single line, and a kind is never picked without its shelf.
/// {@endtemplate}
class ShelfFilter extends StatelessWidget {
  /// {@macro shelf_filter}
  const ShelfFilter({
    required this.categories,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The catalogue's shelves.
  final List<CatalogCategory> categories;

  /// What is picked.
  final Shelf value;

  /// Called with what was picked.
  final ValueChanged<Shelf> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shelves = [null, ...categories];
    final picked = categories
        .where((c) => c.id == value.category)
        .firstOrNull;
    final kinds = [null, ...?picked?.types];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: AppSegmented(
            selected: shelves.indexWhere((c) => c?.id == value.category),
            onSelected: (index) =>
                onChanged(Shelf(category: shelves[index]?.id)),
            segments: [
              for (final shelf in shelves)
                AppSegment(label: shelf?.name ?? l10n.artifactsAll),
            ],
          ),
        ),
        if (picked != null) ...[
          const SizedBox(height: AppSpacing.s2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: AppSegmented(
              selected: kinds.indexWhere((t) => t?.id == value.type),
              onSelected: (index) => onChanged(
                Shelf(category: picked.id, type: kinds[index]?.id),
              ),
              segments: [
                for (final kind in kinds)
                  AppSegment(label: kind?.name ?? l10n.artifactsAllTypes),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
