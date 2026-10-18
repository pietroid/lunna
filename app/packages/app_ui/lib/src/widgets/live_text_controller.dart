import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/rendering.dart';

/// {@template live_text_controller}
/// A page of notes being edited: the field's text, part of which may still
/// be being written by someone other than the keyboard, and the links in it,
/// each drawn as a card.
///
/// Words being dictated, which the recognizer can still revise, are [live]:
/// drawn in ink3, the rest as the field draws it. Once the words are settled,
/// [live] goes back to null and the text is ordinary text.
///
/// A link is a paragraph of its own. In the [notes] it is the link written on
/// its own line; in the field it is one character, drawn as an
/// [AppLinkCard] as wide as the field. Pasting a link, or pressing return
/// after one, makes it a card and puts the cursor on the line under it.
/// Typing next to a card moves to a line of its own, so no two things share
/// its row. One backspace after a card, or at the start of the line under
/// it, takes the card and its line away.
///
/// The field must not hold its lines to the text's height
/// (`strutStyle: StrutStyle.disabled`), or a card overlaps the lines around
/// it.
/// {@endtemplate}
class LiveTextController extends TextEditingController {
  /// {@macro live_text_controller}
  LiveTextController({String text = ''}) {
    notes = text;
  }

  /// What stands for a card in the field's text.
  static const card = '\uFFFC';

  static final _link = RegExp(r'^https?://[^\s]+$');

  /// The links, in the order of their cards.
  final List<String> _links = [];

  TextRange? _live;

  /// The part of the text still open to revision, or null.
  TextRange? get live => _live;

  /// The notes as they are saved: every card back to its link, on its line.
  String get notes {
    var i = 0;
    return text.replaceAllMapped(card, (_) => _links[i++]);
  }

  /// Replaces everything with [notes], each line that is only a link drawn
  /// as its card.
  set notes(String notes) {
    _links.clear();
    final lines = [
      for (final line in notes.split('\n'))
        if (_link.hasMatch(line.trim())) _cardFor(line.trim()) else line,
    ];
    _live = null;
    super.value = TextEditingValue(
      text: lines.join('\n'),
      selection: TextSelection.collapsed(offset: lines.join('\n').length),
    );
  }

  String _cardFor(String url) {
    _links.add(url);
    return card;
  }

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
  set value(TextEditingValue next) => super.value = _edit(value, next);

