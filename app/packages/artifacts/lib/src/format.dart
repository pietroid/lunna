import 'package:app_ui/app_ui.dart';
import 'package:artifacts/src/models/models.dart';
import 'package:l10n/l10n.dart';

/// Whole reais as Brazilians write them: `R$ 4.900`.
String formatMoney(int reais) {
  final digits = reais.abs().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }
  return 'R\$ ${reais < 0 ? '-' : ''}$grouped';
}

/// A length of time as the timeline writes it: `45 min`, `2h`, `1h30`.
String formatMinutes(AppLocalizations l10n, int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return l10n.durationMinutes(rest);
  if (rest == 0) return l10n.durationHours(hours);
  return l10n.durationHoursMinutes(hours, rest);
}

/// The month's name, in lower case: `outubro`.
String monthName(AppLocalizations l10n, DateTime day) =>
    l10n.monthsLong.split(',')[day.month - 1];

/// The short day, as the rest of the app writes it: `sex, 23 out`.
String dayName(AppLocalizations l10n, DateTime day, DateTime now) =>
    AppWheelPicker.dayLabel(l10n, day, now: now).toLowerCase();

/// The day and month alone: `30 nov`.
String shortDay(AppLocalizations l10n, DateTime day) =>
    '${day.day} ${l10n.monthsShort.split(',')[day.month - 1]}';

/// What a goal is called wherever it is named: `Faturar R$ 10.000 até 30
/// nov`.
String goalLabel(AppLocalizations l10n, Goal goal) => l10n.goalMoneyLabel(
  formatMoney(goal.target),
  shortDay(l10n, goal.lastDay),
);

/// A goal's number: reais for money, a plain count otherwise.
String goalAmount(Goal goal, int amount) =>
    goal.kind == GoalKind.money ? formatMoney(amount) : '$amount';
