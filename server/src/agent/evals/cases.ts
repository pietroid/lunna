/**
 * The agent's eval cases: a day, a clock, what the person says, and a check
 * on the day the agent leaves, not on its words. A case may be passed by any
 * route the model takes, as long as the day ends right.
 *
 * Every case is in São Paulo. "Friday" is Friday 16 October 2026.
 */

/** What a case's day is written with. */
export interface World {
  /** A task in the queue, or with `at` ("YYYY-MM-DD HH:mm") an hour of its own, or in the backlog. */
  task(
    title: string,
    minutes: number,
    opts?: { at?: string; backlog?: boolean; artifact?: string },
  ): Promise<void>;
  /** An artifact, answering its id for its tasks' `artifact`. */
  artifact(
    title: string,
    deadline?: string,
    opts?: { value?: number; kind?: string },
  ): Promise<string>;
  /** A kind of the catalogue, on a shelf, answering its id. */
  kind(
    name: string,
    shelf: string,
    minutes: number,
    price?: number,
  ): Promise<string>;
  /** A money goal, by its last day (`YYYY-MM-DD`). */
  goal(target: number, deadline: string): Promise<void>;
  /** A fixed block at "YYYY-MM-DD HH:mm". */
  event(title: string, at: string, minutes?: number): Promise<void>;
}

/** One card of the day the agent left, as a check reads it. */
export interface Seen {
  title: string;
  kind: 'task' | 'event';
  /** "YYYY-MM-DD HH:mm" in São Paulo. Absent in the backlog. */
  at?: string;
  minutes: number;
  anchored: boolean;
  backlog: boolean;
}

/** A delivery, as a check reads it. */
export interface SeenArtifact {
  title: string;
  done: boolean;
  deadline?: string;
  value?: number;
  /** Its kind's name. */
  kind?: string;
  /** Its tasks' titles, done ones included. */
  tasks: string[];
}

/** The day after the turn, and after Aplicar when there was a plan. */
export interface State {
  cards: Seen[];
  /** Every delivery, open ones in their order, then the delivered. */
  artifacts: SeenArtifact[];
  /** The catalogue's kinds, by name. */
  kinds: string[];
  goals: { kind: 'money' | 'count'; target: number; deadline: string }[];
  /** The tasks with an hour, in the list's order. */
  queue: string[];
  /** Every card titled like [title], any case or accent. */
  named(title: string): Seen[];
}

/**
 * What the turn must come to:
 * - `plan`: a plan, which is applied and then checked;
 * - `ask`: a question (a doubt with options, or a reply asking), no plan;
 * - `answer`: a reply with no plan and no question needed;
 * - `either`: a plan or a question; a plan is applied and checked.
 */
export type Expect = 'plan' | 'ask' | 'answer' | 'either';

export interface Case {
  id: string;
  /** Why it is here: a reported bug, or what it covers. */
  why: string;
  /** "YYYY-MM-DD HH:mm" in São Paulo. Friday 15:00 when absent. */
  now?: string;
  /** What the person says; several are turns of one conversation. */
  said: string | string[];
  setup?: (world: World) => Promise<void>;
  expect: Expect;
  /** A block the answer must draw (`day`, `cards`, `artifact`…). */
  drawn?: string;
  /** True, or what was wrong. */
  check?: (state: State) => true | string;
}

const FRIDAY = '2026-10-16';
const OCTOBER_30 = '2026-10-30';
const SATURDAY = '2026-10-17';

/** A check that [title] is there exactly once, at [at] when given. */
function once(title: string, at?: string, minutes?: number) {
  return (state: State): true | string => {
    const found = state.named(title);
    if (found.length !== 1) return `${found.length} cards titled ${title}`;
    if (at !== undefined && found[0].at !== at) {
      return `${title} at ${found[0].at ?? 'backlog'}, wanted ${at}`;
    }
    if (minutes !== undefined && found[0].minutes !== minutes) {
      return `${title} takes ${found[0].minutes} min, wanted ${minutes}`;
    }
    return true;
  };
}

function all(...checks: ((state: State) => true | string)[]) {
  return (state: State): true | string => {
    for (const check of checks) {
      const result = check(state);
      if (result !== true) return result;
    }
    return true;
  };
}