  /// What [next] becomes once the cards have had their say: a card lost
  /// takes its line, a link pasted becomes a card, and a card never shares
  /// its row.
  TextEditingValue _edit(TextEditingValue old, TextEditingValue next) {
    final a = old.text;
    final b = next.text;
    if (a == b) return next;

    // The edit is what lies between what the two texts share at each end.
    final shortest = math.min(a.length, b.length);
    var p = 0;
    while (p < shortest && a.codeUnitAt(p) == b.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < shortest - p &&
        a.codeUnitAt(a.length - 1 - s) == b.codeUnitAt(b.length - 1 - s)) {
      s++;
    }
    var start = p;
    var end = a.length - s;
    // Cards come only from links: one pasted from another field is dropped.
    final inserted = b.substring(p, b.length - s).replaceAll(card, '');

    if (end > start) {
      // The line break under a card is part of it.
      if (a[start] == '\n' && start > 0 && a[start - 1] == card) start--;
      // And a card going takes its line with it.
      if (a.substring(start, end).contains(card) &&
          end < a.length &&
          a[end] == '\n' &&
          (start == 0 || a[start - 1] == '\n')) {
        end++;
      }
    }
    final before = card.allMatches(a.substring(0, start)).length;
    _links.removeRange(
      before,
      before + card.allMatches(a.substring(start, end)).length,
    );

    var text = a.substring(0, start) + inserted + a.substring(end);
    var cursor = _cursorAfter(
      next.selection.extentOffset,
      editStart: p,
      editEnd: b.length - s,
      tailLost: end - (a.length - s),
      start: start,
      inserted: inserted.length,
    );

    // A link pasted, or a return after one, makes it a card.
    var under = false;
    if (inserted.length > 1 || inserted == '\n') {
      final from = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
      var to = text.indexOf('\n', start + inserted.length);
      if (to < 0) to = text.length;
      var at = card.allMatches(text.substring(0, from)).length;
      final lines = <String>[];
      var offset = from;
      for (final line in text.substring(from, to).split('\n')) {
        final url = line.trim();
        if (_link.hasMatch(url)) {
          _links.insert(at++, url);
          lines.add(card);
          if (cursor > offset + line.length) {
            cursor -= line.length - 1;
          } else if (cursor >= offset) {
            // The cursor goes under the card, once it has its line.
            cursor = offset + 1;
            under = true;
          }
          offset += 2;
        } else {
          at += card.allMatches(line).length;
          lines.add(line);
          offset += line.length + 1;
        }
      }
      text = text.substring(0, from) + lines.join('\n') + text.substring(to);
    }

    // A card has its row to itself, and a line under it to type on.
    final out = StringBuffer();
    var moved = cursor;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == card && i > 0 && text[i - 1] != '\n') {
        out.write('\n');
        if (cursor >= i) moved++;
      }
      out.write(c);
      if (c == card && (i + 1 == text.length || text[i + 1] != '\n')) {
        out.write('\n');
        if (cursor > i) moved++;
      }
    }
    text = out.toString();
    cursor = moved.clamp(0, text.length);
    if (under && cursor > 0 && text[cursor - 1] == card) cursor++;

    if (text == b && cursor == next.selection.extentOffset) return next;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  /// Where a cursor at [offset] in the edited text lands once the edit is
  /// widened to whole cards.
  static int _cursorAfter(
    int offset, {
    required int editStart,
    required int editEnd,
    required int tailLost,
    required int start,
    required int inserted,
  }) {
    if (offset < 0) return start + inserted;
    if (offset <= editStart) return math.min(offset, start);
    if (offset < editEnd) return start + math.min(offset - editStart, inserted);
    return start + inserted + math.max(0, offset - editEnd - tailLost);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final live = _live;
    final hasLive = live != null && live.isValid && live.end <= text.length;
    if (!hasLive && _links.isEmpty) {
      return super.buildTextSpan(
        context: context,
        withComposing: withComposing,
        style: style,
      );
    }

    final caret = selection.isCollapsed ? selection.baseOffset : -1;
    final children = <InlineSpan>[];
    var from = 0;
    var link = 0;
    void words(int to) {
      if (to <= from) return;
      if (!hasLive || live.end <= from || live.start >= to) {
        children.add(TextSpan(text: text.substring(from, to)));
        return;
      }
      final liveFrom = math.max(live.start, from);
      final liveTo = math.min(live.end, to);
      children.addAll([
        TextSpan(text: text.substring(from, liveFrom)),
        TextSpan(
          text: text.substring(liveFrom, liveTo),
          style: const TextStyle(color: AppColors.ink3),
        ),
        TextSpan(text: text.substring(liveTo, to)),
      ]);
    }

    for (var i = text.indexOf(card); i >= 0; i = text.indexOf(card, i + 1)) {
      words(i);
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
            child: _Line(
              child: AppLinkCard(
                url: _links[link++],
                selected: caret == i + 1,
              ),
            ),
          ),
        ),
      );
      from = i + 1;
    }
    words(text.length);
    return TextSpan(style: style, children: children);
  }
}

/// As wide as the line a card stands on, short of the room the field keeps
/// for the caret: a placeholder any wider would not fit its line, and the
/// paragraph would lay the text around it out of place.
class _Line extends SingleChildRenderObjectWidget {
  const _Line({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLine();
}

class _RenderLine extends RenderProxyBox {
  static const double _caretRoom = AppSpacing.s1;

  BoxConstraints _inner(BoxConstraints constraints) => constraints.tighten(
    width: math.max(0, constraints.maxWidth - _caretRoom),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      child?.getDryLayout(_inner(constraints)) ?? Size.zero;

  @override
  void performLayout() {
    final child = this.child!
      ..layout(_inner(constraints), parentUsesSize: true);
    size = child.size;
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
