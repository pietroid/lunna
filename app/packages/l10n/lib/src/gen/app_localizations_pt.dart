// dart format off
// coverage:ignore-file

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Lunna';

  @override
  String get authSignIn => 'Entrar';

  @override
  String get authSignInWithGoogle => 'Entrar com Google';

  @override
  String get authSignInFailed => 'Não foi possível entrar';

  @override
  String get shellTimelineTab => 'Tempo';

  @override
  String get shellSecondTab => 'Aba 2';

  @override
  String get shellThirdTab => 'Aba 3';

  @override
  String get shellComingSoon => 'Em breve.';

  @override
  String get shellWriteDown => 'Anotar';

  @override
  String get greetingMorning => 'Bom dia';

  @override
  String get greetingAfternoon => 'Boa tarde';

  @override
  String get greetingEvening => 'Boa noite';

  @override
  String greetingAlone(String part) {
    return '$part!';
  }

  @override
  String greetingWithName(String part, String name) {
    return '$part $name!';
  }

  @override
  String longDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat('EEEE, d \'de\' MMMM', localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get homeRoutines => 'Rotina';

  @override
  String get homeSignOut => 'Sair';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get guardStartNowTitle => 'Começar agora?';

  @override
  String guardStartNowRunning(String title, String start, String end) {
    return '$title está rodando, $start–$end.';
  }

  @override
  String get guardFinishCurrent => 'Concluir o atual';

  @override
  String get guardPostponeCurrent => 'Deixar para depois';

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
    return 'Excluir “$title”?';
  }

  @override
  String get confirmDeleteBody => 'Sai da agenda e não volta.';

  @override
  String get confirmDeleteAction => 'Excluir';

  @override
  String get confirmShortenTitle => 'Não cabe inteiro aqui';

  @override
  String confirmShortenBody(String title, int duration, int minutes) {
    return '“$title” leva $duration min e esse intervalo tem espaço para $minutes min, já contando a pausa. Ajustar para $minutes min?';
  }

  @override
  String confirmShortenAction(int minutes) {
    return 'Ajustar para $minutes min';
  }

  @override
  String confirmMoreTitle(int minutes) {
    return 'Mais $minutes minutos?';
  }

  @override
  String confirmLessTitle(int minutes) {
    return 'Menos $minutes minutos?';
  }

  @override
  String confirmMoreBody(String title, String end) {
    return '“$title” passa a terminar às $end. O que vem depois anda junto.';
  }

  @override
  String confirmLessBody(String title, String end) {
    return '“$title” passa a terminar às $end. O que vem depois adianta.';
  }

  @override
  String get confirmMoreAction => 'Adicionar';

  @override
  String get confirmLessAction => 'Tirar';

  @override
  String get eventUntitled => 'Sem título';

  @override
  String get eventStartsNow => 'Começa agora';

  @override
  String eventStartsIn(int minutes) {
    return 'Começa em $minutes min';
  }

  @override
  String eventStartsAt(String time) {
    return 'Começa às $time';
  }

  @override
  String eventStartsTomorrowAt(String time) {
    return 'Amanhã às $time';
  }

  @override
  String eventTomorrowAt(String time) {
    return 'amanhã $time';
  }

  @override
  String eventDayAt(int day, int month, String time) {
    return '$day/$month $time';
  }

  @override
  String get eventGone => 'Esse bloco não está mais no dia.';

  @override
  String get eventNotesHint => 'Anotações';

  @override
  String get restTip01 => 'Respire fundo. Três vezes, devagar.';

  @override
  String get restTip02 => 'Levante, alongue as costas e olhe pela janela.';

  @override
  String get restTip03 => 'Beba um copo d’água antes de continuar.';

  @override
  String get restTip04 => 'Feche os olhos por um minuto. Só isso.';

  @override
  String get restTip05 => 'Deixe a cabeça vazia. O próximo passo espera.';

  @override
  String get restTip06 => 'Solte os ombros. Eles estavam tensos, não estavam?';

  @override
  String get restTip07 => 'Olhe para algo longe. Seus olhos agradecem.';

  @override
  String get restTip08 => 'Nada para resolver agora. Aproveite.';

  @override
  String get restTip09 => 'Caminhe um pouco, nem que seja até a cozinha.';

  @override
  String get restTip10 => 'Um minuto de silêncio. Sem tela.';

  @override
  String get restTip11 => 'Repare no que você está ouvindo agora.';

  @override
  String get restTip12 => 'Você terminou algo. Reconheça isso.';

  @override
  String get restTip13 => 'Inspire em quatro, segure em quatro, solte em quatro.';

  @override
  String get restTip14 => 'Desligue a mente. Ela volta melhor.';

  @override
  String get restTip15 => 'Mexa as mãos, gire os pulsos, relaxe o rosto.';

  @override
  String get restTip16 => 'Pausa de verdade: sem celular.';

  @override
  String get restTip17 => 'Sinta os pés no chão por alguns segundos.';

  @override
  String get restTip18 => 'Descansar também é parte do trabalho.';

  @override
  String get restTip19 => 'Deixe o último assunto ir embora.';

  @override
  String get restTip20 => 'Medite por um instante. Só respire e observe.';

  @override
  String get freeNothingScheduled => 'Nada programado';

  @override
  String get controlStart => 'Começar';

  @override
  String get controlResume => 'Retomar';

  @override
  String get controlPause => 'Pausar';

  @override
  String get controlStartNow => 'Começar agora';

  @override
  String get controlLess15 => 'Menos 15 min';

  @override
  String get controlWait15 => 'Esperar 15 min';

  @override
  String get controlMore15 => 'Mais 15 min';

  @override
  String get controlDone => 'Concluir';

  @override
  String nowPausedLeft(String left) {
    return 'Pausado · faltam $left';
  }

  @override
  String nowLeft(String left) {
    return 'Faltam $left';
  }

  @override
  String get sectionNow => 'Agora';

  @override
  String get sectionToday => 'Ainda hoje';

  @override
  String get sectionTomorrow => 'Amanhã';

  @override
  String sectionDay(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat('EEEE, d \'de\' MMMM', localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String get timelineModeList => 'Lista';

  @override
  String get timelineModeCalendar => 'Calendário';

  @override
  String get stageSoon => 'Fazer em breve';

  @override
  String get stageBacklog => 'Depois eu priorizo';

  @override
  String get stageSoonEmpty => 'Nada na fila. Arraste uma tarefa para cá para ela ganhar uma hora.';

  @override
  String get stageBacklogEmpty => 'Nada esperando. O que você anotar fica aqui até ganhar um lugar na fila.';

  @override
  String get promptToBacklog => 'Vai para Depois eu priorizo';

  @override
  String get eventInBacklog => 'Em Depois eu priorizo, ainda sem hora';

  @override
  String get routineDaily => 'Todo dia';

  @override
  String get routineWeekdays => 'Dias úteis';

  @override
  String get routineWeekend => 'Fim de semana';

  @override
  String get failureUnreachable => 'Não consegui falar com o servidor.';

  @override
  String failureRetry(String reason) {
    return '$reason Toque para tentar de novo.';
  }

  @override
  String get timelineEmpty => 'Nada marcado. Toque no + para anotar algo.';

  @override
  String get pickerDurationTitle => 'Quanto tempo leva?';

  @override
  String get pickerTimeTitle => 'A que horas?';

  @override
  String get pickerWhenTitle => 'Quando?';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get dayToday => 'Hoje';

  @override
  String get dayTomorrow => 'Amanhã';

  @override
  String get weekdaysShort => 'seg,ter,qua,qui,sex,sáb,dom';

  @override
  String get monthsShort => 'jan,fev,mar,abr,mai,jun,jul,ago,set,out,nov,dez';

  @override
  String dayShort(String weekday, int day, String month) {
    return '$weekday, $day $month';
  }

  @override
  String get promptHint01 => 'O que precisa ser feito?';

  @override
  String get promptHint02 => 'No que vamos trabalhar?';

  @override
  String get promptHint03 => 'O que entra no dia?';

  @override
  String get promptHint04 => 'Por onde começamos?';

  @override
  String get promptHint05 => 'O que está na sua cabeça?';

  @override
  String get promptHint06 => 'Me conta o que precisa.';

  @override
  String get promptHint07 => 'Qual é a próxima?';

  @override
  String get promptHint08 => 'O que resolvemos hoje?';

  @override
  String get promptHint09 => 'Escreve aí.';

  @override
  String get promptHint10 => 'Pode falar.';

  @override
  String get promptFlexible => 'Flexível';

  @override
  String get promptFixed => 'Fixo';

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
  String get notificationChannelBlocks => 'Blocos';

  @override
  String get notificationChannelBlocksDescription => 'Quando um bloco começa e quando está perto de terminar.';

  @override
  String get notificationChannelDaily => 'Bom dia e boa noite';

  @override
  String get notificationChannelDailyDescription => 'Um recado no começo e no fim do dia.';

  @override
  String get remindersNextBlock => 'Próximo bloco';

  @override
  String get remindersAskTitle => 'Quer lembretes?';

  @override
  String get remindersAskBody => 'Pergunto quando é hora de começar um bloco, aviso dez minutos antes de acabar, e mando um bom dia e um boa noite.';

  @override
  String get remindersEnable => 'Ativar lembretes';

  @override
  String get commonNotNow => 'Agora não';

  @override
  String remindersStartTitle(String title) {
    return 'Começar “$title”?';
  }

  @override
  String get remindersStartBody => 'Enquanto você não confirmar, ele vai para mais tarde a cada minuto, e o resto do dia anda junto.';

  @override
  String get routinesHelp => 'Toque num horário para criar. Segure um bloco para mudar a hora.';

  @override
  String get routinesTitleHint => 'Almoço, rotina da manhã…';

  @override
  String get commonSave => 'Salvar';

  @override
  String get routinesDelete => 'Excluir rotina';

  @override
  String get landingHeadline => 'Seu dia, no lugar.';

  @override
  String get landingPitch => 'Lunna é um sistema pessoal de organização. Anote o que precisa ser feito e o Lunna dá uma hora para cada coisa, reorganiza o dia quando ele muda e lembra você na hora certa.';

  @override
  String get landingDemoHint => 'O celular ao lado é o app de verdade. Toque no + para anotar algo, ou num bloco para abri-lo.';

  @override
  String get landingHowTitle => 'Como funciona';

  @override
  String get landingPartTimelineTitle => 'Tempo';

  @override
  String get landingPartTimelineText => 'O dia como uma fila: o que está rodando agora, o que vem ainda hoje e o que fica para amanhã.';

  @override
  String get landingPartRoutinesTitle => 'Rotinas';

  @override
  String get landingPartRoutinesText => 'Blocos que voltam todo dia, nos dias úteis ou no fim de semana, sempre no mesmo horário.';

  @override
  String get landingPartRemindersTitle => 'Lembretes';

  @override
  String get landingPartRemindersText => 'Um aviso quando é hora de começar, outro perto do fim, e um bom dia e um boa noite.';

  @override
  String get landingDayTitle => 'No dia a dia';

  @override
  String get landingUseWrite => 'Anote o que precisa ser feito.';

  @override
  String get landingUseHour => 'Dê a cada coisa a sua hora.';

  @override
  String get landingUsePause => 'Pause, estenda ou adie, e o resto do dia anda junto.';

  @override
  String get landingUseRoutine => 'Deixe a rotina se repetir sozinha.';

  @override
  String get landingFooter => 'Lunna · Organização pessoal';

  @override
  String get demoBuilding => 'Fazendo o Lunna';

  @override
  String get demoGroceries => 'Comprar leite e ovos';

  @override
  String get demoBacklog => 'Organizar as fotos da viagem';

  @override
  String get demoStandup => 'Standup';

  @override
  String get demoDentist => 'Marcar dentista';
}
