import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/widgets.dart';

/// {@template done_archive_page}
/// Everything ticked off, newest first, to look something up later.
///
/// Opened from Menu ("Feitas"). The days are headed the way the calendar
/// heads them (Hoje, Ontem, then the date), each task is the card it was,
/// with the hour it was done at, its project and the start of its notes,
/// and a tap opens its page, where the notes can still be read and changed.
/// The field at the top looks in the titles and the notes.
///
/// A task's [TimelineEvent.startTime] here is when it was done, as on the
/// finished task's page.
/// {@endtemplate}
class DoneArchivePage extends StatefulWidget {
  /// {@macro done_archive_page}
  const DoneArchivePage({required this.done, required this.onOpen, super.key});

  /// The tasks done, newest first.
  final List<TimelineEvent> done;

  /// Opens a task's page.
  final ValueChanged<TimelineEvent> onOpen;

  @override
  State<DoneArchivePage> createState() => _DoneArchivePageState();
}

class _DoneArchivePageState extends State<DoneArchivePage> {
  String _query = '';

  List<TimelineEvent> get _found {
    final words = _query.trim().toLowerCase();
    if (words.isEmpty) return widget.done;

    return [
      for (final card in widget.done)
        if ('${card.title}\n${card.notes}'.toLowerCase().contains(words)) card,
    ];
  }

  String _dayLabel(AppLocalizations l10n, DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return l10n.archiveToday;
    if (days == 1) return l10n.archiveYesterday;

    final date = l10n.sectionDay(day);
    return date.isEmpty ? date : date[0].toUpperCase() + date.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = clock.now();
    final found = _found;
    final rows = <Widget>[];
    DateTime? day;
    for (final card in found) {
      final at = card.startTime;
      final its = DateTime(at.year, at.month, at.day);
      if (its != day) {
        day = its;
        rows.add(
          Padding(
            padding: EdgeInsets.only(
              top: rows.isEmpty ? AppSpacing.s2 : AppSpacing.s6,
              bottom: AppSpacing.s2,
            ),
            child: Text(
              _dayLabel(l10n, its, now),
              style: AppTypography.title,
            ),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s2),
          child: DoneArchiveTile(card: card, onTap: () => widget.onOpen(card)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          iconData: AppIcons.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Text(l10n.menuArchive, style: AppTypography.title),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s6,
                AppSpacing.s2,
                AppSpacing.s6,
                AppSpacing.s12,
              ),
              children: [
                AppTextField(
                  hintText: l10n.archiveSearch,
                  textInputAction: TextInputAction.search,
                  onChanged: (query) => setState(() => _query = query),
                ),
                const SizedBox(height: AppSpacing.s2),
                if (found.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s4),
                    child: Text(
                      widget.done.isEmpty
                          ? l10n.archiveEmpty
                          : l10n.archiveNoMatch,
                      style: AppTypography.label.copyWith(
                        color: AppColors.ink3,
                      ),
                    ),
                  ),
                ...rows,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// {@template done_archive_tile}
/// One task in the archive: the check, its name and the hour it was done
/// at, then its project and the start of its notes, when it has them.
/// {@endtemplate}
class DoneArchiveTile extends StatelessWidget {
  /// {@macro done_archive_tile}
  const DoneArchiveTile({required this.card, required this.onTap, super.key});

  /// The task done; its start is when it was done.
  final TimelineEvent card;

  /// Opens its page.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final notes = notesPreview(card.notes);
    final project = card.projectTitle;

    return Material(
      color: AppColors.fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppIcon(
                    iconData: AppIcons.check,
                    size: AppSpacing.s4,
                    color: AppColors.ink3,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      card.title,
                      style: AppTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Text(
                    hhmm(card.startTime),
                    style: AppTypography.label.copyWith(
                      color: AppColors.ink3,
                    ),
                  ),
                ],
              ),
              if (project != null || notes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s2),
                Row(
                  children: [
                    if (project != null) ...[
                      AppTag(text: project),
                      const SizedBox(width: AppSpacing.s2),
                    ],
                    Expanded(
                      child: Text(
                        notes,
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
