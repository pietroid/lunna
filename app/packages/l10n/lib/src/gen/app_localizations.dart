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
  /// **'{brand, select, lunna{Lunna} other{Focus}}'**
  String appName(String brand);

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

  /// No description provided for @shellProjectsTab.
  ///
  /// In pt, this message translates to:
  /// **'Projetos'**
  String get shellProjectsTab;

  /// No description provided for @shellMenuTab.
  ///
  /// In pt, this message translates to:
  /// **'Menu'**
  String get shellMenuTab;

  /// No description provided for @menuRoutinesHint.
  ///
  /// In pt, this message translates to:
  /// **'Os blocos que se repetem'**
  String get menuRoutinesHint;

  /// No description provided for @menuDaySection.
  ///
  /// In pt, this message translates to:
  /// **'Seu dia'**
  String get menuDaySection;

  /// No description provided for @menuDayStart.
  ///
  /// In pt, this message translates to:
  /// **'Começa às'**
  String get menuDayStart;

  /// No description provided for @menuDayEnd.
  ///
  /// In pt, this message translates to:
  /// **'Termina às'**
  String get menuDayEnd;

  /// No description provided for @menuDayHelp.
  ///
  /// In pt, this message translates to:
  /// **'Nada entra na fila fora dessas horas.'**
  String get menuDayHelp;

  /// No description provided for @menuDayTooShort.
  ///
  /// In pt, this message translates to:
  /// **'O dia precisa terminar pelo menos uma hora depois de começar.'**
  String get menuDayTooShort;

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
  /// **'Nada esperando. Arraste para cá o que ainda não tem lugar na fila.'**
  String get stageBacklogEmpty;

  /// No description provided for @stageDone.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Feitas} =1{1 feita} other{{count} feitas}}'**
  String stageDone(int count);

  /// No description provided for @stageDoneEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nada feito ainda. Arraste uma tarefa para a direita quando terminar.'**
  String get stageDoneEmpty;

  /// No description provided for @promptToBacklog.
  ///
  /// In pt, this message translates to:
  /// **'Vai para Depois eu priorizo'**
  String get promptToBacklog;

  /// No description provided for @promptToQueue.
  ///
  /// In pt, this message translates to:
  /// **'Entra na fila, onde houver espaço'**
  String get promptToQueue;

  /// No description provided for @promptPickTime.
  ///
  /// In pt, this message translates to:
  /// **'Escolher horário'**
  String get promptPickTime;

  /// No description provided for @timelineAdd.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar'**
  String get timelineAdd;

  /// No description provided for @timelineBackToNow.
  ///
  /// In pt, this message translates to:
  /// **'Voltar para agora'**
  String get timelineBackToNow;

  /// No description provided for @eventInBacklog.
  ///
  /// In pt, this message translates to:
  /// **'Em Depois eu priorizo, ainda sem hora'**
  String get eventInBacklog;

  /// No description provided for @eventDoneOn.
  ///
  /// In pt, this message translates to:
  /// **'Feita {day}, às {time}'**
  String eventDoneOn(String day, String time);

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
  /// **'{brand, select, lunna{A Lunna é um sistema pessoal de organização. Anote o que precisa ser feito e a Lunna dá uma hora para cada coisa, reorganiza o dia quando ele muda e lembra você na hora certa.} other{O Focus é um sistema pessoal de organização. Anote o que precisa ser feito e o Focus dá uma hora para cada coisa, reorganiza o dia quando ele muda e lembra você na hora certa.}}'**
  String landingPitch(String brand);

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
  /// **'{brand, select, lunna{Lunna} other{Focus}} · Organização pessoal'**
  String landingFooter(String brand);

  /// No description provided for @demoBuilding.
  ///
  /// In pt, this message translates to:
  /// **'{brand, select, lunna{Fazendo a Lunna} other{Fazendo o Focus}}'**
  String demoBuilding(String brand);

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

  /// No description provided for @agentAsk.
  ///
  /// In pt, this message translates to:
  /// **'{brand, select, lunna{Pergunte à Lunna…} other{Pergunte ao Focus…}}'**
  String agentAsk(String brand);

  /// No description provided for @agentSuggestionLabel.
  ///
  /// In pt, this message translates to:
  /// **'{brand, select, lunna{Sugestão da Lunna} other{Sugestão do Focus}}'**
  String agentSuggestionLabel(String brand);

  /// No description provided for @agentInputHint.
  ///
  /// In pt, this message translates to:
  /// **'Pergunte ou peça algo…'**
  String get agentInputHint;

  /// No description provided for @agentReplyHint.
  ///
  /// In pt, this message translates to:
  /// **'Responder…'**
  String get agentReplyHint;

  /// No description provided for @agentThinking.
  ///
  /// In pt, this message translates to:
  /// **'Olhando seu dia…'**
  String get agentThinking;

  /// No description provided for @agentSend.
  ///
  /// In pt, this message translates to:
  /// **'Enviar'**
  String get agentSend;

  /// No description provided for @agentClose.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get agentClose;

  /// No description provided for @agentApply.
  ///
  /// In pt, this message translates to:
  /// **'Aplicar'**
  String get agentApply;

  /// No description provided for @agentAdjust.
  ///
  /// In pt, this message translates to:
  /// **'Ajustar'**
  String get agentAdjust;

  /// No description provided for @agentApplied.
  ///
  /// In pt, this message translates to:
  /// **'Aplicado'**
  String get agentApplied;

  /// No description provided for @agentChanges.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 mudança} other{{count} mudanças}}'**
  String agentChanges(int count);

  /// No description provided for @agentChangeAddTask.
  ///
  /// In pt, this message translates to:
  /// **'nova tarefa'**
  String get agentChangeAddTask;

  /// No description provided for @agentChangeAddEvent.
  ///
  /// In pt, this message translates to:
  /// **'novo bloco fixo'**
  String get agentChangeAddEvent;

  /// No description provided for @agentChangeMoved.
  ///
  /// In pt, this message translates to:
  /// **'movida'**
  String get agentChangeMoved;

  /// No description provided for @agentChangeRoutine.
  ///
  /// In pt, this message translates to:
  /// **'rotina, só nesse dia'**
  String get agentChangeRoutine;

  /// No description provided for @agentChangeFromBacklog.
  ///
  /// In pt, this message translates to:
  /// **'saiu do Depois eu priorizo'**
  String get agentChangeFromBacklog;

  /// No description provided for @agentUndo.
  ///
  /// In pt, this message translates to:
  /// **'Desfazer'**
  String get agentUndo;

  /// No description provided for @agentEarlier.
  ///
  /// In pt, this message translates to:
  /// **'Conversas anteriores'**
  String get agentEarlier;

  /// No description provided for @agentEarlierFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui trazer as conversas anteriores. Toque para tentar de novo.'**
  String get agentEarlierFailed;

  /// No description provided for @agentHistoryToday.
  ///
  /// In pt, this message translates to:
  /// **'Hoje · {time}'**
  String agentHistoryToday(DateTime time);

  /// No description provided for @agentHistoryYesterday.
  ///
  /// In pt, this message translates to:
  /// **'Ontem, {day} · {time}'**
  String agentHistoryYesterday(DateTime day, DateTime time);

  /// No description provided for @agentHistoryDay.
  ///
  /// In pt, this message translates to:
  /// **'{day} · {time}'**
  String agentHistoryDay(DateTime day, DateTime time);

  /// No description provided for @agentHistoryNow.
  ///
  /// In pt, this message translates to:
  /// **'Agora · {time}'**
  String agentHistoryNow(DateTime time);

  /// No description provided for @agentPlanSummary.
  ///
  /// In pt, this message translates to:
  /// **'{changes} · {status}'**
  String agentPlanSummary(String changes, String status);

  /// No description provided for @agentPlanApplied.
  ///
  /// In pt, this message translates to:
  /// **'aplicado'**
  String get agentPlanApplied;

  /// No description provided for @agentPlanUndone.
  ///
  /// In pt, this message translates to:
  /// **'desfeito'**
  String get agentPlanUndone;

  /// No description provided for @agentPlanNotApplied.
  ///
  /// In pt, this message translates to:
  /// **'não aplicado'**
  String get agentPlanNotApplied;

  /// No description provided for @agentPushedCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 empurrada} other{{count} empurradas}}'**
  String agentPushedCount(int count);

  /// No description provided for @agentChangePushed.
  ///
  /// In pt, this message translates to:
  /// **'empurrada'**
  String get agentChangePushed;

  /// No description provided for @agentPush.
  ///
  /// In pt, this message translates to:
  /// **'Mover'**
  String get agentPush;

  /// No description provided for @agentOtherTime.
  ///
  /// In pt, this message translates to:
  /// **'Outro horário'**
  String get agentOtherTime;

  /// No description provided for @agentOtherTimeDraft.
  ///
  /// In pt, this message translates to:
  /// **'Prefiro outro horário: '**
  String get agentOtherTimeDraft;

  /// No description provided for @agentSuggestionAccept.
  ///
  /// In pt, this message translates to:
  /// **'Encaixar'**
  String get agentSuggestionAccept;

  /// No description provided for @agentSuggestionDismiss.
  ///
  /// In pt, this message translates to:
  /// **'Agora não'**
  String get agentSuggestionDismiss;

  /// No description provided for @agentFailure.
  ///
  /// In pt, this message translates to:
  /// **'Algo deu errado. Tente de novo.'**
  String get agentFailure;

  /// No description provided for @agentFailureModelDown.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui falar com o modelo agora, nem tentando duas vezes.'**
  String get agentFailureModelDown;

  /// No description provided for @agentFailureModelEmpty.
  ///
  /// In pt, this message translates to:
  /// **'O modelo respondeu em branco, duas vezes.'**
  String get agentFailureModelEmpty;

  /// No description provided for @agentFailureDrift.
  ///
  /// In pt, this message translates to:
  /// **'Seu dia mudou desde esse plano e ele não cabe mais. Peça de novo.'**
  String get agentFailureDrift;

  /// No description provided for @agentFailureOffline.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão com o servidor.'**
  String get agentFailureOffline;

  /// No description provided for @agentFailureBug.
  ///
  /// In pt, this message translates to:
  /// **'Algo deu errado do meu lado. Ficou registrado.'**
  String get agentFailureBug;

  /// No description provided for @agentRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar de novo'**
  String get agentRetry;

  /// No description provided for @agentDetails.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes'**
  String get agentDetails;

  /// No description provided for @agentTrace.
  ///
  /// In pt, this message translates to:
  /// **'Código {id}'**
  String agentTrace(String id);

  /// No description provided for @agentPlaceBetween.
  ///
  /// In pt, this message translates to:
  /// **'entre {after} e {before}'**
  String agentPlaceBetween(String after, String before);

  /// No description provided for @agentPlaceAfter.
  ///
  /// In pt, this message translates to:
  /// **'depois de {after}'**
  String agentPlaceAfter(String after);

  /// No description provided for @agentPlaceBefore.
  ///
  /// In pt, this message translates to:
  /// **'antes de {before}'**
  String agentPlaceBefore(String before);

  /// No description provided for @agentPlaceEnd.
  ///
  /// In pt, this message translates to:
  /// **'no fim da fila'**
  String get agentPlaceEnd;

  /// No description provided for @agentAssumed.
  ///
  /// In pt, this message translates to:
  /// **'Assumi {what}'**
  String agentAssumed(String what);

  /// No description provided for @agentAssumedToday.
  ///
  /// In pt, this message translates to:
  /// **'que é para hoje'**
  String get agentAssumedToday;

  /// No description provided for @agentAssumedEnd.
  ///
  /// In pt, this message translates to:
  /// **'o fim da fila'**
  String get agentAssumedEnd;

  /// No description provided for @agentVoiceStart.
  ///
  /// In pt, this message translates to:
  /// **'Falar'**
  String get agentVoiceStart;

  /// No description provided for @agentVoiceListening.
  ///
  /// In pt, this message translates to:
  /// **'Ouvindo'**
  String get agentVoiceListening;

  /// No description provided for @agentVoiceStopped.
  ///
  /// In pt, this message translates to:
  /// **'Parei de ouvir no limite de 1 minuto'**
  String get agentVoiceStopped;

  /// No description provided for @agentVoiceHint.
  ///
  /// In pt, this message translates to:
  /// **'Pode falar. Eu escrevo enquanto você fala.'**
  String get agentVoiceHint;

  /// No description provided for @agentVoiceDiscard.
  ///
  /// In pt, this message translates to:
  /// **'Descartar'**
  String get agentVoiceDiscard;

  /// No description provided for @agentVoiceStop.
  ///
  /// In pt, this message translates to:
  /// **'Parar e revisar'**
  String get agentVoiceStop;

  /// No description provided for @agentVoiceOpen.
  ///
  /// In pt, this message translates to:
  /// **'Abrir a conversa'**
  String get agentVoiceOpen;

  /// No description provided for @agentVoiceVia.
  ///
  /// In pt, this message translates to:
  /// **'por voz · {length}'**
  String agentVoiceVia(String length);

  /// No description provided for @agentVoiceDenied.
  ///
  /// In pt, this message translates to:
  /// **'{brand, select, lunna{A Lunna não tem acesso ao microfone. Libere nos Ajustes do aparelho.} other{O Focus não tem acesso ao microfone. Libere nos Ajustes do aparelho.}}'**
  String agentVoiceDenied(String brand);

  /// No description provided for @agentVoiceUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Este aparelho não reconhece fala em português.'**
  String get agentVoiceUnavailable;

  /// No description provided for @projectsOpenCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Nenhum em andamento} =1{1 em andamento} other{{count} em andamento}}'**
  String projectsOpenCount(int count);

  /// No description provided for @projectsDoneSection.
  ///
  /// In pt, this message translates to:
  /// **'Concluídos'**
  String get projectsDoneSection;

  /// No description provided for @projectsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Um projeto junta as tarefas de um mesmo assunto, com prazo ou sem.'**
  String get projectsEmpty;

  /// No description provided for @projectsNew.
  ///
  /// In pt, this message translates to:
  /// **'Novo projeto'**
  String get projectsNew;

  /// No description provided for @projectUntitled.
  ///
  /// In pt, this message translates to:
  /// **'Sem nome'**
  String get projectUntitled;

  /// No description provided for @projectNoDeadline.
  ///
  /// In pt, this message translates to:
  /// **'Sem prazo'**
  String get projectNoDeadline;

  /// No description provided for @projectGiveDeadline.
  ///
  /// In pt, this message translates to:
  /// **'Dar um prazo'**
  String get projectGiveDeadline;

  /// No description provided for @projectUntil.
  ///
  /// In pt, this message translates to:
  /// **'até {date}'**
  String projectUntil(String date);

  /// No description provided for @projectDaysLeft.
  ///
  /// In pt, this message translates to:
  /// **'{days, plural, =0{termina hoje} =1{falta 1 dia} other{faltam {days} dias}}'**
  String projectDaysLeft(int days);

  /// No description provided for @projectOverdue.
  ///
  /// In pt, this message translates to:
  /// **'{days, plural, =1{atrasado 1 dia} other{atrasado {days} dias}}'**
  String projectOverdue(int days);

  /// No description provided for @projectTaskCount.
  ///
  /// In pt, this message translates to:
  /// **'{done} de {total}'**
  String projectTaskCount(int done, int total);

  /// No description provided for @projectDoneOn.
  ///
  /// In pt, this message translates to:
  /// **'concluído {date}'**
  String projectDoneOn(String date);

  /// No description provided for @projectMinusDay.
  ///
  /// In pt, this message translates to:
  /// **'−1 dia'**
  String get projectMinusDay;

  /// No description provided for @projectPlusDay.
  ///
  /// In pt, this message translates to:
  /// **'+1 dia'**
  String get projectPlusDay;

  /// No description provided for @projectLessDay.
  ///
  /// In pt, this message translates to:
  /// **'Um dia a menos'**
  String get projectLessDay;

  /// No description provided for @projectMoreDay.
  ///
  /// In pt, this message translates to:
  /// **'Um dia a mais'**
  String get projectMoreDay;

  /// No description provided for @projectDone.
  ///
  /// In pt, this message translates to:
  /// **'Concluir projeto'**
  String get projectDone;

  /// No description provided for @projectReopen.
  ///
  /// In pt, this message translates to:
  /// **'Reabrir projeto'**
  String get projectReopen;

  /// No description provided for @projectTasksTab.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Tarefas} other{Tarefas · {count}}}'**
  String projectTasksTab(int count);

  /// No description provided for @projectNotesTab.
  ///
  /// In pt, this message translates to:
  /// **'Notas'**
  String get projectNotesTab;

  /// No description provided for @projectNotesHint.
  ///
  /// In pt, this message translates to:
  /// **'Escreva o que quiser sobre o projeto…'**
  String get projectNotesHint;

  /// No description provided for @projectAddTask.
  ///
  /// In pt, this message translates to:
  /// **'Nova tarefa'**
  String get projectAddTask;

  /// No description provided for @projectTasksDone.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 feita} other{{count} feitas}}'**
  String projectTasksDone(int count);

  /// No description provided for @projectSheetHint.
  ///
  /// In pt, this message translates to:
  /// **'Qual é o projeto?'**
  String get projectSheetHint;

  /// No description provided for @projectSheetOpenEnded.
  ///
  /// In pt, this message translates to:
  /// **'Sem data para acabar'**
  String get projectSheetOpenEnded;

  /// No description provided for @projectWeek.
  ///
  /// In pt, this message translates to:
  /// **'1 semana'**
  String get projectWeek;

  /// No description provided for @projectMonth.
  ///
  /// In pt, this message translates to:
  /// **'1 mês'**
  String get projectMonth;

  /// No description provided for @projectPickDay.
  ///
  /// In pt, this message translates to:
  /// **'Escolher dia'**
  String get projectPickDay;

  /// No description provided for @projectDeleteBody.
  ///
  /// In pt, this message translates to:
  /// **'As tarefas em Depois eu priorizo vão junto. As que já estão em Fazer em breve, e as feitas, ficam no Tempo.'**
  String get projectDeleteBody;

  /// No description provided for @dayOverTitle.
  ///
  /// In pt, this message translates to:
  /// **'Seu dia terminou às {end}'**
  String dayOverTitle(String end);

  /// No description provided for @dayOverBody.
  ///
  /// In pt, this message translates to:
  /// **'Nada começa agora. A fila volta a andar amanhã às {start}.'**
  String dayOverBody(String start);

  /// No description provided for @dayNotYetTitle.
  ///
  /// In pt, this message translates to:
  /// **'Seu dia começa às {start}'**
  String dayNotYetTitle(String start);

  /// No description provided for @dayNotYetBody.
  ///
  /// In pt, this message translates to:
  /// **'Nada começa antes disso. Até lá, descanse.'**
  String get dayNotYetBody;

  /// No description provided for @dayClosedAdjust.
  ///
  /// In pt, this message translates to:
  /// **'Mudar horário'**
  String get dayClosedAdjust;

  /// No description provided for @dayClosedRefused.
  ///
  /// In pt, this message translates to:
  /// **'Agora não: seu dia terminou'**
  String get dayClosedRefused;

  /// No description provided for @vacatedTitle.
  ///
  /// In pt, this message translates to:
  /// **'Agora fica livre'**
  String get vacatedTitle;

  /// No description provided for @vacatedBody.
  ///
  /// In pt, this message translates to:
  /// **'Solte para pausar: ela volta para a fila com o que falta.'**
  String get vacatedBody;

  /// No description provided for @dragHintPause.
  ///
  /// In pt, this message translates to:
  /// **'Pausar · volta com {left}'**
  String dragHintPause(String left);

  /// No description provided for @dragHintShift.
  ///
  /// In pt, this message translates to:
  /// **'{delta} · {hour}'**
  String dragHintShift(String delta, String hour);

  /// No description provided for @dragHintResize.
  ///
  /// In pt, this message translates to:
  /// **'{delta} · até {hour}'**
  String dragHintResize(String delta, String hour);

  /// No description provided for @dragHintTomorrowAt.
  ///
  /// In pt, this message translates to:
  /// **'amanhã {hour}'**
  String dragHintTomorrowAt(String hour);

  /// No description provided for @minutesDelta.
  ///
  /// In pt, this message translates to:
  /// **'{sign}{minutes} min'**
  String minutesDelta(String sign, String minutes);

  /// No description provided for @dragHintSwapWith.
  ///
  /// In pt, this message translates to:
  /// **'Trocar com {title}'**
  String dragHintSwapWith(String title);

  /// No description provided for @dragHintMoveTo.
  ///
  /// In pt, this message translates to:
  /// **'Para {when}'**
  String dragHintMoveTo(String when);

  /// No description provided for @dictationStart.
  ///
  /// In pt, this message translates to:
  /// **'Ditar nas anotações'**
  String get dictationStart;

  /// No description provided for @dictationStop.
  ///
  /// In pt, this message translates to:
  /// **'Parar de ditar'**
  String get dictationStop;

  /// No description provided for @dictationDiscard.
  ///
  /// In pt, this message translates to:
  /// **'Descartar este parágrafo'**
  String get dictationDiscard;

  /// No description provided for @agentApplyDelete.
  ///
  /// In pt, this message translates to:
  /// **'Apagar'**
  String get agentApplyDelete;

  /// No description provided for @agentChangeRenamed.
  ///
  /// In pt, this message translates to:
  /// **'novo nome'**
  String get agentChangeRenamed;

  /// No description provided for @agentChangeLength.
  ///
  /// In pt, this message translates to:
  /// **'duração'**
  String get agentChangeLength;

  /// No description provided for @agentChangeNotes.
  ///
  /// In pt, this message translates to:
  /// **'notas'**
  String get agentChangeNotes;

  /// No description provided for @agentChangeDone.
  ///
  /// In pt, this message translates to:
  /// **'concluída'**
  String get agentChangeDone;

  /// No description provided for @agentChangeRemove.
  ///
  /// In pt, this message translates to:
  /// **'apagar'**
  String get agentChangeRemove;

  /// No description provided for @agentChangeNewProject.
  ///
  /// In pt, this message translates to:
  /// **'novo projeto'**
  String get agentChangeNewProject;

  /// No description provided for @agentChangeDeadline.
  ///
  /// In pt, this message translates to:
  /// **'prazo'**
  String get agentChangeDeadline;

  /// No description provided for @agentChangeProjectDone.
  ///
  /// In pt, this message translates to:
  /// **'projeto concluído'**
  String get agentChangeProjectDone;

  /// No description provided for @agentChangeRemoveProject.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{apagar o projeto} =1{apagar o projeto e 1 tarefa} other{apagar o projeto e {count} tarefas}}'**
  String agentChangeRemoveProject(int count);

  /// No description provided for @agentFree.
  ///
  /// In pt, this message translates to:
  /// **'{span} livre'**
  String agentFree(String span);

  /// No description provided for @agentCardsCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 tarefa} other{{count} tarefas}}'**
  String agentCardsCount(int count);

  /// No description provided for @agentProjectDone.
  ///
  /// In pt, this message translates to:
  /// **'{done} de {total} feitas'**
  String agentProjectDone(int done, int total);

  /// No description provided for @agentProjectNext.
  ///
  /// In pt, this message translates to:
  /// **'Próximas'**
  String get agentProjectNext;

  /// No description provided for @agentProjectMore.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{mais 1} other{mais {count}}}'**
  String agentProjectMore(int count);

  /// No description provided for @agentProjectOpen.
  ///
  /// In pt, this message translates to:
  /// **'Abrir projeto'**
  String get agentProjectOpen;
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
