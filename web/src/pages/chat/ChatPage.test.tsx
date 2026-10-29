import { act, render, screen } from '@testing-library/react';
import { Suspense } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { displayName } from '@/domain/selectors';
import type { LinkPreview, RoomAccess } from '@/domain/types';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { ChatPage } from './ChatPage';

async function show(access: RoomAccess, preview: LinkPreview | null = null) {
  const store = new Store(createSeedState());
  const gateway = new MockGateway(store);

  gateway.chat.linkPreview = async () => preview;

  store.set((state) => {
    const general = state.communities.plang!.rooms.find((r) => r.id === 'general')!;
    general.access = access;
    general.roleIds = [];
    state.chats['plang/general'] = [
      {
        id: 'link',
        who: 'ada',
        text: 'Mine is https://github.com/Daniel-Brai',
        time: '9:00',
        boosts: [],
      },
    ];
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
          <GatewayContext value={gateway}>
            <Suspense fallback={null}>
              <RouterProvider router={router} />
            </Suspense>
          </GatewayContext>
        </StoreContext>
      </LoadCacheContext>,
    ),
  );

  return { router, store };
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

  it('shows no card for a link without one', async () => {
    await show('everyone');
    await act(async () => undefined);

    expect(document.querySelector('.og')).toBeNull();
  });

  it("shows the linked page's own card", async () => {
    await show('everyone', {
      url: 'https://github.com/Daniel-Brai',
      site: 'GitHub',
      title: 'Daniel-Brai - Overview',
      desc: 'Software Engineer',
      image: 'https://avatars.githubusercontent.com/u/88239970?v=4',
    });

    const card = await screen.findByRole('link', { name: /Daniel-Brai - Overview/ });

    expect(card.querySelector('img')?.getAttribute('src')).toBe(
      'https://avatars.githubusercontent.com/u/88239970?v=4',
    );
  });

  it('shows who else is typing', async () => {
    const { store } = await show('everyone');

    await act(async () => store.set((state) => void (state.typing['plang/general'] = ['ada'])));

    expect(document.getElementById('typing-note')?.textContent).toBe(
      `${displayName(store.get(), 'ada')} is typing`,
    );
  });

  it('goes back to the community once the room is hidden', async () => {
    const { router } = await show('roles');

    await act(async () => useUi.getState().setHiddenRoom('plang/general'));

    expect(router.state.location.pathname).toBe(routes.community('plang'));
    expect(useUi.getState().hiddenRoom).toBeNull();
  });
});
