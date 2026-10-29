import { describe, expect, it } from 'vitest';
import { createSeedState } from '@/mocks/seed';
import { suggest } from './composer-text';

const state = createSeedState();

describe('suggest', () => {
  it('offers no @all without the permission', () => {
    const found = suggest(state, '@a', 2, { community: 'elixir', chat: true });

    expect(found?.items.some((s) => s.insert === '@all ')).toBeFalsy();
  });

  it('offers @all first to someone who can ping the room', () => {
    const found = suggest(state, '@a', 2, { community: 'elixir', chat: true, mentionAll: true });

    expect(found?.items[0]?.insert).toBe('@all ');
  });
});
