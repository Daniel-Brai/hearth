import { act, fireEvent, render, screen } from '@testing-library/react';
import { Suspense } from 'react';
import { MemoryRouter } from 'react-router';
import { afterEach, describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { UpdateBanner } from './UpdateBanner';

async function show(store: Store) {
  await act(async () =>
    render(
      <MemoryRouter>
        <LoadCacheContext value={new LoadCache()}>
          <StoreContext value={store}>
            <GatewayContext value={new MockGateway(store)}>
              <Suspense fallback={null}>
                <UpdateBanner />
              </Suspense>
            </GatewayContext>
          </StoreContext>
        </LoadCacheContext>
      </MemoryRouter>,
    ),
  );
}

afterEach(() => localStorage.clear());

describe('UpdateBanner', () => {
  it('stays hidden for someone who is not an instance admin', async () => {
    const store = new Store(createSeedState());

    store.set((state) => {
      state.instance.isAdmin = false;
      state.instance.update = null;
    });

    await show(store);

    expect(screen.queryByRole('region', { name: 'Hearth update' })).toBeNull();
  });

  it('stays hidden when no newer release is out', async () => {
    const store = new Store(createSeedState());

    store.set((state) => {
      state.instance.update!.available = false;
    });

    await show(store);

    expect(screen.queryByRole('region', { name: 'Hearth update' })).toBeNull();
  });

  it('stays hidden for a release the admin closed it for', async () => {
    localStorage.setItem('hearth-update-dismissed', '0.2.0');

    await show(new Store(createSeedState()));

    expect(screen.queryByRole('region', { name: 'Hearth update' })).toBeNull();
  });

  it('comes back for a newer release than the one it was closed for', async () => {
    localStorage.setItem('hearth-update-dismissed', '0.1.5');

    await show(new Store(createSeedState()));

    expect(screen.getByRole('region', { name: 'Hearth update' })).toBeTruthy();
  });

  it('tells the admin which version is out and hides once closed', async () => {
    await show(new Store(createSeedState()));

    expect(screen.getByText("Hearth 0.2.0 is out. You're on 0.1.0.")).toBeTruthy();

    await act(async () =>
      fireEvent.click(screen.getByRole('button', { name: 'Hide until the next release' })),
    );

    expect(screen.queryByRole('region', { name: 'Hearth update' })).toBeNull();
    expect(localStorage.getItem('hearth-update-dismissed')).toBe('0.2.0');
  });

  it('shows the release notes', async () => {
    await show(new Store(createSeedState()));

    await act(async () => fireEvent.click(screen.getByRole('button', { name: "What's new" })));

    expect(screen.getByRole('heading', { name: 'Hearth 0.2.0' })).toBeTruthy();

    expect(screen.getByRole('link', { name: /View on GitHub/ }).getAttribute('rel')).toBe(
      'noopener noreferrer',
    );
  });
});
