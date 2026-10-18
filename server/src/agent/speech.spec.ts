import { leaksRef, speakable } from './speech';

const board = {
  title: (ref: string) =>
    ({ e2: 'Reunião', t1: 'Academia', p1: 'Tese' })[ref.toLowerCase()],
};

describe('speakable', () => {
  it('names a card by its title, never its ref', () => {
    expect(speakable('Passei a e2 para amanhã.', board)).toEqual({
      text: 'Passei a Reunião para amanhã.',
      leaks: 1,
    });
    expect(speakable('Como está o P1?', board).text).toBe('Como está o Tese?');
  });

  it('leaves alone what only looks like a ref', () => {
    // A ref the board does not know, and one inside a word.
    expect(speakable('O t9 e o art1go.', board)).toEqual({
      text: 'O t9 e o art1go.',
      leaks: 0,
    });
  });

  it('says Depois eu priorizo for the backlog', () => {
    expect(speakable('Ficou no backlog.', board)).toEqual({
      text: 'Ficou no Depois eu priorizo.',
      leaks: 1,
    });
    expect(speakable('Backlog vazio.', board).text).toBe(
      'Depois eu priorizo vazio.',
    );
  });

  it('finds the refs left over', () => {
    expect(leaksRef('a t2 desce')).toBe(true);
    expect(leaksRef('a Academia desce')).toBe(false);
  });
});
