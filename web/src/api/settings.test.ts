import { describe, expect, it } from 'vitest';
import { emptyState } from '@/data/empty-state';
import { toSettingsBody } from './settings';

describe('toSettingsBody/2', () => {
  const current = emptyState().settings;

  it('sends only what changed', () => {
    expect(toSettingsBody({ haptics: false }, current)).toEqual({ haptics: false });
  });

  it('turns haptics on for everyone until they turn them off', () => {
    expect(current.haptics).toBe(true);
  });
});
