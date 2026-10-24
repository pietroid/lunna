import { Day } from '../events/timeline.service';
import { Timeline } from '../events/entities/event.entity';
import {
  Artifact,
  CatalogCategory,
  CatalogType,
  Goal,
  GoalView,
} from '../artifacts/artifact.types';
import { measureGoals } from '../artifacts/artifacts.service';
import { Task } from '../tasks/task.types';
import {
  addMinutes,
  BLOCK_GAP_MINUTES,
  formatMinuteOfDay,
  Interval,
  roundUpToFiveMinutes,
} from '../time/work-hours';
import {
  addDaysIn,
  atMinuteIn,
  formatTimeIn,
  instantOf,
  isoDayIn,
  Zone,
} from '../time/zone';

/** How far ahead the agent can see and plan, counting today. */
export const HORIZON_DAYS = 14;

/** How many days the date table names. */
const TABLE_DAYS = 8;

/** A free stretch shorter than this is not worth naming. */
const MIN_FREE_MINUTES = 15;

/** How many backlog tasks the model is shown. */
const MAX_BACKLOG = 30;

/** How many delivered deliveries the model is shown, the latest first. */
const MAX_DELIVERED = 5;

/** One card, as the model refers to it. */
export interface BoardCard {
  /** `t3`, `e1`, `b2`: what the model writes instead of an id. */
  ref: string;
  id: string;
  kind: 'task' | 'event';
  title: string;
  /** Absent in the backlog. */
  start?: Date;
  end?: Date;
  /** "2026-10-16", the day it starts on. Absent in the backlog. */
  day?: string;
  minutes: number;
  /** A task that keeps an hour of its own. */
  anchored: boolean;
  /** Begun, or an event whose hour has come: nothing moves it. */
  started: boolean;
  /** An event somebody else booked. */
  foreign: boolean;
  routine: boolean;
  backlog: boolean;
  /** Ticked off: reached only through an artifact, never on the day. */
  done: boolean;
  /** The artifact it belongs to, when it belongs to one. */
  artifactId?: string;
  notes: string;
}

/** An open artifact, as the board's index names it. */
export interface BoardArtifact {
  /** `p2`. */
  ref: string;
  artifact: Artifact;
  /** Its tasks, done ones included, in their order. */
  tasks: Task[];
}

/** A kind of the catalogue, as the board names it. */
export interface BoardKind {
  /** `k1`. */
  ref: string;
  type: CatalogType;
  /** The name of its shelf. */
  shelf: string;
}

/** A goal, as the board names it, measured now. */
export interface BoardGoal {
  /** `g1`. */
  ref: string;
  goal: Goal;
  view: GoalView;
}

/** What a board is built with besides the day. */
export interface BoardOptions {
  /**
   * The refs handed out earlier in the conversation, by id. The board keeps
   * them and writes the new ones in, so a ref means the same card from turn
   * to turn.
   */
  refs?: Map<string, string>;
  artifacts?: Artifact[];
  /** Every task of an artifact, done ones included. */
  artifactTasks?: Task[];
  categories?: CatalogCategory[];
  types?: CatalogType[];
  goals?: Goal[];
}

const WEEKDAYS_PT = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
const WEEKDAYS_EN = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/** What a person may call a day, to the weekday it names (0 is Sunday). */
const WEEKDAY_WORDS: Record<string, number> = {
  domingo: 0,
  dom: 0,
  sunday: 0,
  segunda: 1,
  'segunda-feira': 1,
  seg: 1,
  monday: 1,
  terca: 2,
  'terca-feira': 2,
  ter: 2,
  tuesday: 2,
  quarta: 3,
  'quarta-feira': 3,
  qua: 3,
  wednesday: 3,
  quinta: 4,
  'quinta-feira': 4,
  qui: 4,
  thursday: 4,
  sexta: 5,
  'sexta-feira': 5,
  sex: 5,
  friday: 5,
  sabado: 6,
  sab: 6,
  saturday: 6,
};

