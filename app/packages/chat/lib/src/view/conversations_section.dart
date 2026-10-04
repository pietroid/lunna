import 'package:app_ui/app_ui.dart';
import 'package:chat/src/data/chat_repository.dart';
import 'package:chat/src/models/models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// {@template conversations_section}
/// Conversas: every conversation, newest reply first, cut into days.
///
/// It reads its own list rather than sharing the timeline's. The timeline is
/// what has an hour; this is what was said, and most of what was said never
/// got an hour. A thread with one is still here, because the conversation
/// behind it is the thing this screen is about.
///
/// A row is a thread's name and the last thing said in it, with the hour of
/// that last reply on the right. The days are headings and nothing else:
/// which one a thread falls under is the clock of its last reply, so a thread
/// answered again today moves to the top of today by itself.
/// {@endtemplate}
class ConversationsSection extends StatefulWidget {
  /// {@macro conversations_section}
  const ConversationsSection({
    required this.onThreadTap,
    this.reloadToken = 0,
    super.key,
  });

  /// Opens the thread with this slug, and completes when it is closed again.
  ///
  /// Awaited rather than fired: the last reply and its hour are both what the
  /// thread just changed, so the row is read again once the user comes back.
  final Future<void> Function(String slug) onThreadTap;

  /// Bump this to read the list again.
  ///
  /// The screen is kept alive behind the tab bar, so it is not rebuilt when
  /// it comes back into view and cannot notice a thread that was started
  /// while it was off screen. Whoever started one says so by changing this.
  final int reloadToken;

  @override
  State<ConversationsSection> createState() => _ConversationsSectionState();
}

class _ConversationsSectionState extends State<ConversationsSection> {
  late Future<List<ThreadItem>> _items = _load();

  Future<List<ThreadItem>> _load() =>
      context.read<ChatRepository>().fetchItems();

  Future<void> _open(String slug) async {
    await widget.onThreadTap(slug);
    if (mounted) setState(() => _items = _load());
  }

  @override
  void didUpdateWidget(ConversationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadToken != oldWidget.reloadToken) {
      setState(() => _items = _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ThreadItem>>(
      future: _items,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null) return const _Loading();
        if (items.isEmpty) return const _Empty();

        return ListView(
          padding: const EdgeInsets.only(
            // Room under the last row so the bar never covers it.
            bottom: AppSpacing.s16 + AppSpacing.s12,
          ),
          children: _rows(items),
        );
      },
    );
  }

  /// The list, with a heading wherever the day changes.
  List<Widget> _rows(List<ThreadItem> items) {
    final rows = <Widget>[];
    DateTime? day;

    for (final item in items) {
      final itemDay = _dayOf(item.updatedAt);
      if (day == null || itemDay != day) {
        rows.add(_Heading(label: _dayLabel(itemDay), first: day == null));
        day = itemDay;
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s1),
          child: _Row(
            item: item,
            onTap: () => _open(item.slug),
          ),
        ),
      );
    }

    return rows;
  }
}

/// One thread: what it is, the last thing said in it, and when that was.
class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onTap});

  final ThreadItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fill,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4,
            vertical: AppSpacing.s3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTypography.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.preview.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s1),
                      Text(
                        item.preview,
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                _hhmm(item.updatedAt),
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _hhmm(DateTime at) {
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }
}

/// The day a heading stands for, with the clock cut off it.
DateTime _dayOf(DateTime at) => DateTime(at.year, at.month, at.day);

/// What a day is called.
///
/// The two days a person thinks of by name are named; everything older is a
/// date, because "há 4 dias" makes the reader do arithmetic to work out which
/// day it actually was.
String _dayLabel(DateTime day, {DateTime? now}) {
  final today = _dayOf(now ?? DateTime.now());
  final difference = today.difference(day).inDays;

  if (difference == 0) return 'Hoje';
  if (difference == 1) return 'Ontem';

  final label = '${day.day} de ${_months[day.month - 1]}';

  return day.year == today.year ? label : '$label de ${day.year}';
}

const _months = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

/// A day, over the threads last touched on it.
class _Heading extends StatelessWidget {
  const _Heading({required this.label, required this.first});

  final String label;

  /// Whether it is the first thing on the screen, and so needs no room above.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: first ? AppSpacing.s2 : AppSpacing.s6,
        bottom: AppSpacing.s1,
      ),
      child: Text(label, style: AppTypography.title),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        AppSkeleton(height: AppSpacing.s12, radius: AppSpacing.chipRadius),
        SizedBox(height: AppSpacing.s1),
        AppSkeleton(height: AppSpacing.s12, radius: AppSpacing.chipRadius),
      ],
    );
  }
}

/// What the screen says before anything has been said.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Nada por aqui ainda. Toque no orb para começar uma conversa.',
      style: AppTypography.body.copyWith(color: AppColors.ink3),
    );
  }
}
