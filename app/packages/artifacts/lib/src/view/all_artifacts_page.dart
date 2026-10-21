import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:artifacts/src/view/artifact_row.dart';
import 'package:artifacts/src/view/shelf_filter.dart';
import 'package:l10n/l10n.dart';

/// {@template all_artifacts_page}
/// Every delivery, searched: those in the queue, in their order, then those
/// made, newest first.
///
/// The search reads the name, the kind and the shelf, so "mapa" finds every
/// natal chart and "Camila" everything for her; the shelves and their
/// kinds narrow it further.
/// {@endtemplate}
class AllArtifactsPage extends StatefulWidget {
  /// {@macro all_artifacts_page}
  const AllArtifactsPage({
    required this.queue,
    required this.done,
    required this.categories,
    required this.now,
    this.initialQuery = '',
    this.initialShelf = const Shelf(),
    super.key,
  });

  /// The deliveries not yet made, in order of priority.
  final List<Artifact> queue;

  /// The deliveries made, newest first.
  final List<Artifact> done;

  /// The catalogue's shelves, which filter the list.
  final List<CatalogCategory> categories;

  /// The moment it is drawn at.
  final DateTime now;

  /// What the search starts with.
  final String initialQuery;

  /// What the list is kept to when it opens.
  final Shelf initialShelf;

  @override
  State<AllArtifactsPage> createState() => _AllArtifactsPageState();
}

class _AllArtifactsPageState extends State<AllArtifactsPage> {
  late final _search = TextEditingController(text: widget.initialQuery);
  late Shelf _shelf = widget.initialShelf;

  bool _matches(Artifact a) {
    if (!_shelf.keeps(a)) return false;
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return [
      a.title,
      a.type?.name ?? '',
      a.category?.name ?? '',
    ].any((text) => text.toLowerCase().contains(query));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final queue = widget.queue.where(_matches).toList();
    final done = widget.done.where(_matches).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s5,
                AppSpacing.s3,
                AppSpacing.s5,
                AppSpacing.s8,
              ),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const AppIcon(
                        iconData: AppIcons.back,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s1),
                    Text(l10n.artifactsAllTitle, style: AppTypography.title),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                AppTextField(
                  controller: _search,
                  hintText: l10n.artifactsSearchHint,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.s3),
                ShelfFilter(
                  categories: widget.categories,
                  used: [...widget.queue, ...widget.done],
                  value: _shelf,
                  onChanged: (shelf) => setState(() => _shelf = shelf),
                ),
                if (queue.isEmpty && done.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s5),
                    child: Text(
                      l10n.artifactsNoResults(_search.text.trim()),
                      style: AppTypography.body.copyWith(
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                if (queue.isNotEmpty) ...[
                  _Section(title: l10n.artifactsInQueue, count: queue.length),
                  for (final artifact in queue) ...[
                    ArtifactRow(artifact: artifact, now: widget.now),
                    const SizedBox(height: AppSpacing.s2),
                  ],
                ],
                if (done.isNotEmpty) ...[
                  _Section(title: l10n.artifactsDone, count: done.length),
                  for (final artifact in done) ...[
                    ArtifactRow(artifact: artifact, now: widget.now),
                    const SizedBox(height: AppSpacing.s2),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s1,
        AppSpacing.s6,
        AppSpacing.s1,
        AppSpacing.s3,
      ),
      child: Row(
        children: [
          Text(title, style: AppTypography.title),
          const SizedBox(width: AppSpacing.s2),
          Text(
            '$count',
            style: AppTypography.label.copyWith(color: AppColors.ink3),
          ),
        ],
      ),
    );
  }
}