/**
 * The day as the agent sees it: every card in reach under a short ref, the
 * dates around today, and the free room. Built once per turn from one read,
 * so the refs the model is shown are the refs it is held to.
 */
export class Board {
  readonly cards: BoardCard[];
  readonly today: string;
  /** Every artifact, oldest first; the index names the open ones. */
  readonly artifacts: BoardArtifact[];
  /** The catalogue's kinds, shelf by shelf. */
  readonly kinds: BoardKind[];
  readonly goals: BoardGoal[];
  private readonly _byRef: Map<string, BoardCard>;
  private readonly _refs: Map<string, string>;
  /** The rows the cards were read from, for what the timeline leaves out. */
  private readonly _rows = new Map<
    string,
    { notes: string; artifactId?: string }
  >();
  private readonly _titles: Map<string, string>;

  constructor(
    readonly day: Day,
    view: Timeline,
    options: BoardOptions = {},
  ) {
    const { now, zone } = day;
    this.today = isoDayIn(now, zone);
    this._refs = options.refs ?? new Map<string, string>();
    for (const row of [...day.tasks, ...day.backlog, ...day.events]) {
      this._rows.set(row.id, {
        notes: row.notes,
        artifactId: 'artifactId' in row ? row.artifactId : undefined,
      });
    }
    this._titles = new Map(
      (options.artifacts ?? []).map((it) => [it.id, it.title]),
    );

    const seen = new Set<string>();
    const tasks = [
      ...view.tasks,
      ...view.cards.filter((it) => it.kind === 'task'),
    ]
      .filter((card) => !seen.has(card.id) && seen.add(card.id))
      .sort((a, b) => Date.parse(a.startTime) - Date.parse(b.startTime));
    const events = view.cards.filter((card) => card.kind === 'event');

    const timed = (
      card: Timeline['cards'][number],
      ref: string,
    ): BoardCard => ({
      ...this._extra(card.id),
      ref,
      id: card.id,
      kind: card.kind,
      title: card.title,
      start: new Date(card.startTime),
      end: new Date(card.endTime),
      day: card.day,
      minutes: card.workMinutes,
      anchored: card.notBefore !== undefined,
      started:
        card.started ||
        (card.kind === 'event' && Date.parse(card.startTime) <= now.getTime()),
      foreign: !card.managed,
      routine: card.routine !== undefined,
      backlog: false,
    });

    this.cards = [
      ...tasks.map((card) => timed(card, this._assign(card.id, 't'))),
      ...events.map((card) => timed(card, this._assign(card.id, 'e'))),
      ...view.backlog.slice(0, MAX_BACKLOG).map((card): BoardCard => ({
        ...this._extra(card.id),
        ref: this._assign(card.id, 'b'),
        id: card.id,
        kind: 'task',
        title: card.title,
        minutes: card.durationMinutes,
        anchored: false,
        started: false,
        foreign: false,
        routine: card.routine !== undefined,
        backlog: true,
      })),
    ];
    this._byRef = new Map(this.cards.map((card) => [card.ref, card]));

    const tasks_ = options.artifactTasks ?? [];
    this.artifacts = (options.artifacts ?? []).map((artifact) => ({
      ref: this._assign(artifact.id, 'p'),
      artifact,
      tasks: tasks_.filter((task) => task.artifactId === artifact.id),
    }));

    const shelves = options.categories ?? [];
    this.kinds = shelves.flatMap((shelf) =>
      (options.types ?? [])
        .filter((type) => type.categoryId === shelf.id)
        .map((type) => ({
          ref: this._assign(type.id, 'k'),
          type,
          shelf: shelf.name,
        })),
    );
    const measured = measureGoals(
      options.goals ?? [],
      options.artifacts ?? [],
      this.today,
      zone,
    );
    this.goals = measured.map((view) => ({
      ref: this._assign(view.id, 'g'),
      goal: (options.goals ?? []).find((it) => it.id === view.id)!,
      view,
    }));
  }

