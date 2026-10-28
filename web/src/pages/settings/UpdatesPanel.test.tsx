import { act, render, screen } from '@testing-library/react';
import { Suspense } from 'react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import type { InstanceUpdate } from '@/domain/types';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { UpdatesPanel } from './UpdatesPanel';

async function show(patch: Partial<InstanceUpdate>) {
  const store = new Store(createSeedState());
  store.set((state) => Object.assign(state.instance.update!, patch));

  await act(async () =>
    render(
      <MemoryRouter>
        <LoadCacheContext value={new LoadCache()}>
          <StoreContext value={store}>
            <GatewayContext value={new MockGateway(store)}>
              <Suspense fallback={null}>
                <UpdatesPanel />
              </Suspense>
            </GatewayContext>
          </StoreContext>
        </LoadCacheContext>
      </MemoryRouter>,
    ),
  );
}

describe('UpdatesPanel', () => {
  it('says the check is off when the server turned it off', async () => {
    await show({ enabled: false, available: false, latest: null });

    expect(screen.getByText(/turned off in the server settings/)).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Check now' })).toBeNull();
  });

  it('says the instance is up to date', async () => {
    await show({ available: false, latest: '0.1.0' });

    expect(screen.getByText("You're on the latest version.")).toBeTruthy();
    expect(screen.queryByText('How to update')).toBeNull();
  });

  it('shows the notes and how to update when a release is out', async () => {
    await show({});

    expect(screen.getByText('Hearth 0.2.0 is out.')).toBeTruthy();
    expect(screen.getByText('How to update')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Check now' })).toBeTruthy();
  });
});
