import 'dart:async';
import 'dart:math' as math;

import 'package:agent/src/voice/voice_recognizer.dart';
import 'package:bloc/bloc.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';

/// Where a recording stands.
enum VoiceStatus {
  /// Not recording.
  idle,

  /// Asking for the microphone.
  preparing,

  /// Hearing, and writing down.
  listening,

  /// Hit the limit: no longer hearing, holding what was said until it is
  /// sent or dropped.
  stopped,

  /// The user refused the microphone.
  denied,

  /// The device cannot recognize speech.
  unavailable;

  /// Whether the composer is a recorder.
  bool get recording =>
      this == preparing || this == listening || this == stopped;

  /// Whether the microphone is offered at all.
  bool get offered => this != denied && this != unavailable;
}

/// {@template voice_take}
/// What a recording came to.
/// {@endtemplate}
class VoiceTake extends Equatable {
  /// {@macro voice_take}
  const VoiceTake({required this.text, required this.length});

  final String text;

  /// How long the user spoke for.
  final Duration length;

  @override
  List<Object?> get props => [text, length];
}

/// {@template voice_state}
/// A recording: the words so far, the microphone's last levels and the time.
/// {@endtemplate}
class VoiceState extends Equatable {
  /// {@macro voice_state}
  const VoiceState({
    this.status = VoiceStatus.idle,
    this.heard = '',
    this.hearing = '',
    this.levels = const [],
    this.elapsed = Duration.zero,
  });

  final VoiceStatus status;

  /// What is settled: the sessions that have ended.
  final String heard;

  /// What the session running now has heard, still open to revision.
  final String hearing;

  /// The microphone's last levels, from 0 to 1, oldest first.
  final List<double> levels;

  final Duration elapsed;

  /// Everything said so far.
  String get text => _join(heard, hearing);

  VoiceState copyWith({
    VoiceStatus? status,
    String? heard,
    String? hearing,
    List<double>? levels,
    Duration? elapsed,
  }) => VoiceState(
    status: status ?? this.status,
    heard: heard ?? this.heard,
    hearing: hearing ?? this.hearing,
    levels: levels ?? this.levels,
    elapsed: elapsed ?? this.elapsed,
  );

  @override
  List<Object?> get props => [status, heard, hearing, levels, elapsed];
}

String _join(String a, String b) =>
    [a.trim(), b.trim()].where((part) => part.isNotEmpty).join(' ');

/// {@template voice_cubit}
/// One recording at a time, for the agent's composer.
///
/// The words are shown as they come and the recording ends only when the user
/// says so ([take] or [cancel]), or at [limit]. Silence ends nothing: where
/// the platform stops a session after a pause (Android), another one starts
/// and its words are joined to the last.
/// {@endtemplate}
class VoiceCubit extends Cubit<VoiceState> {
  /// {@macro voice_cubit}
  VoiceCubit({required this._recognizer}) : super(const VoiceState());

  final VoiceRecognizer _recognizer;

  /// The longest recording, which is iOS's own.
  static const limit = Duration(minutes: 1);

  /// How many levels the wave keeps.
  static const bars = 28;

  /// A session the platform ends sooner than this, having heard nothing,
  /// failed rather than paused: there is no microphone to hear with (a
  /// simulator), or the recognizer refused. Starting another would only fail
  /// the same way, over and over.
  static const quickEnd = Duration(seconds: 1);

  /// Counts sessions, so a late word from one that was ended is dropped.
  int _session = 0;

  DateTime? _startedAt;
  Timer? _ticker;

  // The platforms report the level on scales of their own (decibels, or
  // something like them), so it is drawn against the quietest and loudest
  // heard in this recording.
  double? _quietest;
  double? _loudest;

