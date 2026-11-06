import { describe, expect, it } from 'vitest';

import { closesAtProblem, closingLabel, nextPicks, pollProblem, share, withVote } from './polls';
import type { Poll } from './types';

const poll = (changes: Partial<Poll> = {}): Poll => ({
  id: 'p1',
  multiple: false,
  closesAt: null,
  closedAt: null,
  voters: 2,
  options: [
    { id: 'a', label: 'Tea', votes: 1 },
    { id: 'b', label: 'Coffee', votes: 1 },
  ],
  mine: [],
  ...changes,
});

const now = new Date('2026-11-06T12:00:00Z');

describe('pollProblem', () => {
  it('refuses fewer than two choices', () => {
    expect(
      pollProblem({ question: 'Drink?', options: ['Tea'], multiple: false, closesAt: null }),
    ).toBe('Add at least two choices.');
  });

  it('refuses the same choice twice', () => {
    expect(
      pollProblem({ question: 'Drink?', options: ['Tea', 'tea'], multiple: false, closesAt: null }),
    ).toBe('Each choice needs to be different.');
  });

  it('takes a question with two choices', () => {
    expect(
      pollProblem({
        question: 'Drink?',
        options: ['Tea', 'Coffee'],
        multiple: false,
        closesAt: null,
      }),
    ).toBeNull();
  });
});

describe('closesAtProblem', () => {
  it('refuses a time already past', () => {
    expect(closesAtProblem(new Date('2026-11-06T11:00:00Z'), now)).toBe(
      'Pick a time at least a minute from now.',
    );
  });

  it('refuses more than a week ahead', () => {
    expect(closesAtProblem(new Date('2026-11-20T12:00:00Z'), now)).toBe(
      'A poll can stay open for up to 7 days.',
    );
  });
});

describe('nextPicks', () => {
  it('swaps the pick in a single choice poll', () => {
    expect(nextPicks(poll({ mine: ['a'] }), 'b')).toEqual(['b']);
  });

  it('takes a pick back when tapped again', () => {
    expect(nextPicks(poll({ mine: ['a'] }), 'a')).toEqual([]);
  });

  it('adds to the picks when several are allowed', () => {
    expect(nextPicks(poll({ multiple: true, mine: ['a'] }), 'b')).toEqual(['a', 'b']);
  });
});

describe('withVote', () => {
  it('moves a vote without counting the voter twice', () => {
    const moved = withVote(poll({ voters: 1, mine: ['a'] }), ['b']);

    expect(moved.voters).toBe(1);
    expect(moved.options.map((o) => o.votes)).toEqual([0, 2]);
  });

  it('counts a new voter', () => {
    expect(withVote(poll(), ['a']).voters).toBe(3);
  });
});

describe('share', () => {
  it('is a share of the people who voted', () => {
    expect(share(poll({ voters: 4 }), 1)).toBe(25);
  });
});

describe('closingLabel', () => {
  it('says closed once it has', () => {
    expect(closingLabel(poll({ closedAt: '2026-11-06T11:00:00Z' }), now)).toBe('Closed');
  });

  it('rounds the minutes left up', () => {
    expect(closingLabel(poll({ closesAt: '2026-11-06T12:04:30Z' }), now)).toBe('Closes in 5 min');
  });
});