  get zone(): Zone {
    return this.day.zone;
  }

  ref(ref: string): BoardCard | undefined {
    return this._byRef.get(ref.trim().toLowerCase());
  }

  byId(id: string): BoardCard | undefined {
    return this.cards.find((card) => card.id === id);
  }

  /** The open artifact under [ref] (`p2`). */
  artifact(ref: string): BoardArtifact | undefined {
    const said = ref.trim().toLowerCase();
    return this.artifacts.find((it) => it.ref === said);
  }

  artifactById(id: string): BoardArtifact | undefined {
    return this.artifacts.find((it) => it.artifact.id === id);
  }

  /** The kind under [ref] (`k1`). */
  kind(ref: string): BoardKind | undefined {
    const said = ref.trim().toLowerCase();
    return this.kinds.find((it) => it.ref === said);
  }

  /** The goal under [ref] (`g1`). */
  goal(ref: string): BoardGoal | undefined {
    const said = ref.trim().toLowerCase();
    return this.goals.find((it) => it.ref === said);
  }

  /** The title a ref stands for: a card's, an artifact's or a kind's. */
  title(ref: string): string | undefined {
    return (
      this.ref(ref)?.title ??
      this.artifact(ref)?.artifact.title ??
      this.kind(ref)?.type.name ??
      (this.goal(ref) === undefined ? undefined : 'a meta')
    );
  }

  /**
   * [task] as a card the model can name, wherever it is: on the board it is
   * that card; off it (past the backlog's first 30, done) it gets the next
   * ref of its kind (`b31`, `d1`), kept for the conversation like every
   * other. A task the board cannot see is still made the same way, since
   * the sandbox is seeded with every row of the day.
   */
  reach(task: Task): BoardCard {
    const known = this.byId(task.id);
    if (known !== undefined) return known;

    const placed = this.day.placed.get(task.id);
    const done = task.doneAt !== undefined;
    const card: BoardCard = {
      ref: this._assign(task.id, done ? 'd' : task.backlog ? 'b' : 't'),
      id: task.id,
      kind: 'task',
      title: task.title,
      ...(placed === undefined || done
        ? {}
        : {
            start: placed.start,
            end: placed.end,
            day: isoDayIn(placed.start, this.zone),
          }),
      minutes: task.minutes,
      anchored: task.notBefore !== undefined,
      started: false,
      foreign: false,
      routine: task.routineId !== undefined,
      backlog: task.backlog && !done,
      done,
      artifactId: task.artifactId,
      notes: task.notes,
    };
    this.cards.push(card);
    this._byRef.set(card.ref, card);

    return card;
  }

  /** The name of the artifact [card] belongs to, when it belongs to one. */
  artifactOf(card: BoardCard): string | undefined {
    return card.artifactId === undefined
      ? undefined
      : this._titles.get(card.artifactId);
  }

  /** The ref [id] already has in the conversation, or the next of [kind]. */
  private _assign(id: string, kind: string): string {
    const known = this._refs.get(id);
    if (known !== undefined) return known;

    let next = 1;
    for (const ref of this._refs.values()) {
      if (ref.startsWith(kind)) {
        next = Math.max(next, Number(ref.slice(kind.length)) + 1);
      }
    }
    const ref = `${kind}${next}`;
    this._refs.set(id, ref);

    return ref;
  }

  private _extra(id: string): Pick<BoardCard, 'done' | 'artifactId' | 'notes'> {
    const row = this._rows.get(id);
    return {
      done: false,
      ...(row?.artifactId === undefined ? {} : { artifactId: row.artifactId }),
      notes: row?.notes ?? '',
    };
  }

  /** Whether the working day of [day] ("YYYY-MM-DD") has ended. */
  over(day: string): boolean {
    return this.window(day).end <= this.day.now;
  }