/** A check that exactly one delivery is like [title], and passes [ok]. */
function delivery(
  title: string,
  ok: (it: SeenArtifact) => true | string = () => true,
) {
  return (state: State): true | string => {
    const found = state.artifacts.filter((it) =>
      it.title.toLowerCase().includes(title.toLowerCase()),
    );
    if (found.length !== 1) return `${found.length} deliveries like ${title}`;
    return ok(found[0]);
  };
}

/** A check that [titles] come in this order in the list. */
function inOrder(...titles: string[]) {
  return (state: State): true | string => {
    const at = titles.map((t) =>
      state.queue.findIndex((q) => q.toLowerCase() === t.toLowerCase()),
    );
    if (at.some((i) => i < 0))
      return `missing from the list: ${titles.filter((_, i) => at[i] < 0).join(', ')}`;
    for (let i = 1; i < at.length; i++) {
      if (at[i] < at[i - 1]) return `order is ${state.queue.join(' → ')}`;
    }
    return true;
  };
}

export const CASES: Case[] = [
  // ---- The reported bugs, as regressions --------------------------------
  {
    id: 'move-event-tomorrow',
    why: 'bug 2: "move my event" made a duplicate',
    setup: (w) => w.event('Dentista', `${FRIDAY} 17:00`),
    said: 'passa o dentista pra amanhã às 9',
    expect: 'plan',
    check: once('Dentista', `${SATURDAY} 09:00`),
  },
  {
    id: 'move-event-not-today',
    why: 'bug 2: an event on another day was never read',
    setup: (w) => w.event('Dentista', '2026-10-20 10:00'),
    said: 'muda o dentista de terça pras 14h',
    expect: 'plan',
    check: once('Dentista', '2026-10-20 14:00'),
  },
  {
    id: 'between-is-a-place',
    why: 'bug 3: "between" pinned an hour instead of a place in the queue',
    setup: async (w) => {
      await w.task('Academia', 60);
      await w.task('Responder e-mails', 30);
      await w.event('Jantar', `${FRIDAY} 19:30`);
    },
    said: 'coloca revisar a proposta, 45 min, entre a academia e os e-mails',
    expect: 'plan',
    check: all(
      once('Revisar a proposta', undefined, 45),
      inOrder('Academia', 'Revisar a proposta', 'Responder e-mails'),
      (s) =>
        s.named('Revisar a proposta')[0].anchored
          ? 'it was pinned to an hour'
          : true,
    ),
  },
  {
    id: 'tomorrow-after-hours',
    why: 'bug 4: today and tomorrow mixed up after the working day',
    now: `${FRIDAY} 22:30`,
    said: 'coloca ler artigo amanhã às 8',
    expect: 'plan',
    check: once('Ler artigo', `${SATURDAY} 08:00`),
  },
  {
    id: 'today-is-over',
    why: 'bug 4: "hoje" after the working day has no room',
    now: `${FRIDAY} 22:30`,
    said: 'encaixa ligar pro banco hoje',
    expect: 'either',
    check: (s) =>
      s.named('Ligar pro banco').some((it) => it.at?.startsWith(FRIDAY))
        ? 'put on a day already over'
        : true,
  },
  {
    id: 'move-anchored-task',
    why: 'bug 5: anchors left by earlier moves made the next one refused',
    setup: (w) => w.task('Responder e-mails', 30, { at: `${FRIDAY} 16:00` }),
    said: 'passa responder e-mails pra amanhã às 10',
    expect: 'plan',
    check: once('Responder e-mails', `${SATURDAY} 10:00`),
  },

  // ---- Hours -------------------------------------------------------------
  {
    id: 'new-task-at-hour',
    why: 'a new task at a named hour',
    said: 'marca pagar boleto hoje às 17h',
    expect: 'plan',
    check: once('Pagar boleto', `${FRIDAY} 17:00`),
  },
  {
    id: 'new-meeting',
    why: 'a meeting is a fixed event, with its length',
    said: 'marca reunião com a Ana amanhã às 14h, 1 hora',
    expect: 'plan',
    check: all(once('Reunião com a Ana', `${SATURDAY} 14:00`, 60), (s) =>
      s.named('Reunião com a Ana')[0].kind === 'event'
        ? true
        : 'a meeting became a task',
    ),
  },
  {
    id: 'weekday',
    why: 'a weekday resolved by the server',
    said: 'marca academia sábado às 9',
    expect: 'plan',
    check: once('Academia', `${SATURDAY} 09:00`),
  },
  {
    id: 'next-monday',
    why: 'a weekday past the weekend',
    said: 'coloca correr na segunda às 7',
    expect: 'plan',
    check: once('Correr', '2026-10-19 07:00'),
  },
  {
    id: 'length-said',
    why: 'the length the person said is kept',
    said: 'adiciona estudar inglês amanhã às 10 por 1h30',
    expect: 'plan',
    check: once('Estudar inglês', `${SATURDAY} 10:00`, 90),
  },
  {
    id: 'move-task-other-day',
    why: 'a queued task to another day and hour',
    setup: (w) => w.task('Lavar o carro', 60),
    said: 'passa lavar o carro pra domingo às 10',
    expect: 'plan',
    check: once('Lavar o carro', '2026-10-18 10:00'),
  },
  {
    id: 'event-pushes',
    why: 'an hour that pushes the queue keeps the hour',
    setup: async (w) => {
      await w.task('Revisar proposta', 60);
      await w.task('Responder e-mails', 30);
    },
    said: 'marca médico hoje às 15:30, 1 hora',
    expect: 'either',
    check: once('Médico', `${FRIDAY} 15:30`, 60),
  },

  // ---- Places ------------------------------------------------------------
  {
    id: 'after-event',
    why: 'after a fixed block is that block’s end plus the pause',
    setup: (w) => w.event('Café com a Bia', `${FRIDAY} 16:00`, 30),
    said: 'coloca revisar contrato depois do café com a Bia',
    expect: 'plan',
    check: once('Revisar contrato', `${FRIDAY} 16:35`),
  },
  {
    id: 'before-task',
    why: 'before a task is a place in the queue',
    setup: async (w) => {
      await w.task('Responder e-mails', 30);
      await w.task('Ler artigo', 30);
    },
    said: 'põe ligar pra mãe antes de ler artigo',
    expect: 'plan',
    check: all(
      once('Ligar pra mãe'),
      inOrder('Responder e-mails', 'Ligar pra mãe', 'Ler artigo'),
    ),
  },
  {
    id: 'to-backlog',
    why: 'back to Para depois',
    setup: (w) => w.task('Organizar fotos', 60),
    said: 'deixa organizar fotos pra depois',
    expect: 'plan',
    check: (s) =>
      s.named('Organizar fotos')[0]?.backlog ? true : 'not in the backlog',
  },
  {
    id: 'from-backlog-today',
    why: 'a backlog task into today, with no hour said',
    setup: (w) => w.task('Relatório mensal', 60, { backlog: true }),
    said: 'encaixa o relatório mensal hoje quando der',
    expect: 'plan',
    check: all(once('Relatório mensal'), (s) =>
      s.named('Relatório mensal')[0].at?.startsWith(FRIDAY)
        ? true
        : 'not today',
    ),
  },
  {
    id: 'swap',
    why: 'two tasks trade places',
    setup: async (w) => {
      await w.task('Responder e-mails', 30);
      await w.task('Ler artigo', 30);
    },
    said: 'troca responder e-mails com ler artigo',
    expect: 'plan',
    check: inOrder('Ler artigo', 'Responder e-mails'),
  },

  // ---- Doubts, questions, and nothing to do ------------------------------
  {
    id: 'question',
    why: 'a question gets an answer and no plan',
    setup: async (w) => {
      await w.event('Dentista', `${SATURDAY} 10:00`);
      await w.task('Academia', 60, { at: `${SATURDAY} 08:00` });
    },
    said: 'o que eu tenho amanhã?',
    expect: 'answer',
  },
  {
    id: 'duplicate-asks',
    why: 'something new named like a card already there is asked about',
    setup: (w) => w.event('Dentista', `${FRIDAY} 17:00`),
    said: 'marca dentista amanhã às 9',
    // Asking, or moving the one there: never a silent second Dentista.
    expect: 'either',
    check: once('Dentista', `${SATURDAY} 09:00`),
  },
  {
    id: 'not-a-duplicate',
    why: 'a different appointment is not asked about',
    setup: (w) => w.event('Dentista', `${FRIDAY} 17:00`),
    said: 'marca oftalmologista amanhã às 9',
    expect: 'plan',
    check: all(
      once('Oftalmologista', `${SATURDAY} 09:00`),
      once('Dentista', `${FRIDAY} 17:00`),
    ),
  },
  {
    id: 'no-hour',
    why: 'something new with no hour: proposed from facts, never silent',
    said: 'preciso treinar hoje',
    expect: 'plan',
    check: once('Treinar'),
  },
  {
    id: 'blocked-by-event',
    why: 'a task at an hour a fixed event keeps cannot be had',
    setup: (w) => w.event('Reunião', `${FRIDAY} 16:00`),
    said: 'coloca ligar pro banco às 16h',
    expect: 'either',
    check: (s) =>
      s.named('Ligar pro banco').some((it) => it.at === `${FRIDAY} 16:00`)
        ? 'on top of the meeting'
        : true,
  },
  {
    id: 'two-matches',
    why: 'a reference with two matches is asked about',
    setup: async (w) => {
      await w.task('Ligar pro João', 15);
      await w.task('Ligar pro banco', 15);
    },
    said: 'move a ligação pra amanhã às 9',
    expect: 'ask',
  },
  {
    id: 'afternoon-shown',
    why: 'a question about the day is answered with the day, not prose (§5.3)',
    now: `${FRIDAY} 12:00`,
    setup: async (w) => {
      await w.event('Reunião', `${FRIDAY} 14:00`);
      await w.task('Ler artigo', 30, { backlog: true });
    },
    said: 'como está minha tarde?',
    expect: 'answer',
    drawn: 'day',
  },
  {
    id: 'artifact-from-tempo',
    why: 'an artifact is reached from Tempo, through the index (§5.4)',
    setup: async (w) => {
      const tese = await w.artifact('Tese', '2026-11-30');
      await w.task('Escrever capítulo 2', 90, {
        backlog: true,
        artifact: tese,
      });
      await w.task('Revisar bibliografia', 45, {
        backlog: true,
        artifact: tese,
      });
    },
    said: 'põe o capítulo 2 da tese amanhã às 9',
    expect: 'plan',
    check: once('Escrever capítulo 2', `${SATURDAY} 09:00`),
  },
  {
    id: 'multi-organize',
    why: 'an open request, then a pick in words: two turns to one plan (§5.1)',
    now: `${FRIDAY} 13:00`,
    setup: async (w) => {
      await w.task('Troca 2', 60, { backlog: true });
      await w.task('Ler artigo', 30, { backlog: true });
    },
    said: ['organiza minha tarde', 'só a Troca 2, às 15h'],
    expect: 'plan',
    check: once('Troca 2', `${FRIDAY} 15:00`),
  },
  {
    id: 'multi-refs',
    why: 'a card named in an earlier turn keeps its meaning (stable refs)',
    setup: async (w) => {
      await w.task('Dentista', 60, { at: `${FRIDAY} 16:00` });
    },
    said: ['o que tenho hoje?', 'passa o dentista para amanhã às 10'],
    expect: 'plan',
    check: once('Dentista', `${SATURDAY} 10:00`),
  },
  {
    id: 'multi-backlog',
    why: 'the backlog is named in the app’s words across turns',
    setup: async (w) => {
      await w.task('Pagar boleto', 15, { backlog: true });
    },
    said: ['o que tem no depois eu priorizo?', 'coloca o boleto hoje às 17h'],
    expect: 'plan',
    check: once('Pagar boleto', `${FRIDAY} 17:00`),
  },

  // ---- Deliveries, the catalogue and the goals (RFC agent-full-surface) --
  // Each built around the verb's trap (its "Writes, verb by verb").
  {
    id: 'delivery-new-with-tasks',
    why: 'new_artifact: a delivery and its tasks in one plan (forward refs)',
    said: 'cria a entrega Curso de tarot pra 30/10 com duas tarefas: gravar as aulas, 2 horas, e editar, 1 hora',
    expect: 'plan',
    check: delivery('Curso de tarot', (it) =>
      it.deadline !== OCTOBER_30
        ? `due ${it.deadline ?? 'never'}`
        : it.tasks.length !== 2
          ? `${it.tasks.length} tasks: ${it.tasks.join(', ')}`
          : true,
    ),
  },
  {
    id: 'delivery-twice',
    why: 'new_artifact: "cria a Tese" when it exists makes a second one',
    setup: async (w) => {
      await w.artifact('Tese', '2026-11-30');
    },
    said: 'cria a entrega tese pra 30/11',
    expect: 'either',
    check: delivery('Tese'),
  },
  {
    id: 'delivery-task-for-it',
    why: 'new { artifact }: a task written into the wrong delivery',
    setup: async (w) => {
      await w.artifact('Tese', '2026-11-30');
      await w.artifact('Curso de tarot', OCTOBER_30);
    },
    said: 'anota revisar bibliografia na tese, 1 hora, no depois eu priorizo',
    expect: 'plan',
    check: all(
      once('Revisar bibliografia', undefined, 60),
      delivery('Tese', (it) =>
        it.tasks.some((t) => /bibliografia/i.test(t))
          ? true
          : `Tese has ${it.tasks.join(', ') || 'no tasks'}`,
      ),
    ),
  },
  {
    id: 'deliver-open-tasks',
    why: 'deliver: with tasks still open, the money counts now',
    setup: async (w) => {
      const tese = await w.artifact('Tese', '2026-11-30', { value: 1500 });
      await w.task('Revisão final', 60, { backlog: true, artifact: tese });
    },
    said: 'entreguei a tese hoje',
    expect: 'either',
    check: delivery('Tese', (it) => (it.done ? true : 'still open')),
  },
  {
    id: 'kind-named-loosely',
    why: 'new_artifact { kind }: "um mapa" for Mapa astral',
    setup: async (w) => {
      await w.kind('Mapa astral', 'Atendimentos', 90, 250);
      await w.kind('Leitura de tarot', 'Atendimentos', 60, 150);
    },
    said: 'novo mapa pra Ana, entrega dia 30/10',
    expect: 'plan',
    check: delivery('Ana', (it) =>
      it.kind === 'Mapa astral' ? true : `kind ${it.kind ?? 'none'}`,
    ),
  },
  {
    id: 'goal-amount-unsaid',
    why: 'new_goal: an amount nobody said',
    said: 'cria uma meta de faturamento',
    expect: 'ask',
  },
  {
    id: 'goal-said',
    why: 'new_goal: money by a day, as said',
    said: 'quero faturar 4 mil até o fim do mês que vem',
    expect: 'plan',
    check: (s) =>
      s.goals.some(
        (it) =>
          it.kind === 'money' &&
          it.target === 4000 &&
          it.deadline === '2026-11-30',
      )
        ? true
        : `goals: ${JSON.stringify(s.goals)}`,
  },
  {
    id: 'kind-new',
    why: 'new_kind: a kind with its shelf, length and price',
    said: 'adiciona no catálogo o tipo leitura de tarot, em atendimentos, 1 hora, 150 reais',
    expect: 'plan',
    check: (s) =>
      s.kinds.some((it) => /tarot/i.test(it))
        ? true
        : `kinds: ${s.kinds.join(', ') || 'none'}`,
  },
  {
    id: 'remove-cascade',
    why: 'remove_artifact: its six backlog tasks go with it, so it asks first',
    setup: async (w) => {
      const mudanca = await w.artifact('Mudança');
      for (const title of [
        'Caixas',
        'Frete',
        'Faxina',
        'Chaves',
        'Internet',
        'Endereço',
      ]) {
        await w.task(title, 30, { backlog: true, artifact: mudanca });
      }
    },
    said: 'apaga a entrega da mudança',
    expect: 'ask',
  },
  {
    id: 'delivery-reorder',
    why: 'move_artifact: the queue of deliveries, by name',
    setup: async (w) => {
      await w.artifact('Tese', '2026-11-30');
      await w.artifact('Curso de tarot', OCTOBER_30);
    },
    said: 'passa o curso de tarot na frente da tese',
    expect: 'plan',
    check: (s) => {
      const open = s.artifacts.filter((it) => !it.done).map((it) => it.title);
      return open[0] === 'Curso de tarot' ? true : `queue: ${open.join(' → ')}`;
    },
  },
];
