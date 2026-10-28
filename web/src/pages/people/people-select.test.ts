import { describe, expect, it } from 'vitest';
import { sharedSummary } from './people-select';

describe('sharedSummary', () => {
  it('shows nothing when nothing is shared', () => {
    expect(sharedSummary([])).toEqual({ shown: null, more: 0 });
  });

  it('lists up to two communities in full', () => {
    expect(sharedSummary(['Elixir', 'Phoenix'])).toEqual({ shown: 'Elixir, Phoenix', more: 0 });
  });

  it('counts the rest after two', () => {
    expect(sharedSummary(['Elixir', 'Phoenix', 'Slow Readers', 'Lagos Run Club'])).toEqual({
      shown: 'Elixir, Phoenix',
      more: 2,
    });
  });
});