  /** The working day of [day], from its opening to its close. */
  window(day: string): Interval {
    const noon = noonOf(day, this.zone);
    return {
      start: atMinuteIn(noon, this.day.workDay.start, this.zone),
      end: atMinuteIn(noon, this.day.workDay.end, this.zone),
    };
  }

  /**
   * The day a person named: "hoje", "amanhã", a weekday, or YYYY-MM-DD.
   * Undefined for anything else, or a day out of reach.
   */
  dayOf(words: string): string | undefined {
    const said = normalize(words);
    const offset = (n: number) =>
      isoDayIn(addDaysIn(this.day.now, n, this.zone), this.zone);

    let day: string | undefined;
    if (/^\d{4}-\d{2}-\d{2}$/.test(said)) day = said;
    else if (said === 'hoje' || said === 'today') day = this.today;
    else if (said === 'amanha' || said === 'tomorrow') day = offset(1);
    else if (said === 'depois de amanha') day = offset(2);
    else if (said in WEEKDAY_WORDS) {
      // The next one from today, today included while it has room left.
      const want = WEEKDAY_WORDS[said];
      for (let n = 0; n < 8; n++) {
        const candidate = offset(n);
        if (weekdayOf(candidate) !== want) continue;
        if (n === 0 && this.over(candidate)) continue;
        day = candidate;
        break;
      }
    }

    if (day === undefined) return undefined;
    const ahead = daysBetween(this.today, day);
    return ahead < 0 || ahead >= HORIZON_DAYS ? undefined : day;
  }

  /** "hoje", "amanhã", or "sáb 17/10", for the person to read. */
  dayLabel(day: string): string {
    const ahead = daysBetween(this.today, day);
    if (ahead === 0) return 'hoje';
    if (ahead === 1) return 'amanhã';
    return `${WEEKDAYS_PT[weekdayOf(day)]} ${day.slice(8, 10)}/${day.slice(5, 7)}`;
  }

  /** "hoje 16:00", "sáb 17/10 09:00": an hour, for the person to read. */
  when(at: Date): string {
    return `${this.dayLabel(isoDayIn(at, this.zone))} ${formatTimeIn(at, this.zone)}`;
  }

  /** "Dentista · bloco fixo · hoje 16:00": a card, for the person to read. */
  describe(card: BoardCard): string {
    const what = card.kind === 'event' ? 'bloco fixo' : 'tarefa';
    const where =
      card.start === undefined ? 'Para depois' : this.when(card.start);
    return `${card.title} · ${what} · ${where}`;
  }

  /** The free stretches of [day]'s working hours from now on. */
  free(day: string): Interval[] {
    const window = this.window(day);
    let cursor = roundUpToFiveMinutes(
      new Date(Math.max(window.start.getTime(), this.day.now.getTime())),
    );
    const busy = this.cards
      .filter((card) => card.start !== undefined && card.end! > cursor)
      .filter((card) => card.start! < window.end)
      .sort((a, b) => a.start!.getTime() - b.start!.getTime());

    const free: Interval[] = [];
    const room = (end: Date) => {
      if (end.getTime() - cursor.getTime() >= MIN_FREE_MINUTES * 60_000) {
        free.push({ start: cursor, end });
      }
    };
    for (const card of busy) {
      room(addMinutes(card.start!, -BLOCK_GAP_MINUTES));
      const next = addMinutes(card.end!, BLOCK_GAP_MINUTES);
      if (next > cursor) cursor = next;
    }
    room(window.end);

    return free;
  }

