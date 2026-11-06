// dart format off
// coverage:ignore-file

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Lunna';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignInWithGoogle => 'Sign in with Google';

  @override
  String get authSignInFailed => 'Couldn\'t sign in';

  @override
  String get shellTimelineTab => 'Time';

  @override
  String get shellMenuTab => 'Menu';

  @override
  String get menuRoutinesHint => 'The blocks that repeat';

  @override
  String get menuDaySection => 'Your day';

  @override
  String get menuArchive => 'Done';

  @override
  String get menuArchiveHint => 'Everything you\'ve finished';

  @override
  String get archiveSearch => 'Search what\'s done';

  @override
  String get archiveToday => 'Today';

  @override
  String get archiveYesterday => 'Yesterday';

  @override
  String get archiveEmpty => 'Nothing finished yet. What you mark as done is kept here.';

  @override
  String get archiveNoMatch => 'No finished task with those words.';

  @override
  String get archiveFailed => 'Couldn\'t open what\'s done right now.';

  @override
  String get archiveRetry => 'Try again';

  @override
  String get menuDayStart => 'Starts at';

  @override
  String get menuDayEnd => 'Ends at';

  @override
  String get menuDayHelp => 'Nothing joins the queue outside these hours.';

  @override
  String get menuDayTooShort => 'The day has to end at least an hour after it starts.';

  @override
  String get shellWriteDown => 'Write down';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String greetingAlone(String part) {
    return '$part!';
  }

  @override
  String greetingWithName(String part, String name) {
    return '$part, $name!';
  }

  @override
  String longDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMMEEEEd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get homeRoutines => 'Routine';

  @override
  String get homeSignOut => 'Sign out';

  @override
  String get commonCancel => 'Cancel';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '${hours}h';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '${hours}h$minutes';
  }

  @override
  String confirmDeleteTitle(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get confirmDeleteBody => 'It leaves the calendar for good.';

  @override
  String get confirmDeleteTaskBody => 'It leaves your list for good.';

  @override
  String get confirmDeleteSubtaskBody => 'It leaves this list and the calendar for good.';

  @override
  String get confirmDeleteAction => 'Delete';

  @override
  String confirmDoneTitle(String title) {
    return 'Finish “$title”?';
  }

  @override
  String get confirmDoneBody => 'It leaves the list and goes to Done.';

  @override
  String get confirmDoneAction => 'Finish';

  @override
  String confirmDeliverTitle(String title) {
    return 'Deliver “$title”?';
  }

  @override
  String get confirmDeliverBody => 'It counts as delivered today, with its value.';

  @override
  String get confirmDeliverAction => 'Deliver';

  @override
  String get confirmShortenTitle => 'It doesn\'t fit here';

  @override
  String confirmShortenBody(String title, int duration, int minutes) {
    return '“$title” takes $duration min and this gap has room for $minutes min, counting the break. Shorten it to $minutes min?';
  }

  @override
  String confirmShortenAction(int minutes) {
    return 'Shorten to $minutes min';
  }

  @override
  String confirmMoreTitle(int minutes) {
    return '$minutes more minutes?';
  }

  @override
  String confirmLessTitle(int minutes) {
    return '$minutes fewer minutes?';
  }

  @override
  String confirmMoreBody(String title, String end) {
    return '“$title” now ends at $end. What comes after moves with it.';
  }

  @override
  String confirmLessBody(String title, String end) {
    return '“$title” now ends at $end. What comes after moves up.';
  }

  @override
  String get confirmMoreAction => 'Add';

  @override
  String get confirmLessAction => 'Take off';

  @override
  String get eventUntitled => 'Untitled';

  @override
  String get eventStartsNow => 'Starts now';

  @override
  String eventStartsIn(int minutes) {
    return 'Starts in $minutes min';
  }

  @override
  String eventStartsAt(String time) {
    return 'Starts at $time';
  }

  @override
  String eventStartsTomorrowAt(String time) {
    return 'Tomorrow at $time';
  }

  @override
  String eventTomorrowAt(String time) {
    return 'tomorrow $time';
  }

  @override
  String eventDayAt(int day, int month, String time) {
    return '$month/$day $time';
  }

  @override
  String get eventGone => 'This block is no longer in the day.';

  @override
  String get eventNotesHint => 'Notes';

  @override
  String get eventWhenLabel => 'Time';

  @override
  String get eventLengthLabel => 'Length';

  @override
  String get eventArtifactLabel => 'Delivery';

  @override
  String get eventNoArtifact => 'None';

  @override
  String get restTip01 => 'Take a deep breath. Three times, slowly.';

  @override
  String get restTip02 => 'Stand up, stretch your back and look out the window.';

  @override
  String get restTip03 => 'Drink a glass of water before you go on.';

  @override
  String get restTip04 => 'Close your eyes for a minute. That\'s all.';

  @override
  String get restTip05 => 'Empty your head. The next step can wait.';

  @override
  String get restTip06 => 'Drop your shoulders. They were tense, weren\'t they?';

  @override
  String get restTip07 => 'Look at something far away. Your eyes will thank you.';

  @override
  String get restTip08 => 'Nothing to solve right now. Enjoy it.';

  @override
  String get restTip09 => 'Walk a little, even if just to the kitchen.';

  @override
  String get restTip10 => 'A minute of silence. No screen.';

  @override
  String get restTip11 => 'Notice what you can hear right now.';

  @override
  String get restTip12 => 'You finished something. Take that in.';

  @override
  String get restTip13 => 'Breathe in for four, hold for four, let go for four.';

  @override
  String get restTip14 => 'Switch your mind off. It comes back better.';

  @override
  String get restTip15 => 'Move your hands, roll your wrists, relax your face.';

  @override
  String get restTip16 => 'A real break: no phone.';

  @override
  String get restTip17 => 'Feel your feet on the floor for a few seconds.';

  @override
  String get restTip18 => 'Resting is part of the work too.';

  @override
  String get restTip19 => 'Let the last thing go.';

  @override
  String get restTip20 => 'Meditate for a moment. Just breathe and notice.';

  @override
  String get freeNothingScheduled => 'Nothing scheduled';

  @override
  String get controlStart => 'Start';

  @override
  String get controlResume => 'Resume';

  @override
  String get controlPause => 'Pause';

  @override
  String get controlStartNow => 'Start now';

  @override
  String get controlLess10 => '10 min less';

  @override
  String get controlWait10 => 'Wait 10 min';

  @override
  String get controlMore10 => '10 min more';

  @override
  String get controlDone => 'Finish';

  @override
  String nowPausedLeft(String left) {
    return 'Paused · $left left';
  }

  @override
  String nowLeft(String left) {
    return '$left left';
  }

  @override
  String get sectionNow => 'Now';

  @override
  String get sectionToday => 'Later today';

  @override
  String get sectionTomorrow => 'Tomorrow';

  @override
  String sectionDay(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMMEEEEd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get timelineModeList => 'List';

  @override
  String get timelineModeCalendar => 'Calendar';

  @override
  String get stageBacklog => 'For later';

  @override
  String get stageBacklogEmpty => 'Nothing waiting. Drag here what has no place in the queue yet.';

  @override
  String get promptToBacklog => 'Leave for later';

  @override
  String get promptToQueue => 'Joins the queue, wherever there\'s room';

  @override
  String get promptPickTime => 'Pick a time';

  @override
  String get timelineAdd => 'Add';

  @override
  String get timelineBackToNow => 'Back to now';

  @override
  String get eventInBacklog => 'In For later, no time yet';

  @override
  String eventDoneOn(String day, String time) {
    return 'Done $day at $time';
  }

  @override
  String get routineDaily => 'Every day';

  @override
  String get routineWeekdays => 'Weekdays';

  @override
  String get routineWeekend => 'Weekend';

  @override
  String get failureUnreachable => 'Couldn\'t reach the server.';

  @override
  String failureRetry(String reason) {
    return '$reason Tap to try again.';
  }

  @override
  String get timelineEmpty => 'Nothing scheduled. Tap + to write something down.';

  @override
  String get pickerDurationTitle => 'How long does it take?';

  @override
  String get pickerTimeTitle => 'At what time?';

  @override
  String get pickerWhenTitle => 'When?';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get dayToday => 'Today';

  @override
  String get dayTomorrow => 'Tomorrow';

  @override
  String get weekdaysShort => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String get monthsShort => 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String dayShort(String weekday, int day, String month) {
    return '$weekday, $month $day';
  }

  @override
  String get promptHint01 => 'What needs doing?';

  @override
  String get promptHint02 => 'What are we working on?';

  @override
  String get promptHint03 => 'What goes in the day?';

  @override
  String get promptHint04 => 'Where do we start?';

  @override
  String get promptHint05 => 'What\'s on your mind?';

  @override
  String get promptHint06 => 'Tell me what you need.';

  @override
  String get promptHint07 => 'What\'s next?';

  @override
  String get promptHint08 => 'What do we get done today?';

  @override
  String get promptHint09 => 'Write it here.';

  @override
  String get promptHint10 => 'Go ahead.';

  @override
  String get promptFlexible => 'Flexible';

  @override
  String get promptFixed => 'Fixed';

  @override
  String promptAtOnDay(String time, String day) {
    return '$time, $day';
  }

  @override
  String formatMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String formatHours(int hours) {
    return '$hours h';
  }

  @override
  String formatHoursMinutes(int hours, String minutes) {
    return '${hours}h$minutes';
  }

  @override
  String get notificationChannelBlocks => 'Blocks';

  @override
  String get notificationChannelBlocksDescription => 'When a block starts and when it ends, with a button to answer.';

  @override
  String get notificationActionConfirm => 'Confirm';

  @override
  String get notificationActionLater => '+10 min';

  @override
  String get notificationActionTalk => 'Talk to Lunna';

  @override
  String get notificationChannelDaily => 'Good morning and good night';

  @override
  String get notificationChannelDailyDescription => 'A note at the start and the end of the day.';

  @override
  String get notificationSuggestionTitle => 'Lunna sent you a message';

  @override
  String get notificationSuggestionBody => 'I have an idea for the next step. Want to see?';

  @override
  String get remindersAskTitle => 'Want reminders?';

  @override
  String get remindersAskBody => 'I ask when a block starts and when it ends, and tapping the reminder opens the question here. And I send a good morning and a good night.';

  @override
  String get remindersEnable => 'Turn on reminders';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get reminderStarting => 'Starting now, right?';

  @override
  String get reminderEnding => 'Ending now, right?';

  @override
  String reminderHours(String start, String end) {
    return '$start–$end';
  }

  @override
  String lateEnd(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'Running late · $_temp0';
  }

  @override
  String get reminderFinished => 'I\'m done';

  @override
  String get reminderDelay10 => 'Snooze 10 min';

  @override
  String get routinesHelp => 'Tap a time to create one. Hold a block to change its time.';

  @override
  String get routinesTitleHint => 'Lunch, morning routine…';

  @override
  String get commonSave => 'Save';

  @override
  String get routinesDelete => 'Delete routine';

  @override
  String get routinesNew => 'New routine';

  @override
  String get landingHeadline => 'Say what you need. The day sorts itself out.';

  @override
  String get landingPitch => 'Lunna is a calendar you talk to. Ask in writing or out loud and she proposes the changes to your day: you see the plan and apply it, or not. And what you deliver, with a deadline and a value, becomes tasks on the same day.';

  @override
  String get landingDemoHint => 'The phone beside this is the real app, with a sample day. Tap, drag and ask.';

  @override
  String get landingChapterAskTitle => 'Ask';

  @override
  String get landingChapterAskText => 'Write or say what you need. Lunna reads your day, builds a plan and waits for your yes.';

  @override
  String get landingChapterTimeTitle => 'Time';

  @override
  String get landingChapterTimeText => 'The day as a queue: each thing at its time, and when something runs late the rest moves with it.';

  @override
  String get landingChapterDeliveriesTitle => 'Deliveries';

  @override
  String get landingChapterDeliveriesText => 'What you owe someone, with a deadline and a value. The month\'s goal, and the hours the deliveries ask for against the hours the calendar has free.';

  @override
  String get landingTry => 'Try asking';

  @override
  String get landingMoreTitle => 'Also in the app';

  @override
  String get landingPartRoutinesTitle => 'Routines';

  @override
  String get landingPartRoutinesText => 'Blocks that come back every day, on weekdays or at the weekend, always at the same time.';

  @override
  String get landingPartRemindersTitle => 'Reminders';

  @override
  String get landingPartRemindersText => 'A nudge when it\'s time to start, another near the end, and a good morning and a good night.';

  @override
  String get landingPartVoiceTitle => 'Voice';

  @override
  String get landingPartVoiceText => 'Hold the microphone to ask, or dictate straight into a task\'s notes.';

  @override
  String get landingDayTitle => 'Day to day';

  @override
  String get landingUseAsk => 'Ask, and see the plan before applying it.';

  @override
  String get landingUseHour => 'Give each thing its time.';

  @override
  String get landingUsePause => 'Pause, extend or postpone, and the rest of the day moves with it.';

  @override
  String get landingUseDeliver => 'Close a delivery and watch the goal move.';

  @override
  String get landingPrivacy => 'We record the app\'s use and errors to improve it. Text and images never leave your device in the recordings.';

  @override
  String get landingFooter => 'Lunna · Personal organization';

  @override
  String get demoBuilding => 'Building Lunna';

  @override
  String get demoGroceries => 'Buy milk and eggs';

  @override
  String get demoBacklog => 'Sort the trip photos';

  @override
  String get demoStandup => 'Standup';

  @override
  String get demoDentist => 'Book the dentist';

  @override
  String get demoAskStudy => 'Fit 2h of study tomorrow morning and take the trip photos out of Later';

  @override
  String get demoAskDelivery => 'Create the delivery of Carla\'s chart for Friday';

  @override
  String get demoReplyStudy => 'After the dentist, at 9:30, the morning is free. Like this:';

  @override
  String get demoReplyDelivery => 'A birth chart takes 3 h, in 1 h blocks. Like this:';

  @override
  String get demoStepLooked => 'Looked at tomorrow';

  @override
  String get demoStepFree => 'Found 09:35–12:00 free';

  @override
  String get demoStepCatalogue => 'Birth chart in the catalogue: 3 h, R\$ 350';

  @override
  String get demoStudy => 'Study for the exam';

  @override
  String get demoTypeChart => 'Birth chart';

  @override
  String get demoTypePost => 'Post';

  @override
  String get demoShelfSessions => 'Sessions';

  @override
  String get demoShelfContent => 'Content';

  @override
  String get demoDeliveryCarla => 'Birth chart · Carla';

  @override
  String get demoDeliveryRenata => 'Birth chart · Renata';

  @override
  String get demoDeliveryPost => 'Post: Full moon in Taurus';

  @override
  String get demoDeliveryJulia => 'Birth chart · Júlia';

  @override
  String get demoDeliveryPedro => 'Birth chart · Pedro';

  @override
  String get agentAsk => 'Ask Lunna…';

  @override
  String get agentSuggestionLabel => 'Lunna\'s suggestion';

  @override
  String get agentInputHint => 'Ask or request something…';

  @override
  String get agentReplyHint => 'Reply…';

  @override
  String get agentThinking => 'Looking at your day…';

  @override
  String get agentSend => 'Send';

  @override
  String get agentClose => 'Close';

  @override
  String get agentApply => 'Apply';

  @override
  String get agentAdjust => 'Adjust';

  @override
  String get agentApplied => 'Applied';

  @override
  String agentChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return '$_temp0';
  }

  @override
  String get agentChangeAddTask => 'new task';

  @override
  String get agentChangeAddEvent => 'new fixed block';

  @override
  String get agentChangeMoved => 'moved';

  @override
  String get agentChangeRoutine => 'routine, that day only';

  @override
  String get agentChangeFromBacklog => 'out of For later';

  @override
  String get agentUndo => 'Undo';

  @override
  String get agentEarlier => 'Earlier conversations';

  @override
  String get agentEarlierFailed => 'Couldn\'t load the earlier conversations. Tap to try again.';

  @override
  String agentHistoryToday(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat('HH:mm', localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Today · $timeString';
  }

  @override
  String agentHistoryYesterday(DateTime day, DateTime time) {
    final intl.DateFormat dayDateFormat = intl.DateFormat.EEEE(localeName);
    final String dayString = dayDateFormat.format(day);
    final intl.DateFormat timeDateFormat = intl.DateFormat('HH:mm', localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Yesterday, $dayString · $timeString';
  }

  @override
  String agentHistoryDay(DateTime day, DateTime time) {
    final intl.DateFormat dayDateFormat = intl.DateFormat.MMMEd(localeName);
    final String dayString = dayDateFormat.format(day);
    final intl.DateFormat timeDateFormat = intl.DateFormat('HH:mm', localeName);
    final String timeString = timeDateFormat.format(time);

    return '$dayString · $timeString';
  }

  @override
  String agentHistoryNow(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat('HH:mm', localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Now · $timeString';
  }

  @override
  String agentPlanSummary(String changes, String status) {
    return '$changes · $status';
  }

  @override
  String get agentPlanApplied => 'applied';

  @override
  String get agentPlanUndone => 'undone';

  @override
  String get agentPlanNotApplied => 'not applied';

  @override
  String agentPushedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pushed',
      one: '1 pushed',
    );
    return '$_temp0';
  }

  @override
  String get agentChangePushed => 'pushed';

  @override
  String get agentPush => 'Move';

  @override
  String get agentOtherTime => 'Another time';

  @override
  String get agentOtherTimeDraft => 'I\'d rather another time: ';

  @override
  String get agentSuggestionDismiss => 'Not now';

  @override
  String get agentSuggestionAccept => 'Accept';

  @override
  String get agentSuggestionAdjust => 'Adjust';

  @override
  String get agentWelcome => 'Hi! I\'m Lunna. I\'ll help you plan your month, one step at a time, starting with the goal.';

  @override
  String get agentWelcomeQuestion => 'How much do you want to bill this month?';

  @override
  String agentWelcomeAmount(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'R\$ $amountString';
  }

  @override
  String agentWelcomeSay(int amount) {
    final intl.NumberFormat amountNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String amountString = amountNumberFormat.format(amount);

    return 'I want to bill R\$ $amountString this month.';
  }

  @override
  String get agentWelcomeOther => 'Another amount';

  @override
  String agentPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items in the list',
      one: '1 item in the list',
    );
    return '$_temp0';
  }

  @override
  String get agentFailure => 'Something went wrong. Try again.';

  @override
  String get agentFailureModelDown => 'Couldn\'t reach the model right now, even after two tries.';

  @override
  String get agentFailureModelEmpty => 'The model answered blank, twice.';

  @override
  String get agentFailureDrift => 'Your day changed since this plan and it no longer fits. Ask again.';

  @override
  String get agentFailureOffline => 'No connection to the server.';

  @override
  String get agentFailureBug => 'Something went wrong on my side. It was logged.';

  @override
  String get agentRetry => 'Try again';

  @override
  String get agentDetails => 'Details';

  @override
  String agentTrace(String id) {
    return 'Code $id';
  }

  @override
  String agentPlaceBetween(String after, String before) {
    return 'between $after and $before';
  }

  @override
  String agentPlaceAfter(String after) {
    return 'after $after';
  }

  @override
  String agentPlaceBefore(String before) {
    return 'before $before';
  }

  @override
  String get agentPlaceEnd => 'at the end of the queue';

  @override
  String agentAssumed(String what) {
    return 'I assumed $what';
  }

  @override
  String get agentAssumedToday => 'it\'s for today';

  @override
  String get agentAssumedEnd => 'the end of the queue';

  @override
  String get agentVoiceStart => 'Speak';

  @override
  String get agentVoiceListening => 'Listening';

  @override
  String get agentVoiceStopped => 'Stopped listening at the 1-minute limit';

  @override
  String get agentVoiceHint => 'Go ahead. I write while you talk.';

  @override
  String get agentVoiceDiscard => 'Discard';

  @override
  String get agentVoiceStop => 'Stop and review';

  @override
  String get agentVoiceOpen => 'Open the conversation';

  @override
  String get agentVoiceSlideCancel => 'Slide to cancel';

  @override
  String get agentVoiceLock => 'Record hands-free';

  @override
  String get agentVoiceSend => 'Send';

  @override
  String agentVoiceVia(String length) {
    return 'by voice · $length';
  }

  @override
  String get agentVoiceDenied => 'Lunna has no access to the microphone. Allow it in the device\'s Settings.';

  @override
  String get agentVoiceUnavailable => 'This device doesn\'t recognize speech in Portuguese.';

  @override
  String get artifactUntitled => 'Unnamed';

  @override
  String get artifactNoDeadline => 'No deadline';

  @override
  String get artifactGiveDeadline => 'Set a deadline';

  @override
  String artifactUntil(String date) {
    return 'by $date';
  }

  @override
  String artifactDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'due today',
    );
    return '$_temp0';
  }

  @override
  String artifactOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days late',
      one: '1 day late',
    );
    return '$_temp0';
  }

  @override
  String artifactDoneOn(String date) {
    return 'delivered $date';
  }

  @override
  String get artifactMinusDay => '−1 day';

  @override
  String get artifactPlusDay => '+1 day';

  @override
  String get artifactLessDay => 'One day less';

  @override
  String get artifactMoreDay => 'One day more';

  @override
  String artifactPendingTab(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pending · $count',
      zero: 'Pending',
    );
    return '$_temp0';
  }

  @override
  String artifactDoneTab(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Done · $count',
      zero: 'Done',
    );
    return '$_temp0';
  }

  @override
  String get artifactDoneEmpty => 'Nothing done yet. What you finish of this delivery stays here.';

  @override
  String get artifactNotesTab => 'Notes';

  @override
  String get artifactDeadlineLabel => 'Deadline';

  @override
  String get artifactNotesHint => 'Write anything about the delivery…';

  @override
  String artifactTasksDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count done',
      one: '1 done',
    );
    return '$_temp0';
  }

  @override
  String get artifactDeleteBody => 'The tasks in For later go with it. The ones that already have a time, and the done ones, stay in Time.';

  @override
  String dayOverTitle(String end) {
    return 'Your day ended at $end';
  }

  @override
  String dayOverBody(String start) {
    return 'Nothing starts now. The queue moves again tomorrow at $start.';
  }

  @override
  String dayNotYetTitle(String start) {
    return 'Your day starts at $start';
  }

  @override
  String get dayNotYetBody => 'Nothing starts before then. Until then, rest.';

  @override
  String get dayClosedAdjust => 'Change hours';

  @override
  String get dayClosedRefused => 'Not now: your day is over';

  @override
  String get vacatedTitle => 'Free from now';

  @override
  String get vacatedBody => 'Drop to pause: it goes back to the queue with what\'s left.';

  @override
  String dragHintPause(String left) {
    return 'Pause · back with $left';
  }

  @override
  String dragHintShift(String delta, String hour) {
    return '$delta · $hour';
  }

  @override
  String dragHintResize(String delta, String hour) {
    return '$delta · until $hour';
  }

  @override
  String dragHintTomorrowAt(String hour) {
    return 'tomorrow $hour';
  }

  @override
  String minutesDelta(String sign, String minutes) {
    return '$sign$minutes min';
  }

  @override
  String dragHintSwapWith(String title) {
    return 'Swap with $title';
  }

  @override
  String dragHintMoveTo(String when) {
    return 'To $when';
  }

  @override
  String get dictationStart => 'Dictate into the notes';

  @override
  String get dictationStop => 'Stop dictating';

  @override
  String get dictationDiscard => 'Discard this paragraph';

  @override
  String get agentApplyDelete => 'Delete';

  @override
  String get agentChangeRenamed => 'new name';

  @override
  String get agentChangeLength => 'length';

  @override
  String get agentChangeNotes => 'notes';

  @override
  String get agentChangeDone => 'done';

  @override
  String get agentChangeRemove => 'delete';

  @override
  String get agentChangeNewArtifact => 'new delivery';

  @override
  String get agentChangeDeadline => 'deadline';

  @override
  String get agentChangeArtifactDone => 'delivered';

  @override
  String agentChangeRemoveArtifact(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'delete the delivery and $count tasks',
      one: 'delete the delivery and 1 task',
      zero: 'delete the delivery',
    );
    return '$_temp0';
  }

  @override
  String agentChangeOpenLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks still open',
      one: '1 task still open',
    );
    return '$_temp0';
  }

  @override
  String agentChangeArtifactBefore(String title) {
    return 'in the queue, before $title';
  }

  @override
  String agentChangeArtifactAfter(String title) {
    return 'in the queue, after $title';
  }

  @override
  String get agentChangeNewKind => 'new kind';

  @override
  String get agentChangeNewGoal => 'new goal';

  @override
  String get agentChangeNewRoutine => 'new routine';

  @override
  String get agentChangeEditRoutine => 'routine';

  @override
  String get agentChangeWorkDay => 'Working day';

  @override
  String get agentChangeEditGoal => 'goal';

  @override
  String get agentChangeRemoveGoal => 'delete the goal';

  @override
  String agentGoalPerWeek(String amount) {
    return '$amount a week';
  }

  @override
  String agentGoalPerMonth(String amount) {
    return '$amount a month';
  }

  @override
  String agentFree(String span) {
    return '$span free';
  }

  @override
  String agentCardsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    return '$_temp0';
  }

  @override
  String agentArtifactDone(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get agentArtifactNext => 'Next';

  @override
  String agentArtifactMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more',
      one: '1 more',
    );
    return '$_temp0';
  }

  @override
  String get agentArtifactOpen => 'Open delivery';

  @override
  String get shellArtifactsTab => 'Deliveries';

  @override
  String get monthsLong => 'January,February,March,April,May,June,July,August,September,October,November,December';

  @override
  String get artifactsSearch => 'Search deliveries';

  @override
  String get artifactsSearchHint => 'Search by name, client or kind';

  @override
  String goalOf(String target) {
    return 'of $target';
  }

  @override
  String goalDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'ends today',
    );
    return '$_temp0';
  }

  @override
  String goalStartsOn(String date) {
    return 'starts $date';
  }

  @override
  String get artifactsAll => 'All';

  @override
  String artifactsSeeAll(int count) {
    return 'See all $count';
  }

  @override
  String get artifactsAllTitle => 'All deliveries';

  @override
  String get artifactsInQueue => 'In the queue';

  @override
  String get artifactsDone => 'Done';

  @override
  String artifactsDoneOn(String date) {
    return 'done $date';
  }

  @override
  String artifactsNoResults(String query) {
    return 'Nothing with “$query”.';
  }

  @override
  String get artifactsNew => 'New delivery';

  @override
  String get artifactLoose => 'One-off';

  @override
  String artifactDue(String date) {
    return 'by $date';
  }

  @override
  String artifactTimeDone(String done, String total) {
    return '$done of $total';
  }

  @override
  String artifactSteps(int done, int total) {
    return '$done of $total steps';
  }

  @override
  String artifactBlocks(String block) {
    return 'in blocks of $block';
  }

  @override
  String get artifactSheetSearchHint => 'Birth chart, post, solar return…';

  @override
  String get artifactSheetLoose => 'A one-off delivery';

  @override
  String get artifactSheetLooseHint => 'No kind from the catalogue: you say how long it takes';

  @override
  String get catalogTitle => 'Catalogue';

  @override
  String get catalogEdit => 'Edit';

  @override
  String get catalogEmptyTitle => 'Your catalogue is empty';

  @override
  String get catalogEmptyBody => 'Create a kind for what you always deliver, like a birth chart or a post. It brings the time, the price and how to split it in the day.';

  @override
  String get catalogNewType => 'Create a kind';

  @override
  String get catalogEmptyLooseHint => 'You say how long it takes and what it\'s worth.';

  @override
  String get artifactNameHint => 'Delivery name';

  @override
  String get artifactChangeType => 'Change';

  @override
  String get artifactTotalTime => 'Total time';

  @override
  String artifactTimeFromType(String type) {
    return 'from the kind $type';
  }

  @override
  String get artifactSplit => 'In the day';

  @override
  String get artifactSplitWhole => 'Whole';

  @override
  String artifactSplitBlocks(String block) {
    return 'Blocks of $block';
  }

  @override
  String get artifactValue => 'Value';

  @override
  String get artifactDeadline => 'Deadline';

  @override
  String get artifactPlace => 'Joins the queue';

  @override
  String get artifactPlaceTop => 'At the top';

  @override
  String get artifactPlaceEnd => 'At the end';

  @override
  String get artifactCreate => 'Put in the queue';

  @override
  String get catalogAddType => 'New kind';

  @override
  String get typeNameHint => 'Kind name, like Birth chart';

  @override
  String get typeCategory => 'Category';

  @override
  String get typeNewCategory => 'New';

  @override
  String get typeCategoryHint => 'Category name, like Sessions';

  @override
  String get typeCreate => 'Save to the catalogue';

  @override
  String get valueOptional => 'optional';

  @override
  String get artifactKindLabel => 'Kind';

  @override
  String get artifactsEmpty => 'Nothing in the queue yet. The + puts a delivery in it.';

  @override
  String get artifactsNoneHere => 'Nothing in the queue with this filter.';

  @override
  String stageAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more tasks ahead',
      one: '1 more task ahead',
    );
    return '$_temp0';
  }

  @override
  String get stageAheadOpen => 'See in the calendar';

  @override
  String get stageAheadShow => 'See the next days';

  @override
  String get stageDayEmpty => 'Nothing with a time on this day. Drag a task here to give it a time.';

  @override
  String deliveryTasks(int count, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    return '$_temp0 · $time';
  }

  @override
  String get artifactsInProgress => 'In progress';

  @override
  String get artifactsNotStarted => 'Not started';

  @override
  String get artifactPaceOn => 'on pace';

  @override
  String get artifactPaceBehind => 'behind pace';

  @override
  String get artifactUrgent => 'Urgent';

  @override
  String artifactStartTitle(String title) {
    return 'Start $title';
  }

  @override
  String get artifactStartBody => 'It goes to In progress and its time starts running until the deadline. Until when?';

  @override
  String artifactStartInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String artifactStartInWeeks(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'In $weeks weeks',
      one: 'In 1 week',
    );
    return '$_temp0';
  }

  @override
  String get artifactStartOtherDay => 'Another day';

  @override
  String get artifactStartOtherDayHint => 'Pick in the calendar';

  @override
  String get artifactStart => 'Start';

  @override
  String get routineChecklistHint => 'A list? One item per line';

  @override
  String get eventChecklistLabel => 'List';

  @override
  String checklistCount(int done, int total) {
    return '$done of $total';
  }

  @override
  String get checklistAllDone => 'All done';

  @override
  String get shellGoalsTab => 'Goals';

  @override
  String get goalsNew => 'New goal';

  @override
  String get goalsEmptyTitle => 'How much do you want to bill?';

  @override
  String get goalsEmptyBody => 'A goal is an amount to reach by a day. It adds up the value of each delivery you deliver, and the bar says whether you\'re on pace.';

  @override
  String get goalsUpcoming => 'Upcoming';

  @override
  String get goalsPast => 'Past';

  @override
  String goalMoneyLabel(String amount, String date) {
    return '$amount by $date';
  }

  @override
  String goalRevenueBy(String date) {
    return 'By $date';
  }

  @override
  String goalAchieved(String amount) {
    return '$amount billed';
  }

  @override
  String goalExpected(String amount) {
    return '$amount by today';
  }

  @override
  String goalBehind(String amount) {
    return '$amount behind pace';
  }

  @override
  String goalAhead(String amount) {
    return '$amount ahead of pace';
  }

  @override
  String get goalOnPace => 'On pace';

  @override
  String goalQueuedLine(int count, String amount, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'With $count deliveries by $date, it gets to $amount',
      one: 'With 1 delivery by $date, it gets to $amount',
    );
    return '$_temp0';
  }

  @override
  String goalQueuedReaches(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'With $count deliveries by $date, it reaches the goal',
      one: 'With 1 delivery by $date, it reaches the goal',
    );
    return '$_temp0';
  }

  @override
  String get goalReached => 'Reached';

  @override
  String get goalSheetAmount => 'How much to bill';

  @override
  String get goalSheetBy => 'By when';

  @override
  String get goalByNextWeek => 'Next week';

  @override
  String get goalByNextMonth => 'Next month';

  @override
  String get goalByOther => 'Another date';

  @override
  String goalReadbackBy(String amount, String date) {
    return 'Bill $amount by $date.';
  }

  @override
  String goalReadbackFromToday(String amount) {
    return 'Counts what you deliver from today: about $amount a week.';
  }

  @override
  String goalReadbackFromDay(String date, String amount) {
    return 'Starts when the current one ends, $date: about $amount a week.';
  }

  @override
  String get goalCreateObjective => 'Create goal';

  @override
  String get goalDeleteObjectiveBody => 'The deliveries stay as they are; only the goal stops being measured.';

  @override
  String get artifactValueAdd => 'Add value';

  @override
  String get goalEditTitle => 'Edit goal';

  @override
  String get artifactValueClear => 'Remove value';

  @override
  String get artifactValueHint => 'What this delivery is worth. It counts toward the goals once it\'s delivered.';

  @override
  String goalReadbackSince(String date, String amount) {
    return 'Counts since $date: about $amount a week.';
  }

  @override
  String get shellFeedTab => 'Feed';

  @override
  String get shellPlanTab => 'Plan';

  @override
  String get planTasks => 'Tasks';

  @override
  String get feedNow => 'Now';

  @override
  String get feedNext => 'Up next';

  @override
  String get feedBreak => 'Nothing in progress';

  @override
  String get feedMainDelivery => 'Main delivery';

  @override
  String get feedNoDelivery => 'No delivery in progress';

  @override
  String get feedSeeDeliveries => 'Deliveries';

  @override
  String get feedMainGoal => 'Goal';

  @override
  String get feedNoGoal => 'No goal right now';

  @override
  String get feedSeeGoals => 'Goals';

  @override
  String get demoSuggestionRenata => 'Renata\'s chart is due the day after tomorrow and still needs 2 h. Shall I fit 45 min at 11:10, before the standup?';

  @override
  String get cyclePhaseMenstrual => 'Period';

  @override
  String get cyclePhaseFollicular => 'Follicular';

  @override
  String get cyclePhaseOvulatory => 'Ovulation';

  @override
  String get cyclePhaseLuteal => 'Luteal';

  @override
  String cycleDayPhase(int day, String phase) {
    return 'Cycle day $day · $phase';
  }

  @override
  String dayLightTag(String hours) {
    return 'Light day · $hours';
  }

  @override
  String get dayOffTag => 'Day off';

  @override
  String get dayOffWeekend => 'Weekend · day off';

  @override
  String get dayOffPeriod => 'Period · day off';

  @override
  String get dayOffDate => 'Day off set';

  @override
  String get menuCycle => 'Cycle';

  @override
  String get menuCycleHint => 'Log your period so the app can follow the phases';

  @override
  String menuCycleToday(int day, String phase) {
    return 'Day $day · $phase';
  }

  @override
  String get menuDaysOff => 'Days off';

  @override
  String get menuDaysOffHint => 'Weekends, holidays and light days';

  @override
  String get menuRestSection => 'Rhythm';

  @override
  String get cycleTitle => 'Cycle';

  @override
  String cycleTodayOf(int day, int length) {
    return 'Day $day of $length';
  }

  @override
  String cyclePhaseUntil(String phase, DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$phase until $dateString';
  }

  @override
  String cycleEffectLight(String hours) {
    return 'Light day: up to $hours of tasks, no deliveries.';
  }

  @override
  String get cycleEffectOff => 'Day off: nothing from the queue comes here.';

  @override
  String get cycleEffectWork => 'Normal working day.';

  @override
  String get cycleNext30 => 'Next 30 days';

  @override
  String get cycleSettings => 'Your cycle';

  @override
  String get cycleLastStart => 'Start of your last period';

  @override
  String get cycleLength => 'Cycle length';

  @override
  String get cyclePeriodLength => 'Period length';

  @override
  String cycleDays(int count) {
    return '$count days';
  }

  @override
  String get cyclePeriodKind => 'During the period';

  @override
  String get dayKindWork => 'Normal';

  @override
  String get dayKindLight => 'Light';

  @override
  String get dayKindOff => 'Day off';

  @override
  String get cycleStarted => 'Period started today';

  @override
  String get cycleHelp => 'The forecast counts the cycle length from the start of your last period. Tap a day in the grid to correct it.';

  @override
  String get daysOffTitle => 'Days off';

  @override
  String get daysOffWeekend => 'Weekend';

  @override
  String get daysOffSaturday => 'Saturday';

  @override
  String get daysOffSunday => 'Sunday';

  @override
  String get daysOffLight => 'Light day';

  @override
  String get daysOffLightBudget => 'Tasks on a light day';

  @override
  String get daysOffLightHelp => 'On a light day the queue puts only loose tasks, up to this limit. Delivery tasks wait for the next working day, and their deadline counts working days only.';

  @override
  String get daysOffDates => 'Upcoming days off';

  @override
  String cycleDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String daysOffEntry(DateTime date, String title) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMEd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString · $title';
  }

  @override
  String daysOffRange(DateTime from, DateTime to, String title) {
    final intl.DateFormat fromDateFormat = intl.DateFormat.d(localeName);
    final String fromString = fromDateFormat.format(from);
    final intl.DateFormat toDateFormat = intl.DateFormat.MMMd(localeName);
    final String toString = toDateFormat.format(to);

    return '$fromString to $toString · $title';
  }

  @override
  String get cycleWeekdays => 'S,M,T,W,T,F,S';

  @override
  String get dayLightShort => 'light day';

  @override
  String get dayOffShort => 'day off';

  @override
  String get dayOffWorkHere => 'Work';

  @override
  String get cycleTapHint => 'Tap a day to correct it';

  @override
  String get cycleNextStart => 'Next period';

  @override
  String cycleNextPredicted(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString · predicted';
  }

  @override
  String cycleNextCorrected(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString · corrected by you';
  }

  @override
  String cycleDayTitle(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.MMMMEEEEd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String cycleDayPredicted(int day, String phase) {
    return 'Predicted: cycle day $day · $phase';
  }

  @override
  String get cycleDayStarted => 'The period started on this day';

  @override
  String get cycleDayWillStart => 'The period will start on this day';

  @override
  String get cycleDayHelp => 'The forecast for the following days counts from here, and the light days move with it.';

  @override
  String get cycleBackToPrediction => 'Back to the forecast';

  @override
  String get daysOffWeekendHelp => 'Every weekend is a day off. To work on one, tap Work in the list below.';

  @override
  String daysOffWeekendEntry(DateTime saturday, DateTime sunday) {
    final intl.DateFormat saturdayDateFormat = intl.DateFormat.Md(localeName);
    final String saturdayString = saturdayDateFormat.format(saturday);
    final intl.DateFormat sundayDateFormat = intl.DateFormat.Md(localeName);
    final String sundayString = sundayDateFormat.format(sunday);

    return '$saturdayString and $sundayString';
  }

  @override
  String get daysOffWork => 'Work';

  @override
  String daysOffWorking(String dates) {
    return '$dates · you\'ll work';
  }

  @override
  String get daysOffUndo => 'Undo';

  @override
  String get pickerDateTitle => 'Which day?';

  @override
  String get cyclePickLength => 'How many days does the cycle last?';

  @override
  String get cyclePickPeriod => 'How many days does the period last?';

  @override
  String get daysOffAddTitle => 'New day off';

  @override
  String get daysOffAddName => 'Name (optional): holiday, trip';

  @override
  String get daysOffAddConfirm => 'Set day off';

  @override
  String get daysOffRemove => 'Remove this day off';

  @override
  String get daysOffRemoveHelp => 'The day goes back to what the weekend and the cycle make of it.';

  @override
  String get daysOffFailure => 'Couldn\'t save. Try again.';

  @override
  String get agentChangeRhythm => 'Cycle and days off';

  @override
  String get homeLaterEmpty => 'Nothing waiting. Write something in the +.';

  @override
  String get menuProducts => 'Products';

  @override
  String get menuProductsHint => 'Tasks by product, the delivered ones too';

  @override
  String get menuNewProduct => 'New product';

  @override
  String get menuNewProductHint => 'To pick in the + when creating a task';

  @override
  String get homePending => 'Pending';

  @override
  String get dayPageTitle => 'Calendar';

  @override
  String get promptTask => 'Task';

  @override
  String get promptEvent => 'Event';

  @override
  String get promptProduct => 'Product';

  @override
  String taskTasksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    return '$_temp0';
  }

  @override
  String homeCycleTag(int day, String what) {
    return 'Day $day · $what';
  }

  @override
  String get dueToday => 'today';

  @override
  String get dueYesterday => 'due yesterday';

  @override
  String get weekdaysLong => 'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday';

  @override
  String dueDate(String day, String month) {
    return '$month/$day';
  }

  @override
  String get controlDayEarlier => 'Deadline a day earlier';

  @override
  String get controlDayLater => 'Deadline a day later';

  @override
  String pendingUrgentStatus(String status) {
    return 'Urgent · $status';
  }

  @override
  String playWhole(String length) {
    return 'All · $length';
  }

  @override
  String get stepDayLess => '−1d';

  @override
  String get stepDayMore => '+1d';

  @override
  String pendingTaskLeft(String length) {
    return '$length left';
  }

  @override
  String get composeOpen => 'Write down or ask';

  @override
  String get composeHint => 'A task, an event, or what to change in the day';

  @override
  String get composeSend => 'Send';

  @override
  String get composeListen => 'Speak';

  @override
  String get composeReading => 'Understanding…';

  @override
  String get composeKindTask => 'Task';

  @override
  String get composeKindEvent => 'Event';

  @override
  String get composeKindPlan => 'Changes to the day';

  @override
  String get composeQueued => 'in the queue';

  @override
  String get composeToday => 'today';

  @override
  String get composeTomorrow => 'tomorrow';

  @override
  String composeAt(String day, String hour) {
    return '$day, $hour';
  }

  @override
  String composeIn(String parent) {
    return 'in $parent';
  }

  @override
  String composeSubtasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subtasks',
      one: '1 subtask',
    );
    return '$_temp0';
  }

  @override
  String get composeAdd => 'Add';

  @override
  String get composeAdjust => 'Adjust';

  @override
  String get composeApply => 'Apply';

  @override
  String get composeTalk => 'Talk';

  @override
  String get composeKindGoal => 'Goal';

  @override
  String composeGoalBy(String value, String day) {
    return '$value by $day';
  }

  @override
  String get composeAdded => 'Added';

  @override
  String get composeFailed => 'Couldn\'t understand right now. Try again.';

  @override
  String get homeSeeCalendar => 'See calendar';

  @override
  String get homeNextEmpty => 'Nothing scheduled from here on.';

  @override
  String playWhenTitle(String title) {
    return 'When to do $title?';
  }

  @override
  String get playWhenNow => 'Start now';

  @override
  String playWhenIdle(String length) {
    return 'Nothing running now · $length';
  }

  @override
  String playWhenBusy(String title, String end, String length) {
    return '$title runs until $end · $length';
  }

  @override
  String playWhenSoon(String hour) {
    return 'In 15 min · $hour';
  }

  @override
  String playWhenAt(String hour) {
    return 'At $hour';
  }

  @override
  String playWhenAfter(String title, String hour) {
    return 'After $title · $hour';
  }

  @override
  String get playMuchNowTitle => 'How much will you do now?';

  @override
  String playMuchAtTitle(String hour) {
    return 'How much goes at $hour?';
  }

  @override
  String playMuchRoomUntil(String title, String length, String room, String next) {
    return '$title has $length. There\'s $room free until $next.';
  }

  @override
  String get playMuchRestNow => 'The rest becomes another subtask, in Pending.';

  @override
  String get playMuchRestStays => 'The rest becomes another subtask and stays where it is.';

  @override
  String playMuchShortTitle(String room, String next) {
    return 'Only $room fits until $next';
  }

  @override
  String playMuchShortBody(String title, String length, String room, String rest) {
    return '$title has $length. Do $room and leave $rest as another subtask?';
  }

  @override
  String playMuchDo(String length) {
    return 'Do $length';
  }

  @override
  String guardPauseTitle(String title) {
    return 'Pause $title?';
  }

  @override
  String guardPauseBody(String title) {
    return '$title goes to Pending.';
  }

  @override
  String get guardPauseYes => 'Yes, pause and start';

  @override
  String get guardPauseNo => 'No';

  @override
  String guardWaitTitle(String title) {
    return 'Start after $title?';
  }

  @override
  String guardWaitBody(String title, String end) {
    return '$title is fixed and runs until $end.';
  }

  @override
  String get guardWaitYes => 'Yes, start after';

  @override
  String playMuchUntil(String title, String hour) {
    return '$title, at $hour';
  }

  @override
  String playMuchDayEnd(String hour) {
    return 'the end of the day, at $hour';
  }
}
