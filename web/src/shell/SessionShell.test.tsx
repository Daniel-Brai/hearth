import { act, render, screen } from '@testing-library/react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { ClientOnlyFallback } from '@/app/routes/client-only';
import { GatewayContext } from '@/app/gateway-context';
import { RequestContext } from '@/app/request-context';
import { emptyState } from '@/data/empty-state';
import { Store, StoreContext } from '@/data/store';
import { MockGateway } from '@/mocks/gateway';
import { SessionShell } from './SessionShell';

async function show(signedIn: boolean, session: 'pending' | 'out' = 'pending') {
  const store = new Store({ ...emptyState(), session });
  const request = { origin: 'https://hearth.example', zone: 'UTC', signedIn, setStatus: () => {} };

  const router = createMemoryRouter(
    [
      {
        path: '/',
        element: <SessionShell />,
        children: [{ index: true, element: <ClientOnlyFallback /> }],
      },
    ],
    { initialEntries: ['/'] },
  );

  await act(async () =>
    render(
      <RequestContext value={request}>
        <StoreContext value={store}>
          <GatewayContext value={new MockGateway(store)}>
            <RouterProvider router={router} />
          </GatewayContext>
        </StoreContext>
      </RequestContext>,
    ),
  );
}

describe('SessionShell fallback', () => {
  it('shows the bare bar without the hint', async () => {
    await show(false);

    expect(screen.getByRole('button', { name: 'Sign in' })).toBeInTheDocument();
    expect(screen.queryByRole('complementary', { name: 'Communities' })).not.toBeInTheDocument();
  });

  it('shows the bare bar once the session restore found nobody', async () => {
    await show(true, 'out');

    expect(screen.queryByRole('complementary', { name: 'Communities' })).not.toBeInTheDocument();
  });

  it('shows the app frame with the hint', async () => {
    await show(true);

    const sidebar = screen.getByRole('complementary', { name: 'Communities' });

    expect(sidebar).toHaveAttribute('aria-busy', 'true');
    expect(screen.getByRole('main')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Sign in' })).not.toBeInTheDocument();
  });
});
