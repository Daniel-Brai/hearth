// @vitest-environment node
import { describe, expect, it } from 'vitest';
import type { CommunityEvent } from './types';
import { evDay, evRel, evWhen } from './events';

const event: CommunityEvent = {
  id: 'e1',
  c: 'elixir',
  title: 'Office hours',
  start: '2026-10-29T23:30:00.000Z',
  mins: 60,
  repeat: 'none',
  where: { type: 'voice', room: 'office-hours' },
  host: 'ada',
  interested: [],
  cancelled: false,
  desc: null,
};

const now = Date.parse('2026-10-29T12:00:00.000Z');

describe('event times', () => {
  it('write the same event in the zone they are given', () => {
    expect(evWhen(event, 'UTC')).toBe('Thu, Oct 29 · 11:30 PM to 12:30 AM');
    expect(evWhen(event, 'Africa/Lagos')).toBe('Fri, Oct 30 · 12:30 AM to 1:30 AM');
    expect(evDay(event, 'Africa/Lagos')).toEqual({ mon: 'Oct', day: 30, dow: 'Fri' });
  });

  it('count today and tomorrow by the calendar of that zone', () => {
    expect(evRel(event, 'UTC', now)).toBe('Today at 11:30 PM');
    expect(evRel(event, 'Africa/Lagos', now)).toBe('Tomorrow at 12:30 AM');
  });
});
