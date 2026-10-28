import { act, fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { person } from '@/domain/selectors';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { routes } from '@/runtime/routes';
import { AccountMenu } from './AccountMenu';

async function show(store: Store, at: string) {
  await act(async () =>
    render(
      <MemoryRouter initialEntries={[at]}>
        <StoreContext value={store}>
          <GatewayContext value={new MockGateway(store)}>
            <AccountMenu
              trigger={({ open, toggle }) => (
                <button type="button" onClick={toggle} aria-expanded={open}>
                  Account
                </button>
              )}
            />
            <Routes>
              <Route path={routes.signIn} element={<p>Sign in screen</p>} />
              <Route path="*" element={null} />
            </Routes>
          </GatewayContext>
        </StoreContext>
      </MemoryRouter>,
    ),
  );

  fireEvent.click(screen.getByRole('button', { name: 'Account' }));
}

const myProfile = (store: Store) => routes.profile(person(store.get(), store.get().me).username);

describe('AccountMenu', () => {
  it('shows nothing when signed out', async () => {
    const store = new Store(createSeedState());

    store.set((state) => (state.me = null));

    await act(async () =>
      render(
        <MemoryRouter>
          <StoreContext value={store}>
            <GatewayContext value={new MockGateway(store)}>
              <AccountMenu trigger={() => <button type="button">Account</button>} />
            </GatewayContext>
          </StoreContext>
        </MemoryRouter>,
      ),
    );

    expect(screen.queryByRole('button', { name: 'Account' })).toBeNull();
  });

  it('leaves out the link to your profile while you are on it', async () => {
    const store = new Store(createSeedState());

    await show(store, myProfile(store));

    expect(screen.queryByRole('menuitem', { name: 'Your profile' })).toBeNull();
    expect(screen.getByRole('menuitem', { name: 'Settings' })).toBeTruthy();
  });

  it('links to your profile from anywhere else', async () => {
    const store = new Store(createSeedState());

    await show(store, routes.home);

    expect(screen.getByRole('menuitem', { name: 'Your profile' })).toBeTruthy();
  });

  it('signs you out and goes to sign in', async () => {
    const store = new Store(createSeedState());

    await show(store, routes.home);
    await act(async () => fireEvent.click(screen.getByRole('menuitem', { name: 'Sign out' })));

    expect(store.get().me).toBeNull();
    expect(screen.getByText('Sign in screen')).toBeTruthy();
  });
});
