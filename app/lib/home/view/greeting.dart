import 'package:l10n/l10n.dart';

/// "Bom dia Pietro!", or without the name when there is not one yet.
String greeting(AppLocalizations l10n, DateTime now, String? firstName) {
  final part = switch (now.hour) {
    >= 5 && < 12 => l10n.greetingMorning,
    >= 12 && < 18 => l10n.greetingAfternoon,
    _ => l10n.greetingEvening,
  };

  return firstName == null
      ? l10n.greetingAlone(part)
      : l10n.greetingWithName(part, firstName);
}

/// "Quarta-feira, 27 de agosto", capitalised the way a heading is.
String longDate(AppLocalizations l10n, DateTime at) {
  final date = l10n.longDate(at);
  if (date.isEmpty) return date;

  return date[0].toUpperCase() + date.substring(1);
}
