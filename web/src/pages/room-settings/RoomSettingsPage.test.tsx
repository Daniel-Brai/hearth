import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { Suspense } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { patterns, routes } from '@/runtime/routes';
import { RoomSettingsPage } from './RoomSettingsPage';

async function show(cid: string, room: string) {
  const store = new Store(createSeedState());

  const router = createMemoryRouter(
    [
      { path: patterns.roomSettings, element: <RoomSettingsPage /> },
      { path: patterns.chat, element: <p>Chat</p> },
    ],
    { initialEntries: [routes.roomSettings(cid, room)] },
  );

  await act(async () =>
    render(
      <StoreContext value={store}>
        <GatewayContext value={new MockGateway(store)}>
          <LoadCacheContext value={new LoadCache()}>
            <Suspense>
              <RouterProvider router={router} />
            </Suspense>
          </LoadCacheContext>
        </GatewayContext>
      </StoreContext>,
    ),
  );

  return { store, router };
}

describe('RoomSettingsPage', () => {
  it('tells someone who may not change rooms that they can not', async () => {
    await show('elixir', 'general');

    expect(screen.getByRole('heading', { name: "You can't change this room" })).toBeTruthy();
  });

  it('says when the room is not found', async () => {
    await show('plang', 'nowhere');

    expect(screen.getByRole('heading', { name: "We couldn't find that" })).toBeTruthy();
  });

  it('shows every setting to someone who can change rooms', async () => {
    await show('plang', 'general');

    expect(screen.getByRole('textbox', { name: /Name/ })).toBeTruthy();
    expect(screen.getByRole('textbox', { name: 'Topic' })).toBeTruthy();
    expect(screen.getByRole('radiogroup', { name: 'Who can see it?' })).toBeTruthy();
    expect(screen.getByRole('checkbox', { name: 'Link previews' })).toBeTruthy();
    expect(screen.getByRole('radiogroup', { name: 'Moderation' })).toBeTruthy();
    expect(screen.getByRole('checkbox', { name: 'Sounds' })).toBeTruthy();
  });

  it('saves the topic and goes back to the room', async () => {
    const { store, router } = await show('plang', 'general');

    fireEvent.change(screen.getByRole('textbox', { name: 'Topic' }), {
      target: { value: 'Say hello' },
    });

    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Done' })));

    expect(store.get().roomSettings['plang/general']?.topic).toBe('Say hello');
    expect(router.state.location.pathname).toBe(routes.chat('plang', 'general'));
  });

  it('renames the room', async () => {
    const { router } = await show('plang', 'general');

    fireEvent.change(screen.getByRole('textbox', { name: /Name/ }), {
      target: { value: 'lobby' },
    });

    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Done' })));

    await waitFor(() => expect(router.state.location.pathname).toBe(routes.chat('plang', 'lobby')));
  });
});
