import { ApiGateway } from '@/api/api-gateway';
import type { HearthGateway } from '@/data/gateway';
import { emptyState } from '@/data/empty-state';
import { Store } from '@/data/store';
import type { AppState } from '@/domain/app-state';

type DataSource = 'mock' | 'api';

export type Runtime = {
  readonly store: Store;
  readonly gateway: HearthGateway;
  readonly source: DataSource;
};

// Vite replaces VITE_HEARTH_DATA at build time so API builds never download the mocks
export async function createRuntime(initial: AppState | null): Promise<Runtime> {
  if (import.meta.env.VITE_HEARTH_DATA === 'mock') {
    const [{ MockGateway }, { createSeedState }, { tourDoneRemembered }] = await Promise.all([
      import('@/mocks/gateway'),
      import('@/mocks/seed'),
      import('@/mocks/tour-memory'),
    ]);

    const state = initial ?? createSeedState();

    // Finishing the tour is remembered in this browser, which the server can't see
    if (initial && tourDoneRemembered()) state.settings.tourDone = true;

    const store = new Store(state);

    return { store, gateway: new MockGateway(store), source: 'mock' };
  }

  const store = new Store(initial ?? emptyState());

  return { store, gateway: new ApiGateway(store), source: 'api' };
}
