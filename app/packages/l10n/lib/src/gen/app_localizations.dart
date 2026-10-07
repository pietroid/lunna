// dart format off
// coverage:ignore-file
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('pt')
  ];

  /// No description provided for @appName.
  ///
  /// In pt, this message translates to:
  /// **'Lunna'**
  String get appName;

  /// No description provided for @authSignIn.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get authSignIn;

  /// No description provided for @authSignInWithGoogle.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com Google'**
  String get authSignInWithGoogle;

  /// No description provided for @authSignInFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível entrar'**
  String get authSignInFailed;

  /// No description provided for @shellTimelineTab.
  ///
  /// In pt, this message translates to:
  /// **'Tempo'**
  String get shellTimelineTab;

  /// No description provided for @shellSecondTab.
  ///
  /// In pt, this message translates to:
  /// **'Aba 2'**
  String get shellSecondTab;

  /// No description provided for @shellThirdTab.
  ///
  /// In pt, this message translates to:
  /// **'Aba 3'**
  String get shellThirdTab;

  /// No description provided for @shellComingSoon.
  ///
  /// In pt, this message translates to:
  /// **'Em breve.'**
  String get shellComingSoon;

  /// No description provided for @shellWriteDown.
  ///
  /// In pt, this message translates to:
  /// **'Anotar'**
  String get shellWriteDown;

  /// No description provided for @greetingMorning.
  ///
  /// In pt, this message translates to:
  /// **'Bom dia'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In pt, this message translates to:
  /// **'Boa tarde'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In pt, this message translates to:
  /// **'Boa noite'**
  String get greetingEvening;

  /// No description provided for @greetingAlone.
  ///
  /// In pt, this message translates to:
  /// **'{part}!'**
  String greetingAlone(String part);

  /// No description provided for @greetingWithName.
  ///
  /// In pt, this message translates to:
  /// **'{part} {name}!'**
  String greetingWithName(String part, String name);

  /// No description provided for @longDate.
  ///
  /// In pt, this message translates to:
  /// **'{date}'**
  String longDate(DateTime date);

  /// No description provided for @homeRoutines.
  ///
  /// In pt, this message translates to:
  /// **'Rotina'**
  String get homeRoutines;

  /// No description provided for @homeSignOut.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get homeSignOut;

  /// No description provided for @commonCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @guardStartNowTitle.
  ///
  /// In pt, this message translates to:
  /// **'Começar agora?'**
  String get guardStartNowTitle;

  /// No description provided for @guardStartNowRunning.
  ///
  /// In pt, this message translates to:
  /// **'{title} está rodando, {start}–{end}.'**
  String guardStartNowRunning(String title, String start, String end);

  /// No description provided for @guardFinishCurrent.
  ///
  /// In pt, this message translates to:
  /// **'Concluir o atual'**
  String get guardFinishCurrent;

  /// No description provided for @guardPostponeCurrent.
  ///
  /// In pt, this message translates to:
  /// **'Deixar para depois'**
  String get guardPostponeCurrent;

  /// No description provided for @durationMinutes.
  ///
  /// In pt, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In pt, this message translates to:
  /// **'{hours}h'**
  String durationHours(int hours);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In pt, this message translates to:
  /// **'{hours}h{minutes}'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir “{title}”?'**
  String confirmDeleteTitle(String title);

  /// No description provided for @confirmDeleteBody.
  ///
  /// In pt, this message translates to:
  /// **'Sai da agenda e não volta.'**
  String get confirmDeleteBody;

  /// No description provided for @confirmDeleteAction.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get confirmDeleteAction;

  /// No description provided for @confirmShortenTitle.
  ///
  /// In pt, this message translates to:
  /// **'Não cabe inteiro aqui'**
  String get confirmShortenTitle;

  /// No description provided for @confirmShortenBody.
  ///
  /// In pt, this message translates to:
  /// **'“{title}” leva {duration} min e esse intervalo tem espaço para {minutes} min, já contando a pausa. Ajustar para {minutes} min?'**
  String confirmShortenBody(String title, int duration, int minutes);

  /// No description provided for @confirmShortenAction.
  ///
  /// In pt, this message translates to:
  /// **'Ajustar para {minutes} min'**
  String confirmShortenAction(int minutes);

  /// No description provided for @confirmMoreTitle.
  ///
  /// In pt, this message translates to:
  /// **'Mais {minutes} minutos?'**
  String confirmMoreTitle(int minutes);

  /// No description provided for @confirmLessTitle.
  ///
  /// In pt, this message translates to:
  /// **'Menos {minutes} minutos?'**
  String confirmLessTitle(int minutes);

  /// No description provided for @confirmMoreBody.
  ///
  /// In pt, this message translates to:
  /// **'“{title}” passa a terminar às {end}. O que vem depois anda junto.'**
  String confirmMoreBody(String title, String end);

  /// No description provided for @confirmLessBody.
  ///
  /// In pt, this message translates to:
  /// **'“{title}” passa a terminar às {end}. O que vem depois adianta.'**
  String confirmLessBody(String title, String end);

  /// No description provided for @confirmMoreAction.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar'**
  String get confirmMoreAction;

  /// No description provided for @confirmLessAction.
  ///
  /// In pt, this message translates to:
  /// **'Tirar'**
  String get confirmLessAction;

  /// No description provided for @eventUntitled.
  ///
  /// In pt, this message translates to:
  /// **'Sem título'**
  String get eventUntitled;

  /// No description provided for @eventStartsNow.
  ///
  /// In pt, this message translates to:
  /// **'Começa agora'**
  String get eventStartsNow;

  /// No description provided for @eventStartsIn.
  ///
  /// In pt, this message translates to:
  /// **'Começa em {minutes} min'**
  String eventStartsIn(int minutes);

  /// No description provided for @eventStartsAt.
  ///
  /// In pt, this message translates to:
  /// **'Começa às {time}'**
  String eventStartsAt(String time);

  /// No description provided for @eventStartsTomorrowAt.
  ///
  /// In pt, this message translates to:
  /// **'Amanhã às {time}'**
  String eventStartsTomorrowAt(String time);

  /// No description provided for @eventTomorrowAt.
  ///
  /// In pt, this message translates to:
  /// **'amanhã {time}'**
  String eventTomorrowAt(String time);

  /// No description provided for @eventDayAt.
  ///
  /// In pt, this message translates to:
  /// **'{day}/{month} {time}'**
  String eventDayAt(int day, int month, String time);

  /// No description provided for @eventGone.
  ///
  /// In pt, this message translates to:
  /// **'Esse bloco não está mais no dia.'**
  String get eventGone;

  /// No description provided for @eventNotesHint.
  ///
  /// In pt, this message translates to:
  /// **'Anotações'**
  String get eventNotesHint;

  /// No description provided for @restTip01.
  ///
  /// In pt, this message translates to:
  /// **'Respire fundo. Três vezes, devagar.'**
  String get restTip01;

  /// No description provided for @restTip02.
  ///
  /// In pt, this message translates to:
  /// **'Levante, alongue as costas e olhe pela janela.'**
  String get restTip02;

  /// No description provided for @restTip03.
  ///
  /// In pt, this message translates to:
  /// **'Beba um copo d’água antes de continuar.'**
  String get restTip03;

  /// No description provided for @restTip04.
  ///
  /// In pt, this message translates to:
  /// **'Feche os olhos por um minuto. Só isso.'**
  String get restTip04;

  /// No description provided for @restTip05.
  ///
  /// In pt, this message translates to:
  /// **'Deixe a cabeça vazia. O próximo passo espera.'**
  String get restTip05;

  /// No description provided for @restTip06.
  ///
  /// In pt, this message translates to:
  /// **'Solte os ombros. Eles estavam tensos, não estavam?'**
  String get restTip06;

  /// No description provided for @restTip07.
  ///
  /// In pt, this message translates to:
  /// **'Olhe para algo longe. Seus olhos agradecem.'**
  String get restTip07;

  /// No description provided for @restTip08.
  ///
  /// In pt, this message translates to:
  /// **'Nada para resolver agora. Aproveite.'**
  String get restTip08;

  /// No description provided for @restTip09.
  ///
  /// In pt, this message translates to:
  /// **'Caminhe um pouco, nem que seja até a cozinha.'**
  String get restTip09;

  /// No description provided for @restTip10.
  ///
  /// In pt, this message translates to:
  /// **'Um minuto de silêncio. Sem tela.'**
  String get restTip10;

  /// No description provided for @restTip11.
  ///
  /// In pt, this message translates to:
  /// **'Repare no que você está ouvindo agora.'**
  String get restTip11;

  /// No description provided for @restTip12.
  ///
  /// In pt, this message translates to:
  /// **'Você terminou algo. Reconheça isso.'**
  String get restTip12;

  /// No description provided for @restTip13.
  ///
  /// In pt, this message translates to:
  /// **'Inspire em quatro, segure em quatro, solte em quatro.'**
  String get restTip13;

  /// No description provided for @restTip14.
  ///
  /// In pt, this message translates to:
  /// **'Desligue a mente. Ela volta melhor.'**
  String get restTip14;

  /// No description provided for @restTip15.
  ///
  /// In pt, this message translates to:
  /// **'Mexa as mãos, gire os pulsos, relaxe o rosto.'**
  String get restTip15;

  /// No description provided for @restTip16.
  ///
  /// In pt, this message translates to:
  /// **'Pausa de verdade: sem celular.'**
  String get restTip16;

  /// No description provided for @restTip17.
  ///
  /// In pt, this message translates to:
  /// **'Sinta os pés no chão por alguns segundos.'**
  String get restTip17;

  /// No description provided for @restTip18.
  ///
  /// In pt, this message translates to:
  /// **'Descansar também é parte do trabalho.'**
  String get restTip18;

  /// No description provided for @restTip19.
  ///
  /// In pt, this message translates to:
  /// **'Deixe o último assunto ir embora.'**
  String get restTip19;

  /// No description provided for @restTip20.
  ///
  /// In pt, this message translates to:
  /// **'Medite por um instante. Só respire e observe.'**
  String get restTip20;

  /// No description provided for @freeNothingScheduled.
  ///
  /// In pt, this message translates to:
  /// **'Nada programado'**
  String get freeNothingScheduled;

  /// No description provided for @controlStart.
  ///
  /// In pt, this message translates to:
  /// **'Começar'**
  String get controlStart;

  /// No description provided for @controlResume.
  ///
  /// In pt, this message translates to:
  /// **'Retomar'**
  String get controlResume;

  /// No description provided for @controlPause.
  ///
  /// In pt, this message translates to:
  /// **'Pausar'**
  String get controlPause;

  /// No description provided for @controlStartNow.
  ///
  /// In pt, this message translates to:
  /// **'Começar agora'**
  String get controlStartNow;

  /// No description provided for @controlLess15.
  ///
  /// In pt, this message translates to:
  /// **'Menos 15 min'**
  String get controlLess15;

  /// No description provided for @controlWait15.
  ///
  /// In pt, this message translates to:
  /// **'Esperar 15 min'**
  String get controlWait15;

  /// No description provided for @controlMore15.
  ///
  /// In pt, this message translates to:
  /// **'Mais 15 min'**
  String get controlMore15;

  /// No description provided for @controlDone.
  ///
  /// In pt, this message translates to:
  /// **'Concluir'**
  String get controlDone;

  /// No description provided for @nowPausedLeft.
  ///
  /// In pt, this message translates to:
  /// **'Pausado · faltam {left}'**
  String nowPausedLeft(String left);

  /// No description provided for @nowLeft.
  ///
  /// In pt, this message translates to:
  /// **'Faltam {left}'**
  String nowLeft(String left);

  /// No description provided for @sectionNow.
  ///
  /// In pt, this message translates to:
  /// **'Agora'**
  String get sectionNow;

  /// No description provided for @sectionToday.
  ///
  /// In pt, this message translates to:
  /// **'Ainda hoje'**
  String get sectionToday;

  /// No description provided for @sectionTomorrow.
  ///
  /// In pt, this message translates to:
  /// **'Amanhã'**
  String get sectionTomorrow;

  /// No description provided for @sectionDay.
  ///
  /// In pt, this message translates to:
  /// **'{date}'**
  String sectionDay(DateTime date);

  /// No description provided for @timelineModeList.
  ///
  /// In pt, this message translates to:
  /// **'Lista'**
  String get timelineModeList;

  /// No description provided for @timelineModeCalendar.
  ///
  /// In pt, this message translates to:
  /// **'Calendário'**
  String get timelineModeCalendar;

  /// No description provided for @stageSoon.
  ///
  /// In pt, this message translates to:
  /// **'Fazer em breve'**
  String get stageSoon;

  /// No description provided for @stageBacklog.
  ///
  /// In pt, this message translates to:
  /// **'Depois eu priorizo'**
  String get stageBacklog;

  /// No description provided for @stageSoonEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nada na fila. Arraste uma tarefa para cá para ela ganhar uma hora.'**
  String get stageSoonEmpty;

  /// No description provided for @stageBacklogEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nada esperando. O que você anotar fica aqui até ganhar um lugar na fila.'**
  String get stageBacklogEmpty;

  /// No description provided for @promptToBacklog.
  ///
  /// In pt, this message translates to:
  /// **'Vai para Depois eu priorizo'**
  String get promptToBacklog;

  /// No description provided for @eventInBacklog.
  ///
  /// In pt, this message translates to:
  /// **'Em Depois eu priorizo, ainda sem hora'**
  String get eventInBacklog;

  /// No description provided for @routineDaily.
  ///
  /// In pt, this message translates to:
  /// **'Todo dia'**
  String get routineDaily;

  /// No description provided for @routineWeekdays.
  ///
  /// In pt, this message translates to:
  /// **'Dias úteis'**
  String get routineWeekdays;

  /// No description provided for @routineWeekend.
  ///
  /// In pt, this message translates to:
  /// **'Fim de semana'**
  String get routineWeekend;

  /// No description provided for @failureUnreachable.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui falar com o servidor.'**
  String get failureUnreachable;

  /// No description provided for @failureRetry.
  ///
  /// In pt, this message translates to:
  /// **'{reason} Toque para tentar de novo.'**
  String failureRetry(String reason);

  /// No description provided for @timelineEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nada marcado. Toque no + para anotar algo.'**
  String get timelineEmpty;

  /// No description provided for @pickerDurationTitle.
  ///
  /// In pt, this message translates to:
  /// **'Quanto tempo leva?'**
  String get pickerDurationTitle;

  /// No description provided for @pickerTimeTitle.
  ///
  /// In pt, this message translates to:
  /// **'A que horas?'**
  String get pickerTimeTitle;

  /// No description provided for @pickerWhenTitle.
  ///
  /// In pt, this message translates to:
  /// **'Quando?'**
  String get pickerWhenTitle;

  /// No description provided for @commonConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar'**
  String get commonConfirm;

  /// No description provided for @dayToday.
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get dayToday;

  /// No description provided for @dayTomorrow.
  ///
  /// In pt, this message translates to:
  /// **'Amanhã'**
  String get dayTomorrow;

  /// No description provided for @weekdaysShort.
  ///
  /// In pt, this message translates to:
  /// **'seg,ter,qua,qui,sex,sáb,dom'**
  String get weekdaysShort;

  /// No description provided for @monthsShort.
  ///
  /// In pt, this message translates to:
  /// **'jan,fev,mar,abr,mai,jun,jul,ago,set,out,nov,dez'**
  String get monthsShort;

  /// No description provided for @dayShort.
  ///
  /// In pt, this message translates to:
  /// **'{weekday}, {day} {month}'**
  String dayShort(String weekday, int day, String month);

  /// No description provided for @promptHint01.
  ///
  /// In pt, this message translates to:
  /// **'O que precisa ser feito?'**
  String get promptHint01;

  /// No description provided for @promptHint02.
  ///
  /// In pt, this message translates to:
  /// **'No que vamos trabalhar?'**
  String get promptHint02;

  /// No description provided for @promptHint03.
  ///
  /// In pt, this message translates to:
  /// **'O que entra no dia?'**
  String get promptHint03;

  /// No description provided for @promptHint04.
  ///
  /// In pt, this message translates to:
  /// **'Por onde começamos?'**
  String get promptHint04;

  /// No description provided for @promptHint05.
  ///
  /// In pt, this message translates to:
  /// **'O que está na sua cabeça?'**
  String get promptHint05;

  /// No description provided for @promptHint06.
  ///
  /// In pt, this message translates to:
  /// **'Me conta o que precisa.'**
  String get promptHint06;

  /// No description provided for @promptHint07.
  ///
  /// In pt, this message translates to:
  /// **'Qual é a próxima?'**
  String get promptHint07;

  /// No description provided for @promptHint08.
  ///
  /// In pt, this message translates to:
  /// **'O que resolvemos hoje?'**
  String get promptHint08;

  /// No description provided for @promptHint09.
  ///
  /// In pt, this message translates to:
  /// **'Escreve aí.'**
  String get promptHint09;

  /// No description provided for @promptHint10.
  ///
  /// In pt, this message translates to:
  /// **'Pode falar.'**
  String get promptHint10;

  /// No description provided for @promptFlexible.
  ///
  /// In pt, this message translates to:
  /// **'Flexível'**
  String get promptFlexible;

  /// No description provided for @promptFixed.
  ///
  /// In pt, this message translates to:
  /// **'Fixo'**
  String get promptFixed;

  /// No description provided for @promptAtOnDay.
  ///
  /// In pt, this message translates to:
  /// **'{time}, {day}'**
  String promptAtOnDay(String time, String day);

  /// No description provided for @formatMinutes.
  ///
  /// In pt, this message translates to:
  /// **'{minutes} min'**
  String formatMinutes(int minutes);

  /// No description provided for @formatHours.
  ///
  /// In pt, this message translates to:
  /// **'{hours} h'**
  String formatHours(int hours);

  /// No description provided for @formatHoursMinutes.
  ///
  /// In pt, this message translates to:
  /// **'{hours}h{minutes}'**
  String formatHoursMinutes(int hours, String minutes);

  /// No description provided for @notificationChannelBlocks.
  ///
  /// In pt, this message translates to:
  /// **'Blocos'**
  String get notificationChannelBlocks;

  /// No description provided for @notificationChannelBlocksDescription.
  ///
  /// In pt, this message translates to:
  /// **'Quando um bloco começa e quando está perto de terminar.'**
  String get notificationChannelBlocksDescription;

  /// No description provided for @notificationChannelDaily.
  ///
  /// In pt, this message translates to:
  /// **'Bom dia e boa noite'**
  String get notificationChannelDaily;

  /// No description provided for @notificationChannelDailyDescription.
  ///
  /// In pt, this message translates to:
  /// **'Um recado no começo e no fim do dia.'**
  String get notificationChannelDailyDescription;

  /// No description provided for @remindersNextBlock.
  ///
  /// In pt, this message translates to:
  /// **'Próximo bloco'**
  String get remindersNextBlock;

  /// No description provided for @remindersAskTitle.
  ///
  /// In pt, this message translates to:
  /// **'Quer lembretes?'**
  String get remindersAskTitle;

  /// No description provided for @remindersAskBody.
  ///
  /// In pt, this message translates to:
  /// **'Pergunto quando é hora de começar um bloco, aviso dez minutos antes de acabar, e mando um bom dia e um boa noite.'**
  String get remindersAskBody;

  /// No description provided for @remindersEnable.
  ///
  /// In pt, this message translates to:
  /// **'Ativar lembretes'**
  String get remindersEnable;

  /// No description provided for @commonNotNow.
  ///
  /// In pt, this message translates to:
  /// **'Agora não'**
  String get commonNotNow;

  /// No description provided for @remindersStartTitle.
  ///
  /// In pt, this message translates to:
  /// **'Começar “{title}”?'**
  String remindersStartTitle(String title);

  /// No description provided for @remindersStartBody.
  ///
  /// In pt, this message translates to:
  /// **'Enquanto você não confirmar, ele vai para mais tarde a cada minuto, e o resto do dia anda junto.'**
  String get remindersStartBody;

  /// No description provided for @routinesHelp.
  ///
  /// In pt, this message translates to:
  /// **'Toque num horário para criar. Segure um bloco para mudar a hora.'**
  String get routinesHelp;

  /// No description provided for @routinesTitleHint.
  ///
  /// In pt, this message translates to:
  /// **'Almoço, rotina da manhã…'**
  String get routinesTitleHint;

  /// No description provided for @commonSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get commonSave;

  /// No description provided for @routinesDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir rotina'**
  String get routinesDelete;

  /// No description provided for @landingHeadline.
  ///
  /// In pt, this message translates to:
  /// **'Seu dia, no lugar.'**
  String get landingHeadline;

  /// No description provided for @landingPitch.
  ///
  /// In pt, this message translates to:
  /// **'Lunna é um sistema pessoal de organização. Anote o que precisa ser feito e o Lunna dá uma hora para cada coisa, reorganiza o dia quando ele muda e lembra você na hora certa.'**
  String get landingPitch;

  /// No description provided for @landingDemoHint.
  ///
  /// In pt, this message translates to:
  /// **'O celular ao lado é o app de verdade. Toque no + para anotar algo, ou num bloco para abri-lo.'**
  String get landingDemoHint;

  /// No description provided for @landingHowTitle.
  ///
  /// In pt, this message translates to:
  /// **'Como funciona'**
  String get landingHowTitle;

  /// No description provided for @landingPartTimelineTitle.
  ///
  /// In pt, this message translates to:
  /// **'Tempo'**
  String get landingPartTimelineTitle;

  /// No description provided for @landingPartTimelineText.
  ///
  /// In pt, this message translates to:
  /// **'O dia como uma fila: o que está rodando agora, o que vem ainda hoje e o que fica para amanhã.'**
  String get landingPartTimelineText;

  /// No description provided for @landingPartRoutinesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Rotinas'**
  String get landingPartRoutinesTitle;

  /// No description provided for @landingPartRoutinesText.
  ///
  /// In pt, this message translates to:
  /// **'Blocos que voltam todo dia, nos dias úteis ou no fim de semana, sempre no mesmo horário.'**
  String get landingPartRoutinesText;

  /// No description provided for @landingPartRemindersTitle.
  ///
  /// In pt, this message translates to:
  /// **'Lembretes'**
  String get landingPartRemindersTitle;

  /// No description provided for @landingPartRemindersText.
  ///
  /// In pt, this message translates to:
  /// **'Um aviso quando é hora de começar, outro perto do fim, e um bom dia e um boa noite.'**
  String get landingPartRemindersText;

  /// No description provided for @landingDayTitle.
  ///
  /// In pt, this message translates to:
  /// **'No dia a dia'**
  String get landingDayTitle;

  /// No description provided for @landingUseWrite.
  ///
  /// In pt, this message translates to:
  /// **'Anote o que precisa ser feito.'**
  String get landingUseWrite;

  /// No description provided for @landingUseHour.
  ///
  /// In pt, this message translates to:
  /// **'Dê a cada coisa a sua hora.'**
  String get landingUseHour;

  /// No description provided for @landingUsePause.
  ///
  /// In pt, this message translates to:
  /// **'Pause, estenda ou adie, e o resto do dia anda junto.'**
  String get landingUsePause;

  /// No description provided for @landingUseRoutine.
  ///
  /// In pt, this message translates to:
  /// **'Deixe a rotina se repetir sozinha.'**
  String get landingUseRoutine;

  /// No description provided for @landingFooter.
  ///
  /// In pt, this message translates to:
  /// **'Lunna · Organização pessoal'**
  String get landingFooter;

  /// No description provided for @demoBuilding.
  ///
  /// In pt, this message translates to:
  /// **'Fazendo o Lunna'**
  String get demoBuilding;

  /// No description provided for @demoGroceries.
  ///
  /// In pt, this message translates to:
  /// **'Comprar leite e ovos'**
  String get demoGroceries;

  /// No description provided for @demoBacklog.
  ///
  /// In pt, this message translates to:
  /// **'Organizar as fotos da viagem'**
  String get demoBacklog;

  /// No description provided for @demoStandup.
  ///
  /// In pt, this message translates to:
  /// **'Standup'**
  String get demoStandup;

  /// No description provided for @demoDentist.
  ///
  /// In pt, this message translates to:
  /// **'Marcar dentista'**
  String get demoDentist;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'pt': return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