  /**
   * What the model reads before the request: the clock, the date table, the
   * cards of the days that matter, the backlog and the free room. Days and
   * hours are worked out here, so the model never does that arithmetic.
   */
  context(focusDay: string | undefined, said: string): string {
    const { now, zone, workDay } = this.day;
    const lines: string[] = [];
    const hours = `${formatMinuteOfDay(workDay.start)}–${formatMinuteOfDay(workDay.end)}`;

    lines.push(
      `Now: ${WEEKDAYS_EN[weekdayOf(this.today)]} ${this.today} ${formatTimeIn(now, zone)} (${zone}). Working day: ${hours}.`,
      '',
      'Dates (use these, never compute dates yourself):',
    );
    for (let n = 0; n < TABLE_DAYS; n++) {
      const day = isoDayIn(addDaysIn(now, n, zone), zone);
      const name =
        n === 0 ? 'hoje' : n === 1 ? 'amanhã' : WEEKDAYS_PT[weekdayOf(day)];
      let note = '';
      if (n === 0) {
        const left = this.window(day).end.getTime() - now.getTime();
        note = this.over(day)
          ? ' — working day OVER: nothing more fits today'
          : ` — ${formatSpan(Math.min(left, this.window(day).end.getTime() - this.window(day).start.getTime()))} of working day left`;
      }
      lines.push(`- ${name} = ${WEEKDAYS_EN[weekdayOf(day)]} ${day}${note}`);
    }

    const shown = new Set([
      this.today,
      isoDayIn(addDaysIn(now, 1, zone), zone),
    ]);
    if (focusDay !== undefined && /^\d{4}-\d{2}-\d{2}$/.test(focusDay)) {
      shown.add(focusDay);
      lines.push('', `The screen is showing ${focusDay}.`);
    }

    const named = this.cards.filter(
      (card) =>
        card.day !== undefined &&
        !shown.has(card.day) &&
        mentions(said, card.title),
    );
    lines.push('', 'Cards (ref · title · kind · when):');
    for (const day of [...shown].sort()) {
      const cards = this.cards.filter((card) => card.day === day);
      lines.push(
        `${this.dayLabel(day)} (${day})${this.over(day) ? ' — over' : ''}:`,
        ...(cards.length === 0
          ? ['  (nothing)']
          : cards.map((card) => `  ${this.line(card)}`)),
      );
    }
    if (named.length > 0) {
      lines.push(
        'Other days, named in the request:',
        ...named.map((card) => `  ${this.line(card)}`),
      );
    }
    lines.push(
      'Other days are not shown: read_timeline reads them.',
      '',
      'Backlog ("Para depois", no hour):',
      ...(this.cards.some((card) => card.backlog)
        ? this.cards
            .filter((card) => card.backlog)
            .map((card) => `  ${this.line(card)}`)
        : ['  (empty)']),
      '',
      'Artifacts (read_cards with an artifact ref reads its notes and every task):',
      ...(this.artifacts.every((it) => it.artifact.doneAt !== undefined)
        ? ['  (none)']
        : this.artifacts
            .filter((it) => it.artifact.doneAt === undefined)
            .map((it) => `  ${this.artifactLine(it)}`)),
    );
    const delivered = this.artifacts
      .filter((it) => it.artifact.doneAt !== undefined)
      .sort((a, b) => b.artifact.doneAt!.localeCompare(a.artifact.doneAt!))
      .slice(0, MAX_DELIVERED);
    if (delivered.length > 0) {
      lines.push(
        'Delivered lately:',
        ...delivered.map((it) => `  ${this.artifactLine(it)}`),
      );
    }
    if (this.kinds.length > 0) {
      lines.push(
        'Catalogue (kinds):',
        ...this.kinds.map((it) => `  ${this.kindLine(it)}`),
      );
    }
    if (this.goals.length > 0) {
      lines.push('Goals:', ...this.goals.map((it) => `  ${this.goalLine(it)}`));
    }
    lines.push('', 'Free room:');
    for (const day of [...shown].sort()) {
      const free = this.free(day);
      lines.push(
        `  ${this.dayLabel(day)}: ${free.length === 0 ? 'none' : free.map((it) => this.span(it)).join(', ')}`,
      );
    }

    return lines.join('\n');
  }

