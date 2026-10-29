import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { beforeEach, describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { useUi } from '@/runtime/ui-store';
import { NewRoomDialog } from './NewRoomDialog';

async function show() {
  const store = new Store(createSeedState());

  await act(async () =>
    render(
      <MemoryRouter>
        <LoadCacheContext value={new LoadCache()}>
          <StoreContext value={store}>
            <GatewayContext value={new MockGateway(store)}>
              <NewRoomDialog />
            </GatewayContext>
          </StoreContext>
        </LoadCacheContext>
      </MemoryRouter>,
    ),
  );

  return store;
}

describe('NewRoomDialog', () => {
  beforeEach(() => useUi.getState().openDialog('newRoom', { community: 'plang' }));

  it('lets everyone see a new room unless asked', async () => {
    await show();

    expect(screen.getByRole('radio', { name: 'Everyone in the community' })).toHaveProperty(
      'checked',
      true,
    );
    expect(screen.queryByRole('group', { name: 'Roles that can see the room' })).toBeNull();
  });

  it('adds a room only some roles can see', async () => {
    const store = await show();

    fireEvent.change(screen.getByPlaceholderText('release-planning'), {
      target: { value: 'core' },
    });
    fireEvent.click(screen.getByRole('radio', { name: 'Only some roles' }));
    fireEvent.click(screen.getByRole('button', { name: 'Moderator' }));
    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Add room' })));

    const core = () => store.get().communities.plang?.rooms.find((r) => r.id === 'core');

    await waitFor(() => expect(core()).toMatchObject({ access: 'roles', roleIds: ['moderator'] }));
  });
});
