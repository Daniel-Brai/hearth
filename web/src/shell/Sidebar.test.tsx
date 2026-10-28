import { act, fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { beforeEach, describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { useUi } from '@/runtime/ui-store';
import { Sidebar } from './Sidebar';

async function show() {
  const store = new Store(createSeedState());

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
});