  /** The cards of [days] days from [from], for read_timeline. */
  read(from: string, days: number): string {
    const lines: string[] = [];
    for (let n = 0; n < days; n++) {
      const day = isoDayIn(
        addDaysIn(noonOf(from, this.zone), n, this.zone),
        this.zone,
      );
      if (daysBetween(this.today, day) >= HORIZON_DAYS) break;
      const cards = this.cards.filter((card) => card.day === day);
      const free = this.free(day);
      lines.push(
        `${this.dayLabel(day)} (${day})${this.over(day) ? ' — over' : ''}:`,
        ...(cards.length === 0
          ? ['  (nothing)']
          : cards.map((card) => `  ${this.line(card)}`)),
        `  free: ${free.length === 0 ? 'none' : free.map((it) => this.span(it)).join(', ')}`,
      );
    }
    return lines.join('\n');
  }

  /** "t2 · Academia · task with an hour · 16:00–17:00". */
  line(card: BoardCard): string {
    const kind = card.done
      ? 'done task'
      : card.backlog
        ? 'backlog task'
        : card.kind === 'event'
          ? card.foreign
            ? 'event (not Lunna’s, never moved)'
            : 'fixed event'
          : card.started
            ? 'task, running'
            : card.anchored
              ? 'task with its own hour'
              : 'task in the queue';
    const extra = [
      card.routine ? 'routine' : undefined,
      card.started && card.kind === 'event' ? 'started' : undefined,
    ]
      .filter((it) => it !== undefined)
      .join(', ');
    const when =
      card.start === undefined
        ? formatSpan(card.minutes * 60_000)
        : `${this.dayLabel(card.day!)} ${formatTimeIn(card.start, this.zone)}–${formatTimeIn(card.end!, this.zone)}`;
    const artifact = this.artifactOf(card);

    return `${card.ref} · ${card.title} · ${kind}${extra === '' ? '' : ` (${extra})`} · ${when}${artifact === undefined ? '' : ` · artifact ${artifact}`}`;
  }

  /**
   * "p2 · Tese · Mapa astral · due 30/11 · 6 open tasks, 2 with an hour ·
   * 12h of 20h · R$ 1.500", or "· delivered 12/10" for one delivered.
   */
  artifactLine(it: BoardArtifact): string {
    const { artifact } = it;
    const open = it.tasks.filter((task) => task.doneAt === undefined);
    const timed = open.filter((task) => !task.backlog).length;
    const due = artifact.deadline;
    const kind = this.kinds.find((k) => k.type.id === artifact.typeId);
    const done = it.tasks
      .filter((task) => task.doneAt !== undefined)
      .reduce((sum, task) => sum + task.minutes, 0);
    return [
      it.ref,
      artifact.title,
      ...(kind === undefined ? [] : [kind.type.name]),
      ...(due === undefined ? [] : [`due ${ddmm(due)}`]),
      artifact.doneAt === undefined
        ? `${open.length} open tasks, ${timed} with an hour`
        : `delivered ${ddmm(isoDayIn(new Date(artifact.doneAt), this.zone))}`,
      ...(artifact.minutes === undefined || artifact.doneAt !== undefined
        ? []
        : [
            `${formatSpan(done * 60_000)} of ${formatSpan(artifact.minutes * 60_000)}`,
          ]),
      ...(artifact.value === undefined ? [] : [reais(artifact.value)]),
    ].join(' · ');
  }

  /** "k1 · Mapa astral · Atendimentos · 1h30 · R$ 250". */
  kindLine(it: BoardKind): string {
    return [
      it.ref,
      it.type.name,
      it.shelf,
      formatSpan(it.type.minutes * 60_000),
      ...(it.type.price === undefined ? [] : [reais(it.type.price)]),
    ].join(' · ');
  }

