import 'package:app_ui/app_ui.dart';

/// {@template live_text_controller}
/// A field's text, part of which may still be being written by someone
/// other than the keyboard: words being dictated, which the recognizer can
/// still revise.
///
/// That part ([live]) is drawn in ink3, the rest as the field draws it. Once
/// the words are settled, [live] goes back to null and the text is ordinary
/// text.
/// {@endtemplate}
class LiveTextController extends TextEditingController {
  /// {@macro live_text_controller}
  LiveTextController({super.text});

  TextRange? _live;

  /// The part of the text still open to revision, or null.
  TextRange? get live => _live;

  /// Replaces the text and marks [live] in it, without moving the cursor
  /// off the end.
  void write(String text, {TextRange? live}) {
    _live = live;
    value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Settles whatever was live.
  void settle() {
    if (_live == null) return;
    _live = null;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final live = _live;
    if (live == null || !live.isValid || live.end > text.length) {
      return super.buildTextSpan(
        context: context,
        withComposing: withComposing,
        style: style,
      );
    }

    return TextSpan(
      style: style,
      children: [
        TextSpan(text: live.textBefore(text)),
        TextSpan(
          text: live.textInside(text),
          style: const TextStyle(color: AppColors.ink3),
        ),
        TextSpan(text: live.textAfter(text)),
      ],
    );
  }
}

/// Draws what floats at the foot of a page of notes, given the notes to
/// write into and the task they are a task's notes of (null for a fixed
/// block): the agent's bar and the microphone that dictates.
typedef NotesDockBuilder =
    Widget Function(
      BuildContext context,
      LiveTextController notes,
      String? taskId,
    );

/// How far the notes scroll past their last line, so it clears the dock:
/// the dock's margin, its height and a little air.
const double kNotesDockClearance =
    kFloatingActionButtonMargin + 56 + AppSpacing.s6;
