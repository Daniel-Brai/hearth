import { act, fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { beforeEach, describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { useUi } from '@/runtime/ui-store';
import { JumpDialog } from './JumpDialog';

async function show() {
  const store = new Store(createSeedState());

  await act(async () =>
    render(
      <MemoryRouter>
        <LoadCacheContext value={new LoadCache()}>
          <StoreContext value={store}>
            <GatewayContext value={new MockGateway(store)}>
              <JumpDialog />
            </GatewayContext>
          </StoreContext>
        </LoadCacheContext>
      </MemoryRouter>,
    ),
  );
}

describe('JumpDialog', () => {
  beforeEach(() => useUi.getState().openDialog('jump'));

  it('closes with Cancel', async () => {
    await show();

    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Cancel' })));

    expect(useUi.getState().dialog).toBeNull();
  });
});