  /**
   * "g1 · money · R$ 4.000 per month · delivered R$ 1.250, queued R$ 2.000",
   * or "g2 · count of Mapa astral · 3 per week · delivered 1, queued 2".
   */
  goalLine(it: BoardGoal): string {
    const { view } = it;
    const money = view.kind === 'money';
    const amount = (n: number) => (money ? reais(n) : String(n));
    const kind = this.kinds.find((k) => k.type.id === view.typeId);
    return [
      it.ref,
      money ? 'money' : `count of ${kind?.type.name ?? 'a kind'}`,
      `${amount(view.target)} per ${view.period}${view.start > this.today ? ` from ${ddmm(view.start)}` : ''}`,
      `delivered ${amount(view.done)}, queued ${amount(view.queued)}`,
    ].join(' · ');
  }

  /** "18:00–19:30 (1h30)". */
  span(interval: Interval): string {
    return `${formatTimeIn(interval.start, this.zone)}–${formatTimeIn(interval.end, this.zone)} (${formatSpan(interval.end.getTime() - interval.start.getTime())})`;
  }

  /** The cards whose titles are close enough to [title] to be the same. */
  alike(title: string): BoardCard[] {
    return this.cards.filter((card) => sameTitle(card.title, title));
  }
}

/** Lowercase, no accents, single spaces: how titles are compared. */
export function normalize(text: string): string {
  return text
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Whether two titles name the same thing: equal once normalized, one
 * contained in the other as whole words, or close by trigrams (as pg_trgm
 * measures it).
 */
export function sameTitle(a: string, b: string): boolean {
  const x = normalize(a);
  const y = normalize(b);
  if (x === '' || y === '') return false;
  if (x === y) return true;

  const words = (s: string) => ` ${s.replace(/[^\p{L}\p{N}]+/gu, ' ').trim()} `;
  const [short, long] = x.length <= y.length ? [x, y] : [y, x];
  if (short.length >= 4 && words(long).includes(words(short))) return true;

  return similarity(x, y) >= 0.6;
}

function similarity(a: string, b: string): number {
  const grams = (s: string) => {
    const padded = `  ${s} `;
    const out = new Set<string>();
    for (let i = 0; i + 3 <= padded.length; i++)
      out.add(padded.slice(i, i + 3));
    return out;
  };
  const x = grams(a);
  const y = grams(b);
  let common = 0;
  for (const gram of x) if (y.has(gram)) common++;
  return common / (x.size + y.size - common);
}

/** Whether [said] names [title]: a word of four letters or more in common. */
function mentions(said: string, title: string): boolean {
  const words = (s: string) =>
    normalize(s)
      .split(/[^\p{L}\p{N}]+/u)
      .filter((w) => w.length >= 4);
  const asked = new Set(words(said));
  return words(title).some((word) => asked.has(word));
}

/** Noon of "2026-10-16" in [zone], safely inside that day. */
export function noonOf(day: string, zone: Zone): Date {
  const [year, month, date] = day.split('-').map(Number);
  return instantOf(
    { year, month, day: date, hour: 12, minute: 0, second: 0 },
    zone,
  );
}

/** Whole days from [a] to [b], both "YYYY-MM-DD". */
export function daysBetween(a: string, b: string): number {
  return Math.round(
    (Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86_400_000,
  );
}

/** The weekday of "2026-10-16", 0 for Sunday. */
function weekdayOf(day: string): number {
  return new Date(`${day}T12:00:00Z`).getUTCDay();
}

/** "30/11" of "2026-11-30". */
function ddmm(day: string): string {
  return `${day.slice(8, 10)}/${day.slice(5, 7)}`;
}

/** "R$ 1.500". */
function reais(value: number): string {
  return `R$ ${String(value).replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;
}

/** "3h10", "45 min". */
export function formatSpan(ms: number): string {
  const minutes = Math.max(0, Math.round(ms / 60_000));
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m} min`;
  return m === 0 ? `${h}h` : `${h}h${String(m).padStart(2, '0')}`;
}
