import { act, render, screen } from '@testing-library/react';
import { Suspense } from 'react';
import { RouterProvider, createMemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { EditProfilePage } from './EditProfilePage';

async function show(store: Store) {
  const router = createMemoryRouter(
    [
      { path: '/settings/profile', element: <EditProfilePage /> },
      { path: '*', element: null },
    ],
    { initialEntries: ['/settings/profile'] },
  );

  await act(async () =>
    render(
      <LoadCacheContext value={new LoadCache()}>
        <StoreContext value={store}>
          <GatewayContext value={new MockGateway(store)}>
            <Suspense fallback={null}>
              <RouterProvider router={router} />
            </Suspense>
          </GatewayContext>
        </StoreContext>
      </LoadCacheContext>,
    ),
  );
}

const nameField = () => screen.getByRole('textbox', { name: /^Name/ }) as HTMLInputElement;

describe('EditProfilePage', () => {
  it('waits for the profile before showing a form that could save a placeholder', async () => {
    const store = new Store(createSeedState());

    store.set((state) => {
      delete state.people[state.me!];
    });

    await show(store);

    expect(screen.queryByRole('textbox', { name: /^Name/ })).toBeNull();
  });

  it("starts a fresh form when the session switches people, never keeping the last one's", async () => {
    const store = new Store(createSeedState());

    await show(store);

    const first = nameField().value;

    const other = Object.keys(store.get().people).find((id) => id !== store.get().me)!;

    await act(async () => store.set((state) => (state.me = other)));

    expect(nameField().value).toBe(store.get().people[other]!.name);
    expect(nameField().value).not.toBe(first);
  });
});
