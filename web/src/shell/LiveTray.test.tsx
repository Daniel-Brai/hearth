import { act, render } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { routes } from '@/runtime/routes';
import { LiveTray } from './Bar';

async function show(at: string) {
  const store = new Store(createSeedState());

  store.set((state) => {
    state.live = { joined: true, key: 'elixir/office-hours', role: 'listener', muted: true };
  });

  await act(async () =>
    render(
      <MemoryRouter initialEntries={[at]}>
        <StoreContext value={store}>
          <GatewayContext value={new MockGateway(store)}>
            <LiveTray />
          </GatewayContext>
        </StoreContext>
      </MemoryRouter>,
    ),
  );
}

describe('LiveTray', () => {
  it('offers only leaving while you are looking at the room you are in', async () => {
    await show(routes.voice('elixir', 'office-hours'));

    expect(document.querySelector('#live-tray-return')).toBeNull();
  });

  it('offers a way back to your room from anywhere else', async () => {
    await show(routes.home);

    expect(document.querySelector('#live-tray-return')).not.toBeNull();
  });
});
