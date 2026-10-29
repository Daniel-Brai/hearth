import { act, fireEvent, render, screen } from '@testing-library/react';
import { Suspense } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { EditCommunityPage } from './EditCommunityPage';

async function show(cid: string) {
  const store = new Store(createSeedState());

  const router = createMemoryRouter(
    [
      { path: '/c/:community/edit', element: <EditCommunityPage /> },
      { path: '/c/:community', element: <h1>Community</h1> },
    ],
    { initialEntries: [`/c/${cid}/edit`] },
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

  return store;
}

describe('EditCommunityPage', () => {
  it('tells someone who may not edit that they can not', async () => {
    await show('elixir');

    expect(screen.getByRole('heading', { name: "You can't edit this community" })).toBeTruthy();
  });

  it('shows the form with ownership to the owner', async () => {
    await show('plang');

    expect(screen.getByRole('textbox', { name: 'Description' })).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Transfer ownership' })).toBeTruthy();
  });

  it('keeps a kind added before saving', async () => {
    const store = await show('plang');

    await act(async () => fireEvent.click(document.getElementById('edit-kinds-add')!));

    const added = screen
      .getAllByRole<HTMLInputElement>('textbox', { name: 'Kind name' })
      .at(-1)!.value;

    await act(async () => fireEvent.submit(document.getElementById('edit-community-form')!));

    expect(store.get().communities.plang?.kinds.map((k) => k.name)).toContain(added);
  });
});
