import 'package:l10n/l10n.dart';
import 'package:timeline/src/models/models.dart';

/// The words the screen uses for the enums the API speaks in.
extension TimelineLabels on AppLocalizations {
  /// The heading of [section].
  String sectionLabel(TimelineSection section) => switch (section) {
    TimelineSection.agora => sectionNow,
    TimelineSection.hoje => sectionToday,
    TimelineSection.amanha => sectionTomorrow,
  };

  /// What a routine's [days] are called.
  String routineDaysLabel(RoutineDays days) => switch (days) {
    RoutineDays.daily => routineDaily,
    RoutineDays.weekdays => routineWeekdays,
    RoutineDays.weekend => routineWeekend,
  };
}