  /// Starts recording, asking for the microphone the first time.
  Future<void> start() async {
    if (state.status.recording) return;

    emit(const VoiceState(status: VoiceStatus.preparing));
    final availability = await _recognizer.prepare();
    if (isClosed || state.status != VoiceStatus.preparing) return;

    switch (availability) {
      case VoiceAvailability.denied:
        emit(const VoiceState(status: VoiceStatus.denied));
      case VoiceAvailability.unavailable:
        emit(const VoiceState(status: VoiceStatus.unavailable));
      case VoiceAvailability.available:
        _startedAt = clock.now();
        _quietest = _loudest = null;
        _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
          _tick();
        });
        emit(state.copyWith(status: VoiceStatus.listening));
        await _listen();
    }
  }

  Future<void> _listen() async {
    final session = ++_session;
    bool live() => !isClosed && session == _session;
    // Once a session has said its last words, anything after is a repeat.
    var said = false;
    var heard = false;
    final began = clock.now();

    try {
      await _recognizer.listen(
        onWords: (words, {required done}) {
          if (!live() || said || !state.status.recording) return;
          if (words.isNotEmpty) heard = true;
          if (done) {
            said = true;
            emit(state.copyWith(heard: _join(state.heard, words), hearing: ''));
          } else {
            emit(state.copyWith(hearing: words));
          }
        },
        onLevel: (level) {
          if (live()) _level(level);
        },
        onEnd: () {
          if (!live()) return;
          if (!heard && clock.now().difference(began) < quickEnd) {
            _giveUp();
            return;
          }
          _session++;
          emit(state.copyWith(heard: state.text, hearing: ''));
          _resume();
        },
      );
    } on Object {
      if (live()) _halt();
    }
  }

  /// Carries on after the platform ended a session on its own.
  void _resume() {
    if (state.status == VoiceStatus.listening) unawaited(_listen());
  }

  void _level(double level) {
    _quietest = math.min(_quietest ?? level, level);
    _loudest = math.max(_loudest ?? level, level);
    final range = _loudest! - _quietest!;
    final height = range < 1e-6 ? 0.0 : (level - _quietest!) / range;

    final levels = [...state.levels, height];
    emit(
      state.copyWith(
        levels: levels.length > bars
            ? levels.sublist(levels.length - bars)
            : levels,
      ),
    );
  }

  void _tick() {
    final startedAt = _startedAt;
    if (startedAt == null || state.status != VoiceStatus.listening) return;

    final elapsed = clock.now().difference(startedAt);
    if (elapsed >= limit) {
      emit(state.copyWith(elapsed: limit));
      _halt();
    } else {
      emit(state.copyWith(elapsed: elapsed));
    }
  }

  /// Stops after a session that failed, keeping whatever was heard before
  /// it; with nothing heard at all, there is no recognizer to be had here.
  void _giveUp() {
    _ticker?.cancel();
    _session++;
    emit(
      state.text.isEmpty
          ? const VoiceState(status: VoiceStatus.unavailable)
          : state.copyWith(
              status: VoiceStatus.stopped,
              heard: state.text,
              hearing: '',
            ),
    );
  }

  /// Stops hearing at the limit, holding the words.
  void _halt() {
    _ticker?.cancel();
    _session++;
    unawaited(_recognizer.stop());
    emit(
      state.copyWith(
        status: VoiceStatus.stopped,
        heard: state.text,
        hearing: '',
      ),
    );
  }

  /// Ends the recording and hands over what was said, or null when nothing
  /// was.
  Future<VoiceTake?> take() async {
    if (!state.status.recording) return null;

    final take = VoiceTake(
      text: state.text,
      length: state.status == VoiceStatus.stopped
          ? state.elapsed
          : clock.now().difference(_startedAt ?? clock.now()),
    );
    await _finish(_recognizer.stop);
    return take.text.isEmpty ? null : take;
  }

  /// Ends the recording and drops it.
  Future<void> cancel() => _finish(_recognizer.cancel);

  Future<void> _finish(Future<void> Function() end) async {
    _ticker?.cancel();
    _session++;
    _startedAt = null;
    final wasRecording = state.status.recording;
    emit(const VoiceState());
    if (wasRecording) await end();
  }

  @override
  Future<void> close() async {
    _ticker?.cancel();
    if (state.status.recording) await _recognizer.cancel();
    return super.close();
  }
}
