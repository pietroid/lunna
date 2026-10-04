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

/** The body of a block's reminder at its start: "Começa agora, até 15:00". */
export function startingBody(endTime: string): string {
  return `Começa agora, até ${endTime}`;
}

/**
 * The body of a flexible block's reminder at its hour.
 *
 * It asks rather than announces: the block waits for the user, and the tap
 * is where they say whether it starts now or in a bit.
 */
export const CONFIRM_START_BODY = 'Está na hora. Começamos?';

/** The body of a block's reminder shortly before it ends. */
export function almostFinishingBody(minutes: number): string {
  return `Finaliza em ${minutes} minutos`;
}
