// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { emptyState } from '@/data/empty-state';
import { hydrationScript } from './hydration';

describe('hydrationScript', () => {
  it('keeps text in the data from closing the script', () => {
    const state = emptyState();

    state.instance.name = '</script><script>alert(1)</script>';

    const script = hydrationScript({
      state,
      loaded: ['post:p1'],
      origin: '',
      zone: 'UTC',
      signedIn: false,
    });

    expect(script.match(/<\/script>/g)).toHaveLength(1);
    expect(script).toContain('\\u003c/script>');
  });
});
