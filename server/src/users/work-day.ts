import { BadRequestException } from '@nestjs/common';
import {
  formatMinuteOfDay,
  MIN_WORK_DAY_MINUTES,
  parseMinuteOfDay,
  WorkDay,
} from '../time/work-hours';

/** A working day as the wire writes it: "07:00" to "22:00". */
export class WorkDayDto {
  start?: string;
  end?: string;
}

/** What the menu may change about the signed-in person. */
export class EditMeDto {
  workDay?: WorkDayDto;
}

/**
 * Reads the working day the menu sent, refusing one the layout could not
 * use: an edge that is not a time, or a day shorter than an hour.
 *
 * The end may be "24:00", a day that runs to midnight. It may not wrap past
 * it: a day that ends the next morning is a night, and the queue has no
 * way to tell which date it belongs to.
 */
export function requireWorkDay(dto: WorkDayDto | undefined): WorkDay {
  const start = parseMinuteOfDay(dto?.start);
  const end = parseMinuteOfDay(dto?.end);

  if (start === undefined || end === undefined) {
    throw new BadRequestException('workDay needs start and end as "HH:MM"');
  }
  if (end - start < MIN_WORK_DAY_MINUTES) {
    throw new BadRequestException(
      'O dia precisa terminar pelo menos uma hora depois de começar.',
    );
  }

  return { start, end };
}

/** [day] as the wire writes it. */
export function workDayDtoOf(day: WorkDay): Required<WorkDayDto> {
  return {
    start: formatMinuteOfDay(day.start),
    end: formatMinuteOfDay(day.end),
  };
}
