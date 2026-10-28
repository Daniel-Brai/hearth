import { act, fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it, vi } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { NotificationsTray } from './Bar';

function withRead(count: number, more: boolean) {
  const store = new Store(createSeedState());
  store.set((state) => {
    const [first] = state.notifications;

    state.notifications = Array.from({ length: count }, (_, i) => ({
      ...first!,
      id: 'old-' + i,
      read: true,
    }));

    state.directs.forEach((d) => (d.unread = false));
    state.notificationsAfter = more ? 'old-last' : null;
  });
  return store;
}

async function show(store: Store, gateway = new MockGateway(store)) {
  await act(async () =>
    render(
      <MemoryRouter>
        <StoreContext value={store}>
          <GatewayContext value={gateway}>
            <NotificationsTray />
          </GatewayContext>
        </StoreContext>
      </MemoryRouter>,
    ),
  );
}

const items = () => document.querySelectorAll('.tray__earlier .tray__item').length;

describe('NotificationsTray', () => {
  it('caps how many earlier ones it says there are', async () => {
    await show(withRead(150, false));

    expect(screen.getByRole('button', { name: 'Show earlier (99+)' })).toBeTruthy();
  });

  it('says when the server has more than it loaded', async () => {
    await show(withRead(30, true));

    expect(screen.getByRole('button', { name: 'Show earlier (30+)' })).toBeTruthy();
  });

  it('shows earlier ones 20 at a time, then asks the server for more', async () => {
    const store = withRead(30, true);
    const gateway = new MockGateway(store);
    const loadEarlier = vi.spyOn(gateway.notifications, 'loadEarlier');

    await show(store, gateway);

    fireEvent.click(screen.getByRole('button', { name: /Show earlier/ }));
    expect(items()).toBe(20);

    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Show more' })));
    expect(items()).toBe(30);
    expect(loadEarlier).not.toHaveBeenCalled();

    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Show more' })));
    expect(loadEarlier).toHaveBeenCalledOnce();
  });

  it('stops offering more once everything shows', async () => {
    await show(withRead(5, false));

    fireEvent.click(screen.getByRole('button', { name: /Show earlier/ }));

    expect(items()).toBe(5);
    expect(screen.queryByRole('button', { name: 'Show more' })).toBeNull();
  });
});
