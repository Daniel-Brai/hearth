import { afterEach, describe, expect, it, vi } from 'vitest';
import { createSeedState } from '@/mocks/seed';
import { createRuntime } from './runtime';

const serverState = () => {
  const state = createSeedState();
  state.settings.tourDone = false;
  return state;
};

afterEach(() => {
  vi.unstubAllEnvs();
  localStorage.clear();
});

describe('createRuntime', () => {
  it('shows the tour again when this browser never finished it', async () => {
    vi.stubEnv('VITE_HEARTH_DATA', 'mock');

    const { store } = await createRuntime(serverState());

    expect(store.get().settings.tourDone).toBe(false);
  });

  it('keeps the tour finished in the in-memory data when this browser remembers it', async () => {
    vi.stubEnv('VITE_HEARTH_DATA', 'mock');
    localStorage.setItem('hearth-tour-done', 'true');

    const { store } = await createRuntime(serverState());

    expect(store.get().settings.tourDone).toBe(true);
  });

  it('takes the tour only from the server when talking to the API', async () => {
    vi.stubEnv('VITE_HEARTH_DATA', '');
    localStorage.setItem('hearth-tour-done', 'true');

    const { store } = await createRuntime(serverState());

    expect(store.get().settings.tourDone).toBe(false);
  });
});
