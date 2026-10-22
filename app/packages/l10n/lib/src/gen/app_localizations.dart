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

  /// No description provided for @menuArchive.
  ///
  /// In pt, this message translates to:
  /// **'Feitas'**
  String get menuArchive;

  /// No description provided for @menuArchiveHint.
  ///
  /// In pt, this message translates to:
  /// **'Tudo o que você já concluiu'**
  String get menuArchiveHint;

  /// No description provided for @archiveSearch.
  ///
  /// In pt, this message translates to:
  /// **'Buscar nas feitas'**
  String get archiveSearch;

  /// No description provided for @archiveToday.
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get archiveToday;

  /// No description provided for @archiveYesterday.
  ///
  /// In pt, this message translates to:
  /// **'Ontem'**
  String get archiveYesterday;

  /// No description provided for @archiveEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nada concluído ainda. O que você marcar como feito fica guardado aqui.'**
  String get archiveEmpty;

  /// No description provided for @archiveNoMatch.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma tarefa feita com essas palavras.'**
  String get archiveNoMatch;

  /// No description provided for @archiveFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não deu para abrir as feitas agora.'**
  String get archiveFailed;

  /// No description provided for @archiveRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar de novo'**
  String get archiveRetry;

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

  /// No description provided for @eventWhenLabel.
  ///
  /// In pt, this message translates to:
  /// **'Horário'**
  String get eventWhenLabel;

  /// No description provided for @eventLengthLabel.
  ///
  /// In pt, this message translates to:
  /// **'Duração'**
  String get eventLengthLabel;

  /// No description provided for @eventArtifactLabel.
  ///
  /// In pt, this message translates to:
  /// **'Entrega'**
  String get eventArtifactLabel;

  /// No description provided for @eventNoArtifact.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma'**
  String get eventNoArtifact;

  /// No description provided for @eventNotesLabel.
  ///
  /// In pt, this message translates to:
  /// **'Notas'**
  String get eventNotesLabel;

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

  /// One muted line at the foot of the landing page: what PostHog records, and that replays mask every text and image.
  ///
  /// In pt, this message translates to:
  /// **'Registramos o uso e os erros do app para melhorá-lo. Textos e imagens nunca saem do seu aparelho nas gravações.'**
  String get landingPrivacy;

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

  /// No description provided for @agentVoiceSlideCancel.
  ///
  /// In pt, this message translates to:
  /// **'Deslize para cancelar'**
  String get agentVoiceSlideCancel;

  /// No description provided for @agentVoiceLock.
  ///
  /// In pt, this message translates to:
  /// **'Gravar sem segurar'**
  String get agentVoiceLock;

  /// No description provided for @agentVoiceSend.
  ///
  /// In pt, this message translates to:
  /// **'Enviar'**
  String get agentVoiceSend;

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

  /// No description provided for @artifactUntitled.
  ///
  /// In pt, this message translates to:
  /// **'Sem nome'**
  String get artifactUntitled;

  /// No description provided for @artifactNoDeadline.
  ///
  /// In pt, this message translates to:
  /// **'Sem prazo'**
  String get artifactNoDeadline;

  /// No description provided for @artifactGiveDeadline.
  ///
  /// In pt, this message translates to:
  /// **'Dar um prazo'**
  String get artifactGiveDeadline;

  /// No description provided for @artifactUntil.
  ///
  /// In pt, this message translates to:
  /// **'até {date}'**
  String artifactUntil(String date);

  /// No description provided for @artifactDaysLeft.
  ///
  /// In pt, this message translates to:
  /// **'{days, plural, =0{termina hoje} =1{falta 1 dia} other{faltam {days} dias}}'**
  String artifactDaysLeft(int days);

  /// No description provided for @artifactOverdue.
  ///
  /// In pt, this message translates to:
  /// **'{days, plural, =1{atrasada 1 dia} other{atrasada {days} dias}}'**
  String artifactOverdue(int days);

  /// No description provided for @artifactTaskCount.
  ///
  /// In pt, this message translates to:
  /// **'{done} de {total}'**
  String artifactTaskCount(int done, int total);

  /// No description provided for @artifactDoneOn.
  ///
  /// In pt, this message translates to:
  /// **'entregue {date}'**
  String artifactDoneOn(String date);

  /// No description provided for @artifactMinusDay.
  ///
  /// In pt, this message translates to:
  /// **'−1 dia'**
  String get artifactMinusDay;

  /// No description provided for @artifactPlusDay.
  ///
  /// In pt, this message translates to:
  /// **'+1 dia'**
  String get artifactPlusDay;

  /// No description provided for @artifactLessDay.
  ///
  /// In pt, this message translates to:
  /// **'Um dia a menos'**
  String get artifactLessDay;

  /// No description provided for @artifactMoreDay.
  ///
  /// In pt, this message translates to:
  /// **'Um dia a mais'**
  String get artifactMoreDay;

  /// No description provided for @artifactTasksTab.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Tarefas} other{Tarefas · {count}}}'**
  String artifactTasksTab(int count);

  /// No description provided for @artifactNotesTab.
  ///
  /// In pt, this message translates to:
  /// **'Notas'**
  String get artifactNotesTab;

  /// No description provided for @artifactDeadlineLabel.
  ///
  /// In pt, this message translates to:
  /// **'Prazo'**
  String get artifactDeadlineLabel;

  /// No description provided for @artifactProgressLabel.
  ///
  /// In pt, this message translates to:
  /// **'Feitas'**
  String get artifactProgressLabel;

  /// No description provided for @artifactNotesHint.
  ///
  /// In pt, this message translates to:
  /// **'Escreva o que quiser sobre a entrega…'**
  String get artifactNotesHint;

  /// No description provided for @artifactAddTask.
  ///
  /// In pt, this message translates to:
  /// **'Nova tarefa'**
  String get artifactAddTask;

  /// No description provided for @artifactTasksDone.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 feita} other{{count} feitas}}'**
  String artifactTasksDone(int count);

  /// No description provided for @artifactDeleteBody.
  ///
  /// In pt, this message translates to:
  /// **'As tarefas em Depois eu priorizo vão junto. As que já estão em Fazer em breve, e as feitas, ficam no Tempo.'**
  String get artifactDeleteBody;

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

  /// No description provided for @agentChangeNewArtifact.
  ///
  /// In pt, this message translates to:
  /// **'nova entrega'**
  String get agentChangeNewArtifact;

  /// No description provided for @agentChangeDeadline.
  ///
  /// In pt, this message translates to:
  /// **'prazo'**
  String get agentChangeDeadline;

  /// No description provided for @agentChangeArtifactDone.
  ///
  /// In pt, this message translates to:
  /// **'entregue'**
  String get agentChangeArtifactDone;

  /// No description provided for @agentChangeRemoveArtifact.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{apagar a entrega} =1{apagar a entrega e 1 tarefa} other{apagar a entrega e {count} tarefas}}'**
  String agentChangeRemoveArtifact(int count);

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

  /// No description provided for @agentArtifactDone.
  ///
  /// In pt, this message translates to:
  /// **'{done} de {total} feitas'**
  String agentArtifactDone(int done, int total);

  /// No description provided for @agentArtifactNext.
  ///
  /// In pt, this message translates to:
  /// **'Próximas'**
  String get agentArtifactNext;

  /// No description provided for @agentArtifactMore.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{mais 1} other{mais {count}}}'**
  String agentArtifactMore(int count);

  /// No description provided for @agentArtifactOpen.
  ///
  /// In pt, this message translates to:
  /// **'Abrir entrega'**
  String get agentArtifactOpen;

  /// No description provided for @shellArtifactsTab.
  ///
  /// In pt, this message translates to:
  /// **'Entregas'**
  String get shellArtifactsTab;

  /// No description provided for @monthsLong.
  ///
  /// In pt, this message translates to:
  /// **'janeiro,fevereiro,março,abril,maio,junho,julho,agosto,setembro,outubro,novembro,dezembro'**
  String get monthsLong;

  /// No description provided for @artifactsSearch.
  ///
  /// In pt, this message translates to:
  /// **'Buscar entregas'**
  String get artifactsSearch;

  /// No description provided for @artifactsSearchHint.
  ///
  /// In pt, this message translates to:
  /// **'Buscar por nome, cliente ou tipo'**
  String get artifactsSearchHint;

  /// No description provided for @goalsSection.
  ///
  /// In pt, this message translates to:
  /// **'Metas'**
  String get goalsSection;

  /// No description provided for @goalNew.
  ///
  /// In pt, this message translates to:
  /// **'Nova meta'**
  String get goalNew;

  /// No description provided for @goalRevenue.
  ///
  /// In pt, this message translates to:
  /// **'Faturamento'**
  String get goalRevenue;

  /// No description provided for @goalInMonth.
  ///
  /// In pt, this message translates to:
  /// **'{label} · {month}'**
  String goalInMonth(String label, String month);

  /// No description provided for @goalThisWeek.
  ///
  /// In pt, this message translates to:
  /// **'{label} · esta semana'**
  String goalThisWeek(String label);

  /// No description provided for @goalOf.
  ///
  /// In pt, this message translates to:
  /// **'de {target}'**
  String goalOf(String target);

  /// No description provided for @goalDaysLeft.
  ///
  /// In pt, this message translates to:
  /// **'{days, plural, =0{termina hoje} =1{falta 1 dia} other{faltam {days} dias}}'**
  String goalDaysLeft(int days);

  /// No description provided for @goalStartsOn.
  ///
  /// In pt, this message translates to:
  /// **'começa {date}'**
  String goalStartsOn(String date);

  /// No description provided for @goalDone.
  ///
  /// In pt, this message translates to:
  /// **'feito'**
  String get goalDone;

  /// No description provided for @goalQueued.
  ///
  /// In pt, this message translates to:
  /// **'na fila {value}'**
  String goalQueued(String value);

  /// No description provided for @goalMissing.
  ///
  /// In pt, this message translates to:
  /// **'faltam {value}'**
  String goalMissing(String value);

  /// No description provided for @goalCovered.
  ///
  /// In pt, this message translates to:
  /// **'a fila cobre o resto'**
  String get goalCovered;

  /// No description provided for @goalSchedule.
  ///
  /// In pt, this message translates to:
  /// **'A fila pede {need} · você tem {free} livres até {date}'**
  String goalSchedule(String need, String free, String date);

  /// No description provided for @artifactsQueue.
  ///
  /// In pt, this message translates to:
  /// **'Fila'**
  String get artifactsQueue;

  /// No description provided for @artifactsQueueSummary.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 entrega} other{{count} entregas}} · {time}'**
  String artifactsQueueSummary(int count, String time);

  /// No description provided for @artifactsAll.
  ///
  /// In pt, this message translates to:
  /// **'Todas'**
  String get artifactsAll;

  /// No description provided for @artifactsSeeAll.
  ///
  /// In pt, this message translates to:
  /// **'Ver todas as {count}'**
  String artifactsSeeAll(int count);

  /// No description provided for @artifactsAllTitle.
  ///
  /// In pt, this message translates to:
  /// **'Todas as entregas'**
  String get artifactsAllTitle;

  /// No description provided for @artifactsInQueue.
  ///
  /// In pt, this message translates to:
  /// **'Na fila'**
  String get artifactsInQueue;

  /// No description provided for @artifactsDone.
  ///
  /// In pt, this message translates to:
  /// **'Feitas'**
  String get artifactsDone;

  /// No description provided for @artifactsDoneOn.
  ///
  /// In pt, this message translates to:
  /// **'feita {date}'**
  String artifactsDoneOn(String date);

  /// No description provided for @artifactsNoResults.
  ///
  /// In pt, this message translates to:
  /// **'Nada com “{query}”.'**
  String artifactsNoResults(String query);

  /// No description provided for @artifactsNew.
  ///
  /// In pt, this message translates to:
  /// **'Nova entrega'**
  String get artifactsNew;

  /// No description provided for @artifactLoose.
  ///
  /// In pt, this message translates to:
  /// **'Avulsa'**
  String get artifactLoose;

  /// No description provided for @artifactDue.
  ///
  /// In pt, this message translates to:
  /// **'até {date}'**
  String artifactDue(String date);

  /// No description provided for @artifactTimeDone.
  ///
  /// In pt, this message translates to:
  /// **'{done} de {total}'**
  String artifactTimeDone(String done, String total);

  /// No description provided for @artifactSteps.
  ///
  /// In pt, this message translates to:
  /// **'{done} de {total} etapas'**
  String artifactSteps(int done, int total);

  /// No description provided for @artifactBlocks.
  ///
  /// In pt, this message translates to:
  /// **'em blocos de {block}'**
  String artifactBlocks(String block);

  /// No description provided for @artifactSheetSearchHint.
  ///
  /// In pt, this message translates to:
  /// **'Mapa astral, post, revolução…'**
  String get artifactSheetSearchHint;

  /// No description provided for @artifactSheetLoose.
  ///
  /// In pt, this message translates to:
  /// **'Uma entrega avulsa'**
  String get artifactSheetLoose;

  /// No description provided for @artifactSheetLooseHint.
  ///
  /// In pt, this message translates to:
  /// **'Sem tipo do catálogo: você diz quanto tempo leva'**
  String get artifactSheetLooseHint;

  /// No description provided for @catalogTitle.
  ///
  /// In pt, this message translates to:
  /// **'Catálogo'**
  String get catalogTitle;

  /// No description provided for @catalogEdit.
  ///
  /// In pt, this message translates to:
  /// **'Editar'**
  String get catalogEdit;

  /// No description provided for @catalogEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Seu catálogo está vazio'**
  String get catalogEmptyTitle;

  /// No description provided for @catalogEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Crie um tipo para o que você entrega sempre, como um mapa astral ou um post. Ele já traz o tempo, o preço e como dividir no dia.'**
  String get catalogEmptyBody;

  /// No description provided for @catalogNewType.
  ///
  /// In pt, this message translates to:
  /// **'Criar um tipo'**
  String get catalogNewType;

  /// No description provided for @catalogEmptyLooseHint.
  ///
  /// In pt, this message translates to:
  /// **'Você diz quanto tempo leva e quanto vale.'**
  String get catalogEmptyLooseHint;

  /// No description provided for @artifactNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Nome da entrega'**
  String get artifactNameHint;

  /// No description provided for @artifactChangeType.
  ///
  /// In pt, this message translates to:
  /// **'Trocar'**
  String get artifactChangeType;

  /// No description provided for @artifactTotalTime.
  ///
  /// In pt, this message translates to:
  /// **'Tempo total'**
  String get artifactTotalTime;

  /// No description provided for @artifactTimeFromType.
  ///
  /// In pt, this message translates to:
  /// **'do tipo {type}'**
  String artifactTimeFromType(String type);

  /// No description provided for @artifactSplit.
  ///
  /// In pt, this message translates to:
  /// **'No dia'**
  String get artifactSplit;

  /// No description provided for @artifactSplitWhole.
  ///
  /// In pt, this message translates to:
  /// **'Inteira'**
  String get artifactSplitWhole;

  /// No description provided for @artifactSplitBlocks.
  ///
  /// In pt, this message translates to:
  /// **'Blocos de {block}'**
  String artifactSplitBlocks(String block);

  /// No description provided for @artifactValue.
  ///
  /// In pt, this message translates to:
  /// **'Valor'**
  String get artifactValue;

  /// No description provided for @artifactDeadline.
  ///
  /// In pt, this message translates to:
  /// **'Prazo'**
  String get artifactDeadline;

  /// No description provided for @artifactCountsFor.
  ///
  /// In pt, this message translates to:
  /// **'Conta para'**
  String get artifactCountsFor;

  /// No description provided for @artifactPlace.
  ///
  /// In pt, this message translates to:
  /// **'Entra na fila'**
  String get artifactPlace;

  /// No description provided for @artifactPlaceTop.
  ///
  /// In pt, this message translates to:
  /// **'No topo'**
  String get artifactPlaceTop;

  /// No description provided for @artifactPlaceEnd.
  ///
  /// In pt, this message translates to:
  /// **'No fim'**
  String get artifactPlaceEnd;

  /// No description provided for @artifactCreate.
  ///
  /// In pt, this message translates to:
  /// **'Pôr na fila'**
  String get artifactCreate;

  /// No description provided for @goalSheetKind.
  ///
  /// In pt, this message translates to:
  /// **'Medir'**
  String get goalSheetKind;

  /// No description provided for @goalKindMoney.
  ///
  /// In pt, this message translates to:
  /// **'Faturamento'**
  String get goalKindMoney;

  /// No description provided for @goalKindCount.
  ///
  /// In pt, this message translates to:
  /// **'Quantidade'**
  String get goalKindCount;

  /// No description provided for @goalAmount.
  ///
  /// In pt, this message translates to:
  /// **'Quanto'**
  String get goalAmount;

  /// No description provided for @goalPer.
  ///
  /// In pt, this message translates to:
  /// **'Por'**
  String get goalPer;

  /// No description provided for @goalPerWeek.
  ///
  /// In pt, this message translates to:
  /// **'Semana'**
  String get goalPerWeek;

  /// No description provided for @goalPerMonth.
  ///
  /// In pt, this message translates to:
  /// **'Mês'**
  String get goalPerMonth;

  /// No description provided for @goalWhen.
  ///
  /// In pt, this message translates to:
  /// **'Quando'**
  String get goalWhen;

  /// No description provided for @goalNow.
  ///
  /// In pt, this message translates to:
  /// **'Agora'**
  String get goalNow;

  /// No description provided for @goalNextMonth.
  ///
  /// In pt, this message translates to:
  /// **'Em {month}'**
  String goalNextMonth(String month);

  /// No description provided for @goalReadbackMoney.
  ///
  /// In pt, this message translates to:
  /// **'Faturar {amount} em {month}.'**
  String goalReadbackMoney(String amount, String month);

  /// No description provided for @goalReadbackFuture.
  ///
  /// In pt, this message translates to:
  /// **'Fica guardada e passa a valer em 1º de {month}.'**
  String goalReadbackFuture(String month);

  /// No description provided for @goalCreate.
  ///
  /// In pt, this message translates to:
  /// **'Criar meta'**
  String get goalCreate;

  /// No description provided for @catalogAddType.
  ///
  /// In pt, this message translates to:
  /// **'Novo tipo'**
  String get catalogAddType;

  /// No description provided for @typeNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Nome do tipo, como Mapa astral'**
  String get typeNameHint;

  /// No description provided for @typeCategory.
  ///
  /// In pt, this message translates to:
  /// **'Categoria'**
  String get typeCategory;

  /// No description provided for @typeNewCategory.
  ///
  /// In pt, this message translates to:
  /// **'Nova'**
  String get typeNewCategory;

  /// No description provided for @typeCategoryHint.
  ///
  /// In pt, this message translates to:
  /// **'Nome da categoria, como Atendimentos'**
  String get typeCategoryHint;

  /// No description provided for @typeCreate.
  ///
  /// In pt, this message translates to:
  /// **'Guardar no catálogo'**
  String get typeCreate;

  /// No description provided for @valueOptional.
  ///
  /// In pt, this message translates to:
  /// **'opcional'**
  String get valueOptional;

  /// No description provided for @artifactKindLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get artifactKindLabel;

  /// No description provided for @goalsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Uma meta diz quanto você quer faturar, ou quantas entregas de um tipo fazer, por semana ou por mês.'**
  String get goalsEmpty;

  /// No description provided for @goalDeleteBody.
  ///
  /// In pt, this message translates to:
  /// **'As entregas continuam na fila; só a meta deixa de ser medida.'**
  String get goalDeleteBody;

  /// No description provided for @artifactsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nada na fila ainda. O + põe uma entrega nela.'**
  String get artifactsEmpty;

  /// No description provided for @artifactsNoneHere.
  ///
  /// In pt, this message translates to:
  /// **'Nada na fila com esse filtro.'**
  String get artifactsNoneHere;

  /// No description provided for @goalCountNeedsType.
  ///
  /// In pt, this message translates to:
  /// **'Crie um tipo no catálogo para contar as entregas dele.'**
  String get goalCountNeedsType;

  /// No description provided for @goalNextWeek.
  ///
  /// In pt, this message translates to:
  /// **'Semana que vem'**
  String get goalNextWeek;

  /// No description provided for @goalReadbackMoneyWeek.
  ///
  /// In pt, this message translates to:
  /// **'Faturar {amount} por semana.'**
  String goalReadbackMoneyWeek(String amount);

  /// No description provided for @goalReadbackCountMonth.
  ///
  /// In pt, this message translates to:
  /// **'{type}: {count} em {month}.'**
  String goalReadbackCountMonth(String type, String count, String month);

  /// No description provided for @goalReadbackCountWeek.
  ///
  /// In pt, this message translates to:
  /// **'{type}: {count} por semana.'**
  String goalReadbackCountWeek(String type, String count);

  /// No description provided for @goalReadbackFutureWeek.
  ///
  /// In pt, this message translates to:
  /// **'Fica guardada e passa a valer na segunda-feira.'**
  String get goalReadbackFutureWeek;
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
