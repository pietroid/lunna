import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Whether the device can turn speech into text for this app.
enum VoiceAvailability {
  /// It can, and the user let it.
  available,

  /// The user refused the microphone or speech recognition.
  denied,

  /// The device or browser has no speech recognition.
  unavailable,
}

/// Called with the words recognized so far in the current session; [done]
/// once they are the session's last.
typedef VoiceWords = void Function(String words, {required bool done});

/// {@template voice_recognizer}
/// Speech to text, on the device.
///
/// A session runs until [stop] or [cancel], or until the platform ends it on
/// its own (Android stops after a short silence), which it reports through
/// `onEnd`. Nothing it hears leaves the device through this app: the text is
/// what the agent gets, never the audio.
/// {@endtemplate}
abstract interface class VoiceRecognizer {
  /// Asks for the microphone the first time, and says what came of it.
  Future<VoiceAvailability> prepare();

  /// Starts a session in Brazilian Portuguese.
  ///
  /// [onLevel] gets the microphone's level, in the platform's own scale.
  Future<void> listen({
    required VoiceWords onWords,
    required ValueChanged<double> onLevel,
    required VoidCallback onEnd,
  });

  /// Ends the session, keeping what was said.
  Future<void> stop();

  /// Ends the session and drops it.
  Future<void> cancel();
}

/// {@macro voice_recognizer}
///
/// Over the platform's own recognizer (`speech_to_text`): on the device where
/// it has Portuguese, in the platform's cloud where it does not.
class SpeechVoiceRecognizer implements VoiceRecognizer {
  /// {@macro voice_recognizer}
  SpeechVoiceRecognizer({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  bool _ready = false;

  VoidCallback? _onEnd;

  /// The last call into the plugin, which the next one waits for.
  ///
  /// The plugin runs each call on a thread of its own, unguarded: a listen
  /// that starts while another call is still setting up or letting go of the
  /// audio engine crashes the app (iOS, `AVAudioNode` from two threads).
  Future<void> _last = Future.value();

  /// When the last session ended. The plugin says a session is done before
  /// it has let go of the audio engine, so the next one waits a moment.
  DateTime? _endedAt;

  static const _settle = Duration(milliseconds: 400);

  /// Runs [call] once every call before it is over.
  Future<void> _serial(Future<void> Function() call) {
    final next = _last.then((_) => call());
    _last = next.catchError((Object _) {});
    return next;
  }

  /// The browser wants a language tag, the phones take either.
  static const _locale = kIsWeb ? 'pt-BR' : 'pt_BR';

  @override
  Future<VoiceAvailability> prepare() async {
    if (_ready) return VoiceAvailability.available;

    try {
      _ready = await _speech.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus) _end();
        },
        onError: (error) {
          if (error.permanent) _end();
        },
      );
    } on Object {
      _ready = false;
    }
    if (_ready) return VoiceAvailability.available;

    final permitted = await _speech.hasPermission.catchError((_) => true);
    return permitted ? VoiceAvailability.unavailable : VoiceAvailability.denied;
  }

  void _end() {
    _endedAt = DateTime.now();
    final onEnd = _onEnd;
    _onEnd = null;
    onEnd?.call();
  }

  @override
  Future<void> listen({
    required VoiceWords onWords,
    required ValueChanged<double> onLevel,
    required VoidCallback onEnd,
  }) async {
    await _serial(() async {
      final endedAt = _endedAt;
      if (endedAt != null) {
        final wait = _settle - DateTime.now().difference(endedAt);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _onEnd = onEnd;
      await _speech.listen(
        onResult: (result) =>
            onWords(result.recognizedWords, done: result.finalResult),
        onSoundLevelChange: onLevel,
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 30),
        ),
      );
    });
  }

  @override
  Future<void> stop() {
    _onEnd = null;
    return _serial(() async {
      await _speech.stop();
      _endedAt = DateTime.now();
    });
  }

  @override
  Future<void> cancel() {
    _onEnd = null;
    return _serial(() async {
      await _speech.cancel();
      _endedAt = DateTime.now();
    });
  }
}
