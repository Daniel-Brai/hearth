import { act, fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { beforeEach, describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { emptyState } from '@/data/empty-state';
import { Store, StoreContext } from '@/data/store';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { useUi } from '@/runtime/ui-store';
import { Sidebar } from './Sidebar';

async function show(store = new Store(createSeedState())) {
  await act(async () =>
    render(
      <MemoryRouter initialEntries={['/']}>
        <StoreContext value={store}>
          <GatewayContext value={new MockGateway(store)}>
            <Sidebar />
          </GatewayContext>
        </StoreContext>
      </MemoryRouter>,
    ),
  );
}

describe('Sidebar', () => {
  beforeEach(() => useUi.getState().setSidebarOpen(true));

  it('holds skeleton rows while the session loads', async () => {
    await show(new Store({ ...createSeedState(), session: 'loading' }));

    expect(screen.getByRole('complementary', { name: 'Communities' })).toHaveAttribute(
      'aria-busy',
      'true',
    );

    expect(screen.queryByRole('link', { name: /catch up/i })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /your account/i })).not.toBeInTheDocument();
  });

  it('holds skeleton rows before the session restore starts', async () => {
    await show(new Store(emptyState()));

    expect(screen.queryByRole('link', { name: /catch up/i })).not.toBeInTheDocument();
  });

  it('shows the real rows once everything has loaded', async () => {
    const store = new Store({ ...createSeedState(), session: 'loading' });

    await show(store);
    await act(async () => store.set((state) => (state.session = 'ready')));

    expect(screen.getByRole('link', { name: /catch up/i })).toBeInTheDocument();
    expect(screen.getByRole('complementary', { name: 'Communities' })).not.toHaveAttribute(
      'aria-busy',
    );
  });

  it('closes after following a link', async () => {
    await show();

    fireEvent.click(screen.getAllByRole('link')[1]!);

    expect(useUi.getState().sidebarOpen).toBe(false);
  });

  it('stays open for a button that is not a link', async () => {
    await show();

    fireEvent.click(screen.getByRole('button', { name: /jump/i }));

    expect(useUi.getState().sidebarOpen).toBe(true);
  });

  it('marks a private room with a lock', async () => {
    const store = new Store(createSeedState());

    store.set((state) => {
      state.communities.plang!.rooms.find((r) => r.id === 'general')!.access = 'roles';
    });

    await show(store);

    expect(screen.getByRole('img', { name: 'Only some roles can see this room' })).toBeTruthy();
  });
});
