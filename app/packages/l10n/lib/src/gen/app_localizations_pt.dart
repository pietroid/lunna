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
  String appName(String brand) {
    String _temp0 = intl.Intl.selectLogic(
      brand,
      {
        'lunna': 'Lunna',
        'other': 'Focus',
      },
    );
    return '$_temp0';
  }

  @override
  String get authSignIn => 'Entrar';

  @override
  String get authSignInWithGoogle => 'Entrar com Google';

  @override
  String get authSignInFailed => 'Não foi possível entrar';

  @override
  String get shellTimelineTab => 'Tempo';

  @override
  String get shellProjectsTab => 'Projetos';

  @override
  String get shellMenuTab => 'Menu';

  @override
  String get menuRoutinesHint => 'Os blocos que se repetem';

  @override
  String get menuDaySection => 'Seu dia';

  @override
  String get menuArchive => 'Feitas';

  @override
  String get menuArchiveHint => 'Tudo o que você já concluiu';

  @override
  String get archiveSearch => 'Buscar nas feitas';

  @override
  String get archiveToday => 'Hoje';

  @override
  String get archiveYesterday => 'Ontem';

  @override
  String get archiveEmpty => 'Nada concluído ainda. O que você marcar como feito fica guardado aqui.';

  @override
  String get archiveNoMatch => 'Nenhuma tarefa feita com essas palavras.';

  @override
  String get archiveFailed => 'Não deu para abrir as feitas agora.';

  @override
  String get archiveRetry => 'Tentar de novo';

  @override
  String get menuDayStart => 'Começa às';

  @override
  String get menuDayEnd => 'Termina às';

  @override
  String get menuDayHelp => 'Nada entra na fila fora dessas horas.';

  @override
  String get menuDayTooShort => 'O dia precisa terminar pelo menos uma hora depois de começar.';

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
  String get eventWhenLabel => 'Horário';

  @override
  String get eventLengthLabel => 'Duração';

  @override
  String get eventProjectLabel => 'Projeto';

  @override
  String get eventNoProject => 'Nenhum';

  @override
  String get eventNotesLabel => 'Notas';

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
  String get stageBacklogEmpty => 'Nada esperando. Arraste para cá o que ainda não tem lugar na fila.';

  @override
  String stageDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count feitas',
      one: '1 feita',
      zero: 'Feitas',
    );
    return '$_temp0';
  }

  @override
  String get stageDoneEmpty => 'Nada feito ainda. Arraste uma tarefa para a direita quando terminar.';

  @override
  String get promptToBacklog => 'Vai para Depois eu priorizo';

  @override
  String get promptToQueue => 'Entra na fila, onde houver espaço';

  @override
  String get promptPickTime => 'Escolher horário';

  @override
  String get timelineAdd => 'Adicionar';

  @override
  String get timelineBackToNow => 'Voltar para agora';

  @override
  String get eventInBacklog => 'Em Depois eu priorizo, ainda sem hora';

  @override
  String eventDoneOn(String day, String time) {
    return 'Feita $day, às $time';
  }

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
  String landingPitch(String brand) {
    String _temp0 = intl.Intl.selectLogic(
      brand,
      {
        'lunna': 'A Lunna é um sistema pessoal de organização. Anote o que precisa ser feito e a Lunna dá uma hora para cada coisa, reorganiza o dia quando ele muda e lembra você na hora certa.',
        'other': 'O Focus é um sistema pessoal de organização. Anote o que precisa ser feito e o Focus dá uma hora para cada coisa, reorganiza o dia quando ele muda e lembra você na hora certa.',
      },
    );
    return '$_temp0';
  }

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
  String landingFooter(String brand) {
    String _temp0 = intl.Intl.selectLogic(
      brand,
      {
        'lunna': 'Lunna',
        'other': 'Focus',
      },
    );
    return '$_temp0 · Organização pessoal';
  }

  @override
  String demoBuilding(String brand) {
    String _temp0 = intl.Intl.selectLogic(
      brand,
      {
        'lunna': 'Fazendo a Lunna',
        'other': 'Fazendo o Focus',
      },
    );
    return '$_temp0';
  }

  @override
  String get demoGroceries => 'Comprar leite e ovos';

  @override
  String get demoBacklog => 'Organizar as fotos da viagem';

  @override
  String get demoStandup => 'Standup';

  @override
  String get demoDentist => 'Marcar dentista';

  @override
  String agentAsk(String brand) {
    String _temp0 = intl.Intl.selectLogic(
      brand,
      {
        'lunna': 'Pergunte à Lunna…',
        'other': 'Pergunte ao Focus…',
      },
    );
    return '$_temp0';
  }

  @override
  String agentSuggestionLabel(String brand) {
    String _temp0 = intl.Intl.selectLogic(
      brand,
      {
        'lunna': 'Sugestão da Lunna',
        'other': 'Sugestão do Focus',
      },
    );
    return '$_temp0';
  }

  @override
  String get agentInputHint => 'Pergunte ou peça algo…';

  @override
  String get agentReplyHint => 'Responder…';

  @override
  String get agentThinking => 'Olhando seu dia…';

  @override
  String get agentSend => 'Enviar';

  @override
  String get agentClose => 'Fechar';

  @override
  String get agentApply => 'Aplicar';

  @override
  String get agentAdjust => 'Ajustar';

  @override
  String get agentApplied => 'Aplicado';

  @override
  String agentChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mudanças',
      one: '1 mudança',
    );
    return '$_temp0';
  }

  @override
  String get agentChangeAddTask => 'nova tarefa';

  @override
  String get agentChangeAddEvent => 'novo bloco fixo';

  @override
  String get agentChangeMoved => 'movida';

  @override
  String get agentChangeRoutine => 'rotina, só nesse dia';

  @override
  String get agentChangeFromBacklog => 'saiu do Depois eu priorizo';

  @override
  String get agentUndo => 'Desfazer';

  @override
  String get agentEarlier => 'Conversas anteriores';

  @override
  String get agentEarlierFailed => 'Não consegui trazer as conversas anteriores. Toque para tentar de novo.';

  @override
  String agentHistoryToday(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat('HH:mm', localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Hoje · $timeString';
  }

  @override
  String agentHistoryYesterday(DateTime day, DateTime time) {
    final intl.DateFormat dayDateFormat = intl.DateFormat.EEEE(localeName);
    final String dayString = dayDateFormat.format(day);
    final intl.DateFormat timeDateFormat = intl.DateFormat('HH:mm', localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Ontem, $dayString · $timeString';
  }

  @override
  String agentHistoryDay(DateTime day, DateTime time) {
    final intl.DateFormat dayDateFormat = intl.DateFormat('EEE, d \'de\' MMM', localeName);
    final String dayString = dayDateFormat.format(day);
    final intl.DateFormat timeDateFormat = intl.DateFormat('HH:mm', localeName);
    final String timeString = timeDateFormat.format(time);

    return '$dayString · $timeString';
  }

  @override
  String agentHistoryNow(DateTime time) {
    final intl.DateFormat timeDateFormat = intl.DateFormat('HH:mm', localeName);
    final String timeString = timeDateFormat.format(time);

    return 'Agora · $timeString';
  }

  @override
  String agentPlanSummary(String changes, String status) {
    return '$changes · $status';
  }

  @override
  String get agentPlanApplied => 'aplicado';

  @override
  String get agentPlanUndone => 'desfeito';

  @override
  String get agentPlanNotApplied => 'não aplicado';

  @override
  String agentPushedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count empurradas',
      one: '1 empurrada',
    );
    return '$_temp0';
  }

  @override
  String get agentChangePushed => 'empurrada';

  @override
  String get agentPush => 'Mover';

  @override
  String get agentOtherTime => 'Outro horário';

  @override
  String get agentOtherTimeDraft => 'Prefiro outro horário: ';

  @override
  String get agentSuggestionAccept => 'Encaixar';

  @override
  String get agentSuggestionDismiss => 'Agora não';

  @override
  String get agentFailure => 'Algo deu errado. Tente de novo.';

  @override
  String get agentFailureModelDown => 'Não consegui falar com o modelo agora, nem tentando duas vezes.';

  @override
  String get agentFailureModelEmpty => 'O modelo respondeu em branco, duas vezes.';

  @override
  String get agentFailureDrift => 'Seu dia mudou desde esse plano e ele não cabe mais. Peça de novo.';

  @override
  String get agentFailureOffline => 'Sem conexão com o servidor.';

  @override
  String get agentFailureBug => 'Algo deu errado do meu lado. Ficou registrado.';

  @override
  String get agentRetry => 'Tentar de novo';

  @override
  String get agentDetails => 'Detalhes';

  @override
  String agentTrace(String id) {
    return 'Código $id';
  }

  @override
  String agentPlaceBetween(String after, String before) {
    return 'entre $after e $before';
  }

  @override
  String agentPlaceAfter(String after) {
    return 'depois de $after';
  }

  @override
  String agentPlaceBefore(String before) {
    return 'antes de $before';
  }

  @override
  String get agentPlaceEnd => 'no fim da fila';

  @override
  String agentAssumed(String what) {
    return 'Assumi $what';
  }

  @override
  String get agentAssumedToday => 'que é para hoje';

  @override
  String get agentAssumedEnd => 'o fim da fila';

  @override
  String get agentVoiceStart => 'Falar';

  @override
  String get agentVoiceListening => 'Ouvindo';

  @override
  String get agentVoiceStopped => 'Parei de ouvir no limite de 1 minuto';

  @override
  String get agentVoiceHint => 'Pode falar. Eu escrevo enquanto você fala.';

  @override
  String get agentVoiceDiscard => 'Descartar';

  @override
  String get agentVoiceStop => 'Parar e revisar';

  @override
  String get agentVoiceOpen => 'Abrir a conversa';

  @override
  String get agentVoiceSlideCancel => 'Deslize para cancelar';

  @override
  String get agentVoiceLock => 'Gravar sem segurar';

  @override
  String get agentVoiceSend => 'Enviar';

  @override
  String agentVoiceVia(String length) {
    return 'por voz · $length';
  }

  @override
  String agentVoiceDenied(String brand) {
    String _temp0 = intl.Intl.selectLogic(
      brand,
      {
        'lunna': 'A Lunna não tem acesso ao microfone. Libere nos Ajustes do aparelho.',
        'other': 'O Focus não tem acesso ao microfone. Libere nos Ajustes do aparelho.',
      },
    );
    return '$_temp0';
  }

  @override
  String get agentVoiceUnavailable => 'Este aparelho não reconhece fala em português.';

  @override
  String projectsOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count em andamento',
      one: '1 em andamento',
      zero: 'Nenhum em andamento',
    );
    return '$_temp0';
  }

  @override
  String get projectsDoneSection => 'Concluídos';

  @override
  String get projectsEmpty => 'Um projeto junta as tarefas de um mesmo assunto, com prazo ou sem.';

  @override
  String get projectsNew => 'Novo projeto';

  @override
  String get projectUntitled => 'Sem nome';

  @override
  String get projectNoDeadline => 'Sem prazo';

  @override
  String get projectGiveDeadline => 'Dar um prazo';

  @override
  String projectUntil(String date) {
    return 'até $date';
  }

  @override
  String projectDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'faltam $days dias',
      one: 'falta 1 dia',
      zero: 'termina hoje',
    );
    return '$_temp0';
  }

  @override
  String projectOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'atrasado $days dias',
      one: 'atrasado 1 dia',
    );
    return '$_temp0';
  }

  @override
  String projectTaskCount(int done, int total) {
    return '$done de $total';
  }

  @override
  String projectDoneOn(String date) {
    return 'concluído $date';
  }

  @override
  String get projectMinusDay => '−1 dia';

  @override
  String get projectPlusDay => '+1 dia';

  @override
  String get projectLessDay => 'Um dia a menos';

  @override
  String get projectMoreDay => 'Um dia a mais';

  @override
  String projectTasksTab(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tarefas · $count',
      zero: 'Tarefas',
    );
    return '$_temp0';
  }

  @override
  String get projectNotesTab => 'Notas';

  @override
  String get projectDeadlineLabel => 'Prazo';

  @override
  String get projectProgressLabel => 'Feitas';

  @override
  String get projectNotesHint => 'Escreva o que quiser sobre o projeto…';

  @override
  String get projectAddTask => 'Nova tarefa';

  @override
  String projectTasksDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count feitas',
      one: '1 feita',
    );
    return '$_temp0';
  }

  @override
  String get projectSheetHint => 'Qual é o projeto?';

  @override
  String get projectSheetOpenEnded => 'Sem data para acabar';

  @override
  String get projectWeek => '1 semana';

  @override
  String get projectMonth => '1 mês';

  @override
  String get projectPickDay => 'Escolher dia';

  @override
  String get projectDeleteBody => 'As tarefas em Depois eu priorizo vão junto. As que já estão em Fazer em breve, e as feitas, ficam no Tempo.';

  @override
  String dayOverTitle(String end) {
    return 'Seu dia terminou às $end';
  }

  @override
  String dayOverBody(String start) {
    return 'Nada começa agora. A fila volta a andar amanhã às $start.';
  }

  @override
  String dayNotYetTitle(String start) {
    return 'Seu dia começa às $start';
  }

  @override
  String get dayNotYetBody => 'Nada começa antes disso. Até lá, descanse.';

  @override
  String get dayClosedAdjust => 'Mudar horário';

  @override
  String get dayClosedRefused => 'Agora não: seu dia terminou';

  @override
  String get vacatedTitle => 'Agora fica livre';

  @override
  String get vacatedBody => 'Solte para pausar: ela volta para a fila com o que falta.';

  @override
  String dragHintPause(String left) {
    return 'Pausar · volta com $left';
  }

  @override
  String dragHintShift(String delta, String hour) {
    return '$delta · $hour';
  }

  @override
  String dragHintResize(String delta, String hour) {
    return '$delta · até $hour';
  }

  @override
  String dragHintTomorrowAt(String hour) {
    return 'amanhã $hour';
  }

  @override
  String minutesDelta(String sign, String minutes) {
    return '$sign$minutes min';
  }

  @override
  String dragHintSwapWith(String title) {
    return 'Trocar com $title';
  }

  @override
  String dragHintMoveTo(String when) {
    return 'Para $when';
  }

  @override
  String get dictationStart => 'Ditar nas anotações';

  @override
  String get dictationStop => 'Parar de ditar';

  @override
  String get dictationDiscard => 'Descartar este parágrafo';

  @override
  String get agentApplyDelete => 'Apagar';

  @override
  String get agentChangeRenamed => 'novo nome';

  @override
  String get agentChangeLength => 'duração';

  @override
  String get agentChangeNotes => 'notas';

  @override
  String get agentChangeDone => 'concluída';

  @override
  String get agentChangeRemove => 'apagar';

  @override
  String get agentChangeNewProject => 'novo projeto';

  @override
  String get agentChangeDeadline => 'prazo';

  @override
  String get agentChangeProjectDone => 'projeto concluído';

  @override
  String agentChangeRemoveProject(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'apagar o projeto e $count tarefas',
      one: 'apagar o projeto e 1 tarefa',
      zero: 'apagar o projeto',
    );
    return '$_temp0';
  }

  @override
  String agentFree(String span) {
    return '$span livre';
  }

  @override
  String agentCardsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarefas',
      one: '1 tarefa',
    );
    return '$_temp0';
  }

  @override
  String agentProjectDone(int done, int total) {
    return '$done de $total feitas';
  }

  @override
  String get agentProjectNext => 'Próximas';

  @override
  String agentProjectMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $count',
      one: 'mais 1',
    );
    return '$_temp0';
  }

  @override
  String get agentProjectOpen => 'Abrir projeto';

  @override
  String get shellArtifactsTab => 'Entregas';

  @override
  String get monthsLong => 'janeiro,fevereiro,março,abril,maio,junho,julho,agosto,setembro,outubro,novembro,dezembro';

  @override
  String get artifactsSearch => 'Buscar entregas';

  @override
  String get artifactsSearchHint => 'Buscar por nome, cliente ou tipo';

  @override
  String get goalsSection => 'Metas';

  @override
  String get goalNew => 'Nova meta';

  @override
  String get goalRevenue => 'Faturamento';

  @override
  String goalInMonth(String label, String month) {
    return '$label · $month';
  }

  @override
  String goalThisWeek(String label) {
    return '$label · esta semana';
  }

  @override
  String goalOf(String target) {
    return 'de $target';
  }

  @override
  String goalDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'faltam $days dias',
      one: 'falta 1 dia',
      zero: 'termina hoje',
    );
    return '$_temp0';
  }

  @override
  String goalStartsOn(String date) {
    return 'começa $date';
  }

  @override
  String get goalDone => 'feito';

  @override
  String goalQueued(String value) {
    return 'na fila $value';
  }

  @override
  String goalMissing(String value) {
    return 'faltam $value';
  }

  @override
  String get goalCovered => 'a fila cobre o resto';

  @override
  String goalSchedule(String need, String free, String date) {
    return 'A fila pede $need · você tem $free livres até $date';
  }

  @override
  String get artifactsQueue => 'Fila';

  @override
  String artifactsQueueSummary(int count, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entregas',
      one: '1 entrega',
    );
    return '$_temp0 · $time';
  }

  @override
  String get artifactsAll => 'Todas';

  @override
  String artifactsSeeAll(int count) {
    return 'Ver todas as $count';
  }

  @override
  String get artifactsAllTitle => 'Todas as entregas';

  @override
  String get artifactsInQueue => 'Na fila';

  @override
  String get artifactsDone => 'Feitas';

  @override
  String artifactsDoneOn(String date) {
    return 'feita $date';
  }

  @override
  String artifactsNoResults(String query) {
    return 'Nada com “$query”.';
  }

  @override
  String get artifactsNew => 'Nova entrega';

  @override
  String get artifactLoose => 'Avulsa';

  @override
  String artifactDue(String date) {
    return 'até $date';
  }

  @override
  String artifactTimeDone(String done, String total) {
    return '$done de $total';
  }

  @override
  String artifactSteps(int done, int total) {
    return '$done de $total etapas';
  }

  @override
  String artifactBlocks(String block) {
    return 'em blocos de $block';
  }

  @override
  String get artifactSheetSearchHint => 'Mapa astral, post, revolução…';

  @override
  String get artifactSheetLoose => 'Uma entrega avulsa';

  @override
  String get artifactSheetLooseHint => 'Sem tipo do catálogo: você diz quanto tempo leva';

  @override
  String get catalogTitle => 'Catálogo';

  @override
  String get catalogEdit => 'Editar';

  @override
  String get catalogEmptyTitle => 'Seu catálogo está vazio';

  @override
  String get catalogEmptyBody => 'Crie um tipo para o que você entrega sempre, como um mapa astral ou um post. Ele já traz o tempo, o preço e como dividir no dia.';

  @override
  String get catalogNewType => 'Criar um tipo';

  @override
  String get catalogEmptyLooseHint => 'Você diz quanto tempo leva. Depois dá para guardá-la como tipo.';

  @override
  String get artifactNameHint => 'Nome da entrega';

  @override
  String get artifactChangeType => 'Trocar';

  @override
  String get artifactTotalTime => 'Tempo total';

  @override
  String artifactTimeFromType(String type) {
    return 'do tipo $type';
  }

  @override
  String get artifactSplit => 'No dia';

  @override
  String get artifactSplitWhole => 'Inteira';

  @override
  String artifactSplitBlocks(String block) {
    return 'Blocos de $block';
  }

  @override
  String get artifactValue => 'Valor';

  @override
  String get artifactDeadline => 'Prazo';

  @override
  String get artifactCountsFor => 'Conta para';

  @override
  String get artifactPlace => 'Entra na fila';

  @override
  String get artifactPlaceTop => 'No topo';

  @override
  String get artifactPlaceEnd => 'No fim';

  @override
  String get artifactCreate => 'Pôr na fila';

  @override
  String get goalSheetKind => 'Medir';

  @override
  String get goalKindMoney => 'Faturamento';

  @override
  String get goalKindCount => 'Quantidade';

  @override
  String get goalAmount => 'Quanto';

  @override
  String get goalPer => 'Por';

  @override
  String get goalPerWeek => 'Semana';

  @override
  String get goalPerMonth => 'Mês';

  @override
  String get goalWhen => 'Quando';

  @override
  String get goalNow => 'Agora';

  @override
  String goalNextMonth(String month) {
    return 'Em $month';
  }

  @override
  String goalReadbackMoney(String amount, String month) {
    return 'Faturar $amount em $month.';
  }

  @override
  String goalReadbackFuture(String month) {
    return 'Fica guardada e passa a valer em 1º de $month.';
  }

  @override
  String get goalCreate => 'Criar meta';
}
