import { BadRequestException } from '@nestjs/common';
import { requireWorkDay, workDayDtoOf } from './work-day';

describe('requireWorkDay', () => {
  it('reads both edges as minutes after midnight', () => {
    expect(requireWorkDay({ start: '06:30', end: '23:00' })).toEqual({
      start: 390,
      end: 1380,
    });
  });

  it('lets the day run to midnight', () => {
    expect(requireWorkDay({ start: '08:00', end: '24:00' }).end).toBe(1440);
  });

  it.each([
    [undefined],
    [{ start: '7:00', end: '22:00' }],
    [{ start: '07:00', end: '22:60' }],
    [{ start: '07:00', end: '24:30' }],
    [{ start: '07:00' }],
    [{ start: '22:00', end: '07:00' }],
    [{ start: '09:00', end: '09:30' }],
  ])('refuses %j', (dto) => {
    expect(() => requireWorkDay(dto)).toThrow(BadRequestException);
  });

  it('writes a day back the way it was read', () => {
    expect(workDayDtoOf({ start: 420, end: 1440 })).toEqual({
      start: '07:00',
      end: '24:00',
    });
  });
});
