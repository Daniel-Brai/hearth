import { act, render, screen } from '@testing-library/react';
import { Suspense } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { RequestContext } from '@/app/request-context';
import { emptyState } from '@/data/empty-state';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import Home from './home';

async function show(hint: boolean) {
  const store = new Store(emptyState());
  const request = {
    origin: 'https://hearth.example',
    zone: 'UTC',
    signedIn: hint,
    setStatus: () => {},
  };
  const router = createMemoryRouter([{ path: '/', element: <Home /> }]);

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

describe('Home', () => {
  it('shows the public landing without the hint', async () => {
    await show(false);

    expect(screen.getByRole('heading', { level: 1, name: /Communities/ })).toBeInTheDocument();
    expect(screen.queryByLabelText('Loading')).not.toBeInTheDocument();
  });

  it('shows the Catch up skeleton and not the landing with the hint', async () => {
    await show(true);

    expect(screen.getByLabelText('Loading')).toBeInTheDocument();
    expect(screen.queryByRole('heading', { level: 1 })).not.toBeInTheDocument();
  });
});
