import 'package:l10n/l10n.dart';

/// "14:30". The same on every locale the app speaks.
String hhmm(DateTime at) {
  return '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
}

/// "45 min", "1h", "1h30".
String durationLabel(AppLocalizations l10n, int minutes) {
  if (minutes < 60) return l10n.durationMinutes(minutes);

  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0
      ? l10n.durationHours(hours)
      : l10n.durationHoursMinutes(hours, rest);
}

/// The start of [notes] as a card on the calendar reads it: the first line
/// that says something, with a link on a line of its own skipped (it is
/// drawn as a card on the page, and an address says nothing at a glance).
/// Empty when there is nothing to read.
String notesPreview(String notes) {
  for (final raw in notes.split('\n')) {
    final line = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (line.isEmpty) continue;
    if (RegExp(r'^https?://\S+$').hasMatch(line)) continue;
    return line;
  }
  return '';
}
