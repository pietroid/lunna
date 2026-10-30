/**
 * Everything a reminder says.
 *
 * On the server so the wording can change without an app release, and in
 * Portuguese because everything the user reads is.
 */

/** The title of the reminder at the start of the day. */
export const MORNING_TITLE = 'Bom dia';

/** The title of the reminder near the end of it. */
export const EVENING_TITLE = 'Boa noite';

/** The next suggestion is written: the Feed has it. */
export const SUGGESTION_TITLE = 'Uma sugestão para o seu mês';
export const SUGGESTION_BODY = 'Tenho uma ideia para o próximo passo. Vem ver?';

/** One of these opens the day. Light, short, nothing to do yet. */
export const MORNING_MESSAGES: readonly string[] = [
  'Um dia novinho em folha. Bora?',
  'Café na mão e um passo de cada vez.',
  'Hoje é um bom dia pra fazer uma coisa bem feita.',
  'Respira fundo. O dia é seu.',
  'Começa pequeno. O resto vem.',
  'Que tal escolher uma coisa só pra hoje?',
  'O sol já levantou. E você?',
  'Devagar também chega. Bom dia!',
  'Uma coisa de cada vez, e tudo dá certo.',
  'Dia bom começa com um sorriso. Até torto vale.',
];

/** One of these closes it. Winding down, nothing left to do. */
export const EVENING_MESSAGES: readonly string[] = [
  'Hora de desacelerar. O dia já foi.',
  'O que ficou pra trás pode esperar amanhã.',
  'Desliga a tela e descansa um pouco.',
  'Você fez o que deu. Tá ótimo.',
  'Amanhã tem mais. Agora é descanso.',
  'Um chá, um livro e cama?',
  'Boa hora pra deixar a cabeça quieta.',
  'Dormir bem também é produtivo.',
  'Fecha o dia com calma. Até amanhã.',
  'O mundo continua amanhã. Pode ir dormir.',
];

/*
 * A reminder about a block is titled with the block itself ("Café") and
 * asks one plain thing under it.
 */

/** The body of a start, a task's or a fixed block's. */
export const STARTING_BODY = 'Começando agora, certo?';

/** The body of an end, the first time it is asked. */
export const ENDING_BODY = 'Terminando agora, certo?';

/** The body of an end asked again: "Atraso no término · 10 minutos". */
export function lateBody(minutes: number): string {
  return `Atraso no término · ${minutes} ${minutes === 1 ? 'minuto' : 'minutos'}`;
}

/** The body of the heads-up before a fixed block: "Começa em 15 minutos, às 12:00". */
export function headsUpBody(minutes: number, startTime: string): string {
  return `Começa em ${minutes} minutos, às ${startTime}`;
}
