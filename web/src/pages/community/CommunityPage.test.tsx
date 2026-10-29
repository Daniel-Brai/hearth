import { act, render, screen } from '@testing-library/react';
import { Suspense } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { RequestContext } from '@/app/request-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import type { SessionPhase } from '@/domain/app-state';
import type { CommunityVisibility } from '@/domain/types';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { routes } from '@/runtime/routes';
import { CommunityPage } from './CommunityPage';

type Look = {
  hint: boolean;
  session: SessionPhase;
  visibility: CommunityVisibility;
  signedIn?: boolean;
};

async function show({ hint, session, visibility, signedIn = false }: Look) {
  const store = new Store(createSeedState());

  store.set((state) => {
    state.me = signedIn ? state.me : null;
    state.session = session;
    state.communities['elixir']!.visibility = visibility;
  });

  const request = {
    origin: 'https://hearth.example',
    zone: 'UTC',
    signedIn: hint,
    setStatus: () => {},
  };

  const router = createMemoryRouter([{ path: '/c/:community', element: <CommunityPage /> }], {
    initialEntries: [routes.community('elixir')],
  });

  await act(async () =>
    render(
      <RequestContext value={request}>
        <LoadCacheContext value={new LoadCache()}>
          <StoreContext value={store}>
            <GatewayContext value={new MockGateway(store)}>
              <Suspense fallback={null}>
                <RouterProvider router={router} />
              </Suspense>
            </GatewayContext>
          </StoreContext>
        </LoadCacheContext>
      </RequestContext>,
    ),
  );
}

describe('CommunityPage viewer', () => {
  it('shows the guest note and Join without the hint', async () => {
    await show({ hint: false, session: 'pending', visibility: 'public' });

    expect(document.getElementById('community-guest-note')).not.toBeNull();
    expect(screen.getByRole('button', { name: 'Join' })).toBeInTheDocument();
  });

  it('shows the guest note and Join once the restore finds nobody', async () => {
    await show({ hint: true, session: 'out', visibility: 'public' });

    expect(document.getElementById('community-guest-note')).not.toBeNull();
    expect(screen.getByRole('button', { name: 'Join' })).toBeInTheDocument();
  });

  it('shows no guest note and no Join while the viewer is unknown', async () => {
    await show({ hint: true, session: 'pending', visibility: 'public' });

    expect(document.getElementById('community-guest-note')).toBeNull();
    expect(screen.queryByRole('button', { name: 'Join' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Sign in' })).not.toBeInTheDocument();
    expect(screen.getByRole('heading', { level: 1 })).toBeInTheDocument();
  });

  it('shows no Join to a member whose communities are still loading', async () => {
    await show({ hint: true, session: 'loading', visibility: 'public', signedIn: true });

    expect(document.getElementById('community-guest-note')).toBeNull();
    expect(screen.queryByRole('button', { name: 'Join' })).not.toBeInTheDocument();
  });

  it('shows the wall of a private community to a guest', async () => {
    await show({ hint: false, session: 'pending', visibility: 'invite' });

    expect(screen.getByRole('button', { name: 'Sign in' })).toBeInTheDocument();
  });

  it('shows no wall of a private community while the viewer is unknown', async () => {
    await show({ hint: true, session: 'loading', visibility: 'invite' });

    expect(screen.queryByRole('button', { name: 'Sign in' })).not.toBeInTheDocument();
    expect(screen.getByLabelText('Loading')).toBeInTheDocument();
  });
});
