import { act, render } from '@testing-library/react';
import { Suspense, type ReactNode } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { GatewayContext } from '@/app/gateway-context';
import { RequestContext } from '@/app/request-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import type { SessionPhase } from '@/domain/app-state';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';

type Screen = {
  readonly path: string;
  readonly url: string;
  readonly element: ReactNode;
  readonly hint: boolean;
  readonly session: SessionPhase;
  readonly signedIn: boolean;
};

/** Renders one screen as a reload would see it, with or without the signed in hint */
export async function showScreen({ path, url, element, hint, session, signedIn }: Screen) {
  const store = new Store(createSeedState());

  store.set((state) => {
    state.me = signedIn ? state.me : null;
    state.session = session;
  });

  const request = {
    origin: 'https://hearth.example',
    zone: 'UTC',
    signedIn: hint,
    setStatus: () => {},
  };
  const router = createMemoryRouter([{ path, element }], { initialEntries: [url] });

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

  return store;
}
