import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:clock/clock.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:l10n/l10n.dart';
import 'package:timeline/src/bloc/done_archive_cubit.dart';
import 'package:timeline/src/models/models.dart';
import 'package:timeline/src/widgets/widgets.dart';

/// {@template done_archive_page}
/// Everything ticked off, newest first, to look something up later.
///
/// Opened from Menu ("Feitas"), over a [DoneArchiveCubit]. The days are
/// headed the way the calendar heads them (Hoje, Ontem, then the date),
/// each task is the card it was, with the hour it was done at, its artifact
/// and the start of its notes, and a tap opens its page ([onOpen]), where
/// the notes can still be read and changed. The field at the top looks in
/// the titles and the notes, on the server; older pages come in as the
/// list nears its end.
///
/// A task's [TimelineEvent.startTime] here is when it was done, as on the
/// finished task's page.
/// {@endtemplate}
class DoneArchivePage extends StatelessWidget {
  /// {@macro done_archive_page}
  const DoneArchivePage({required this.onOpen, super.key});

  /// Opens a task's page; the archive reads itself again once it closes,
  /// since its notes may have changed there.
  final Future<void> Function(TimelineEvent card) onOpen;

  /// How close to the end of the list the next page is asked for.
  static const _nearEnd = 600.0;

  String _dayLabel(AppLocalizations l10n, DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(day).inDays;
    if (days <= 0) return l10n.archiveToday;
    if (days == 1) return l10n.archiveYesterday;

    final date = l10n.sectionDay(day);
    return date.isEmpty ? date : date[0].toUpperCase() + date.substring(1);
  }

  List<Widget> _rows(BuildContext context, DoneArchiveState state) {
    final l10n = context.l10n;
    final cubit = context.read<DoneArchiveCubit>();
    final now = clock.now();
    final rows = <Widget>[];
    DateTime? day;
    for (final card in state.done) {
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
          child: DoneArchiveTile(
            card: card,
            onTap: () async {
              await onOpen(card);
              if (!cubit.isClosed) unawaited(cubit.load());
            },
          ),
        ),
      );
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DoneArchiveCubit>();
    final hint = AppTypography.label.copyWith(color: AppColors.ink3);

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
            child: BlocBuilder<DoneArchiveCubit, DoneArchiveState>(
              builder: (context, state) {
                return NotificationListener<ScrollNotification>(
                  onNotification: (note) {
                    if (note.metrics.extentAfter < _nearEnd) {
                      unawaited(cubit.more());
                    }
                    return false;
                  },
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
                        onChanged: cubit.search,
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      if (state.status == DoneArchiveStatus.loading)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.s8),
                          child: Center(child: _Spinner()),
                        )
                      else if (state.status == DoneArchiveStatus.failure)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.archiveFailed, style: hint),
                              const SizedBox(height: AppSpacing.s2),
                              AppButton.text(
                                text: l10n.archiveRetry,
                                onPressed: () => unawaited(cubit.load()),
                              ),
                            ],
                          ),
                        )
                      else if (state.done.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s4),
                          child: Text(
                            state.query.trim().isEmpty
                                ? l10n.archiveEmpty
                                : l10n.archiveNoMatch,
                            style: hint,
                          ),
                        ),
                      ..._rows(context, state),
                      if (state.loadingMore)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.s4),
                          child: Center(child: _Spinner()),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A page on its way.
class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink3),
    );
  }
}

/// {@template done_archive_tile}
/// One task in the archive: the check, its name and the hour it was done
/// at, then its artifact and the start of its notes, when it has them.
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
    final artifact = card.artifactTitle;

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
              if (artifact != null || notes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s2),
                Row(
                  children: [
                    if (artifact != null) ...[
                      AppTag(text: artifact),
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
