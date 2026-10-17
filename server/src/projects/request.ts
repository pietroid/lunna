import { BadRequestException } from '@nestjs/common';
import {
  CreateProjectDto,
  CreateProjectTaskDto,
  EditProjectDto,
} from './dto/project.dto';
import { NewProject, ProjectEdit } from './project.types';

/**
 * Reading what the app sent, for every route about projects.
 *
 * As for the day: a request that cannot be trusted is a 400 with a reason,
 * never a guess.
 */

/** A new project. */
export function requireProject(dto: CreateProjectDto): NewProject {
  const deadline = deadlineOf(dto.deadline);
  return {
    title: requireTitle(dto.title),
    ...(deadline === null || deadline === undefined ? {} : { deadline }),
  };
}

/** A change to a project. */
export function requireProjectEdit(dto: EditProjectDto): ProjectEdit {
  const edit: ProjectEdit = {};
  if (dto.title !== undefined) edit.title = requireTitle(dto.title);
  if (dto.notes !== undefined) {
    if (typeof dto.notes !== 'string') {
      throw new BadRequestException('notes must be a string');
    }
    edit.notes = dto.notes;
  }
  const deadline = deadlineOf(dto.deadline);
  if (deadline !== undefined) edit.deadline = deadline;
  if (dto.done !== undefined) {
    if (typeof dto.done !== 'boolean') {
      throw new BadRequestException('done must be a boolean');
    }
    edit.done = dto.done;
  }

  return edit;
}

/** A task written down in a project. */
export function requireProjectTask(dto: CreateProjectTaskDto): {
  title: string;
  minutes: number;
} {
  const minutes = dto.minutes;
  if (
    typeof minutes !== 'number' ||
    !Number.isFinite(minutes) ||
    minutes <= 0
  ) {
    throw new BadRequestException('minutes must be positive');
  }

  return { title: requireTitle(dto.title), minutes: Math.round(minutes) };
}

function requireTitle(raw: unknown): string {
  const title = typeof raw === 'string' ? raw.trim() : '';
  if (title === '') throw new BadRequestException('title is required');

  return title;
}

/** A `YYYY-MM-DD` that is a real day, null, or undefined when not given. */
function deadlineOf(raw: unknown): string | null | undefined {
  if (raw === undefined || raw === null) return raw;
  if (typeof raw !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    throw new BadRequestException('deadline must be a YYYY-MM-DD day');
  }
  const [year, month, day] = raw.split('-').map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (parsed.getUTCMonth() !== month - 1 || parsed.getUTCDate() !== day) {
    throw new BadRequestException('deadline must be a YYYY-MM-DD day');
  }

  return raw;
}
