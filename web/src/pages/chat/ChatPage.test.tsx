import { act, render, screen } from '@testing-library/react';
import { Suspense } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import type { RoomAccess } from '@/domain/types';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { ChatPage } from './ChatPage';

async function show(access: RoomAccess) {
  const store = new Store(createSeedState());

  store.set((state) => {
    const general = state.communities.plang!.rooms.find((r) => r.id === 'general')!;
    general.access = access;
    general.roleIds = [];
  });

  const router = createMemoryRouter(
    [
      { path: '/c/:community/chat/:room', element: <ChatPage /> },
      { path: '/c/:community', element: <p>Community</p> },
    ],
    { initialEntries: [routes.chat('plang', 'general')] },
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

  return router;
}

const promote = () => screen.queryByRole('button', { name: 'Select messages to turn into a post' });

describe('ChatPage', () => {
  it('offers no promoting in a private room', async () => {
    await show('roles');

    expect(promote()).toBeNull();
    expect(screen.getByRole('img', { name: 'Only some roles can see this room' })).toBeTruthy();
  });

  it('offers promoting in a room for everyone', async () => {
    await show('everyone');

    expect(promote()).toBeTruthy();
    expect(screen.queryByRole('img', { name: 'Only some roles can see this room' })).toBeNull();
  });

  it('goes back to the community once the room is hidden', async () => {
    const router = await show('roles');

    await act(async () => useUi.getState().setHiddenRoom('plang/general'));

    expect(router.state.location.pathname).toBe(routes.community('plang'));
    expect(useUi.getState().hiddenRoom).toBeNull();
  });
});
