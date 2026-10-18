import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const String _c = LiveTextController.card;
const _url = 'https://youtu.be/abc';

void main() {
  group('LiveTextController links', () {
    test('a link on its own line is a card, and the notes keep the link', () {
      final notes = LiveTextController(text: 'Ver isto:\n$_url\ndepois');
      expect(notes.text, 'Ver isto:\n$_c\ndepois');
      expect(notes.notes, 'Ver isto:\n$_url\ndepois');
    });

    test('a link inside a sentence stays text', () {
      final notes = LiveTextController(text: 'ver $_url hoje');
      expect(notes.text, 'ver $_url hoje');
    });

    test('pasting a link makes a card and moves under it', () {
      final notes = LiveTextController(text: 'Ver isto:\n')
        ..value = const TextEditingValue(
          text: 'Ver isto:\n$_url',
          selection: TextSelection.collapsed(offset: 10 + _url.length),
        );
      expect(notes.text, 'Ver isto:\n$_c\n');
      expect(notes.selection.baseOffset, notes.text.length);
      expect(notes.notes, 'Ver isto:\n$_url\n');
    });

    test('a link pasted inside a sentence stays text', () {
      final notes = LiveTextController(text: 'abcd')
        ..value = const TextEditingValue(
          text: 'ab${_url}cd',
          selection: TextSelection.collapsed(offset: 2 + _url.length),
        );
      expect(notes.text, 'ab${_url}cd');
    });

    test('typing a link by hand waits for return', () {
      final notes = LiveTextController(text: 'https://')
        ..value = const TextEditingValue(
          text: 'https://a',
          selection: TextSelection.collapsed(offset: 9),
        );
      expect(notes.text, 'https://a');
      notes.value = const TextEditingValue(
        text: 'https://a\n',
        selection: TextSelection.collapsed(offset: 10),
      );
      expect(notes.text, '$_c\n');
      expect(notes.notes, 'https://a\n');
      expect(notes.selection.baseOffset, 2);
    });

    test('backspace right after a card takes it and its line', () {
      final notes = LiveTextController(text: 'a\n$_url\nb')
        ..value = const TextEditingValue(
          text: 'a\n\nb',
          selection: TextSelection.collapsed(offset: 2),
        );
      expect(notes.text, 'a\nb');
      expect(notes.notes, 'a\nb');
      expect(notes.selection.baseOffset, 2);
    });

    test('backspace at the start of the line under a card takes the card', () {
      final notes = LiveTextController(text: 'a\n$_url\nb')
        ..value = const TextEditingValue(
          text: 'a\n${_c}b',
          selection: TextSelection.collapsed(offset: 3),
        );
      expect(notes.text, 'a\nb');
      expect(notes.selection.baseOffset, 2);
    });

    test('typing beside a card moves to a line of its own', () {
      final notes = LiveTextController(text: '$_url\n')
        ..value = const TextEditingValue(
          text: '${_c}x\n',
          selection: TextSelection.collapsed(offset: 2),
        );
      expect(notes.text, '$_c\nx\n');
      expect(notes.selection.baseOffset, 3);
    });

    test('deleting the second of two cards keeps the first', () {
      final notes = LiveTextController(text: '$_url\nhttps://b.c\nfim')
        ..value = const TextEditingValue(
          text: '$_c\n\nfim',
          selection: TextSelection.collapsed(offset: 2),
        );
      expect(notes.notes, '$_url\nfim');
    });

    test('dictation appends after a card', () {
      final notes = LiveTextController(text: 'a\n$_url\n')
        ..write('a\n$_c\n\nfalado', live: const TextRange(start: 5, end: 11));
      expect(notes.notes, 'a\n$_url\n\nfalado');
    });
  });
}
