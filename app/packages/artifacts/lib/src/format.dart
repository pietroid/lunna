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

/// What a goal is called on its card: `Faturamento · outubro`.
String goalLabel(AppLocalizations l10n, Goal goal) {
  final what = goal.kind == GoalKind.money
      ? l10n.goalRevenue
      : goal.type?.name ?? l10n.artifactLoose;
  return goal.period == GoalPeriod.month
      ? l10n.goalInMonth(what, monthName(l10n, goal.start))
      : l10n.goalThisWeek(what);
}

/// A goal's number: reais for money, a plain count otherwise.
String goalAmount(Goal goal, int amount) =>
    goal.kind == GoalKind.money ? formatMoney(amount) : '$amount';
