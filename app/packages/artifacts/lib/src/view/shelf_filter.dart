import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:flutter/rendering.dart';
import 'package:l10n/l10n.dart';

/// What a list of deliveries is kept to: one kind, or one shelf of the
/// catalogue. Both null, everything.
class Shelf {
  /// Creates a filter.
  const Shelf({this.category, this.type})
    : assert(category == null || type == null, 'one or the other');

  /// The shelf's id; null when not kept to a shelf.
  final String? category;

  /// The kind's id; null when not kept to a kind.
  final String? type;

  /// Whether [artifact] is kept.
  bool keeps(Artifact artifact) =>
      (category == null || artifact.category?.id == category) &&
      (type == null || artifact.type?.id == type);
}

/// {@template shelf_filter}
/// The catalogue as one line of filters: "Todas", then the kinds she uses
/// most, then the shelves, each marked with a folder.
///
/// A kind picked elsewhere that is not among the most used joins the line
/// after them. The line scrolls sideways, and the picked one is brought
/// into sight.
/// {@endtemplate}
class ShelfFilter extends StatefulWidget {
  /// {@macro shelf_filter}
  const ShelfFilter({
    required this.categories,
    required this.top,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The catalogue's shelves.
  final List<CatalogCategory> categories;

  /// The kinds she uses most, most used first, as the server counts them.
  final List<CatalogType> top;

  /// What is picked.
  final Shelf value;

  /// Called with what was picked.
  final ValueChanged<Shelf> onChanged;

  @override
  State<ShelfFilter> createState() => _ShelfFilterState();
}

class _ShelfFilterState extends State<ShelfFilter> {
  final _scroll = ScrollController();
  final GlobalKey _picked = GlobalKey();

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(ShelfFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value.category != widget.value.category ||
        oldWidget.value.type != widget.value.type) {
      _reveal();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the line, and only the line, so the picked one is in sight.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _picked.currentContext?.findRenderObject();
      if (box == null || !_scroll.hasClients) return;
      final offset = RenderAbstractViewport.of(
        box,
      ).getOffsetToReveal(box, 0.5).offset;
      final position = _scroll.position;
      _scroll.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = widget.value;
    final kinds = [...widget.top];
    if (value.type != null && !kinds.any((t) => t.id == value.type)) {
      final picked = widget.categories
          .expand((c) => c.types)
          .where((t) => t.id == value.type)
          .firstOrNull;
      if (picked != null) kinds.add(picked);
    }
    final filters = [
      const Shelf(),
      for (final kind in kinds) Shelf(type: kind.id),
      for (final category in widget.categories) Shelf(category: category.id),
    ];
    final names = {
      for (final kind in kinds) kind.id: kind.name,
      for (final category in widget.categories) category.id: category.name,
    };

    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: AppSegmented(
        selectedKey: _picked,
        selected: filters.indexWhere(
          (f) => f.category == value.category && f.type == value.type,
        ),
        onSelected: (index) => widget.onChanged(filters[index]),
        segments: [
          for (final filter in filters)
            if (filter.category != null)
              AppSegment(
                label: names[filter.category]!,
                iconData: AppIcons.category,
              )
            else
              AppSegment(label: names[filter.type] ?? l10n.artifactsAll),
        ],
      ),
    );
  }
}
