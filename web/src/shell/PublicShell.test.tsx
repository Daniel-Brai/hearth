import { act, render } from '@testing-library/react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { ok, type Result } from '@/data/gateway';
import { Store, StoreContext } from '@/data/store';
import { emptyState } from '@/data/empty-state';
import { MockGateway } from '@/mocks/gateway';
import { PublicShell } from './PublicShell';

async function show(session: Promise<Result>) {
  const store = new Store(emptyState());
  const gateway = new MockGateway(store);

  gateway.load.session = () => session;

  const router = createMemoryRouter([{ path: '/', element: <PublicShell /> }]);

  await act(async () =>
    render(
      <StoreContext value={store}>
        <GatewayContext value={gateway}>
          <RouterProvider router={router} />
        </GatewayContext>
      </StoreContext>,
    ),
  );
}

const signIn = () => document.getElementById('public-sign-in')!;

describe('PublicShell', () => {
  it('holds Sign in back while the browser is still restoring a session', async () => {
    await show(new Promise(() => undefined));

    expect(signIn()).toHaveClass('is-waiting');
    expect(signIn()).toHaveAttribute('aria-hidden', 'true');
  });

  it('shows Sign in once the browser finds nobody signed in', async () => {
    await show(Promise.resolve(ok(undefined)));

    expect(signIn()).not.toHaveClass('is-waiting');
  });
});
