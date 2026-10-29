import { beforeEach, describe, expect, it } from 'vitest';
import { rememberSignedIn } from './request-context';

describe('rememberSignedIn', () => {
  beforeEach(() => rememberSignedIn(false));

  it('clears the hint', () => {
    rememberSignedIn(true);
    rememberSignedIn(false);

    expect(document.cookie).not.toContain('hearth-signed-in');
  });

  it('saves a flag and never a token', () => {
    rememberSignedIn(true);

    expect(document.cookie).toBe('hearth-signed-in=1');
  });
});
