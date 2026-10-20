import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:timeline/src/data/timeline_repository.dart';
import 'package:timeline/src/models/models.dart';

/// Where the archive is in reading what was done.
enum DoneArchiveStatus {
  /// The first page is on its way.
  loading,

  /// What there is has been read; more may come as it scrolls.
  ready,

  /// The first page could not be read.
  failure,
}

/// {@template done_archive_state}
/// The tasks done that the archive has read so far, for [query].
/// {@endtemplate}
class DoneArchiveState extends Equatable {
  /// {@macro done_archive_state}
  const DoneArchiveState({
    this.status = DoneArchiveStatus.loading,
    this.done = const [],
    this.query = '',
    this.hasMore = false,
    this.loadingMore = false,
  });

  /// Whether the first page is in.
  final DoneArchiveStatus status;

  /// The tasks done, newest first; each one's start is when it was done.
  final List<TimelineEvent> done;

  /// The words being looked for, as typed. Blank is everything.
  final String query;

  /// Whether the server may have older ones still.
  final bool hasMore;

  /// Whether the next page is on its way.
  final bool loadingMore;

  /// A copy with the given fields replaced.
  DoneArchiveState copyWith({
    DoneArchiveStatus? status,
    List<TimelineEvent>? done,
    String? query,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return DoneArchiveState(
      status: status ?? this.status,
      done: done ?? this.done,
      query: query ?? this.query,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }

  @override
  List<Object?> get props => [status, done, query, hasMore, loadingMore];
}

/// {@template done_archive_cubit}
/// The archive in Menu: everything ticked off, newest first, a page at a
/// time, and the search over it.
///
/// The server does the looking ([TimelineRepository.fetchDone]), so a task
/// done a year ago is found without scrolling to it. Typing waits a moment
/// for the words to settle; an answer to words no longer in the field is
/// thrown away.
/// {@endtemplate}
class DoneArchiveCubit extends Cubit<DoneArchiveState> {
  /// {@macro done_archive_cubit}
  DoneArchiveCubit({
    required this._repository,
    this.debounce = const Duration(milliseconds: 300),
    this.pageSize = TimelineRepository.donePage,
  }) : super(const DoneArchiveState());

  final TimelineRepository _repository;

  /// How long typing must pause before the words are looked for.
  final Duration debounce;

  /// How many tasks one page asks for.
  final int pageSize;

  Timer? _typing;

  /// Bumped on every new first page, so a late answer to an older one is
  /// recognised and dropped.
  int _generation = 0;

  /// Reads the first page again, for the words in the field.
  Future<void> load() async {
    final generation = ++_generation;
    final query = state.query;
    emit(
      state.copyWith(
        status: state.done.isEmpty ? DoneArchiveStatus.loading : null,
        loadingMore: false,
      ),
    );
    try {
      final page = await _repository.fetchDone(query: query, limit: pageSize);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: DoneArchiveStatus.ready,
          done: page,
          hasMore: page.length == pageSize,
        ),
      );
    } on Object {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: state.done.isEmpty ? DoneArchiveStatus.failure : null,
        ),
      );
    }
  }

  /// The words in the field changed: look for them once typing pauses.
  void search(String query) {
    if (query == state.query) return;
    emit(state.copyWith(query: query));
    _typing?.cancel();
    _typing = Timer(debounce, () => unawaited(load()));
  }

  /// Reads the next page, once the list nears its end.
  Future<void> more() async {
    if (!state.hasMore || state.loadingMore || state.done.isEmpty) return;
    final generation = _generation;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repository.fetchDone(
        after: state.done.last,
        query: state.query,
        limit: pageSize,
      );
      if (isClosed || generation != _generation) return;
      final seen = {for (final card in state.done) card.id};
      emit(
        state.copyWith(
          done: [
            ...state.done,
            for (final card in page)
              if (!seen.contains(card.id)) card,
          ],
          hasMore: page.length == pageSize,
          loadingMore: false,
        ),
      );
    } on Object {
      // Scrolling back down asks again.
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(loadingMore: false));
      }
    }
  }

  @override
  Future<void> close() {
    _typing?.cancel();
    return super.close();
  }
}
