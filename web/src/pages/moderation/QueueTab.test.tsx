import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import type { Permission } from '@/domain/types';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { QueueTab } from './QueueTab';

async function show(permissions: Permission[]) {
  const store = new Store(createSeedState());
  store.set((state) => {
    state.communities.elixir!.moderation = 'full';
    state.communities.elixir!.permissions = permissions;
  });

  await act(async () =>
    render(
      <MemoryRouter>
        <StoreContext value={store}>
          <GatewayContext value={new MockGateway(store)}>
            <QueueTab cid="elixir" name="Elixir" />
          </GatewayContext>
        </StoreContext>
      </MemoryRouter>,
    ),
  );
}

describe('QueueTab', () => {
  it('offers no ban to someone who can only remove content', async () => {
    await show(['content.remove']);

    expect(screen.getAllByRole('button', { name: 'Remove' }).length).toBeGreaterThan(0);
    expect(screen.queryByRole('button', { name: /^Ban/ })).toBeNull();
  });

  it('offers a ban to someone who can also ban members', async () => {
    await show(['content.remove', 'member.ban']);

    expect(screen.getAllByRole('button', { name: /^Ban/ }).length).toBeGreaterThan(0);
  });

  it('lists a decision under Just handled until it is undone', async () => {
    await show(['content.remove']);

    const waiting = screen.getAllByRole('button', { name: /Keep it/ }).length;

    fireEvent.click(screen.getAllByRole('button', { name: /Keep it/ })[0]!);

    await waitFor(() => expect(document.getElementById('queue-handled')).toBeTruthy());

    const undo = screen.getByRole('button', { name: /^Undo, kept up/ });

    fireEvent.click(undo);

    await waitFor(() => expect(document.getElementById('queue-handled')).toBeNull());
    expect(screen.getAllByRole('button', { name: /Keep it/ })).toHaveLength(waiting);
  });
});
