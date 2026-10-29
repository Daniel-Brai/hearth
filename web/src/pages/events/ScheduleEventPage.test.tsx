import { act, fireEvent, render, screen } from '@testing-library/react';
import { Suspense } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { patterns } from '@/runtime/routes';
import { ScheduleEventPage } from './ScheduleEventPage';

async function show(path: string) {
  const store = new Store(createSeedState());

  const router = createMemoryRouter(
    [
      { path: patterns.eventNew, element: <ScheduleEventPage /> },
      { path: patterns.eventEdit, element: <ScheduleEventPage /> },
      { path: patterns.communityEvents, element: <p>Events</p> },
    ],
    { initialEntries: [path] },
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

describe('ScheduleEventPage', () => {
  it('refuses someone who may not schedule', async () => {
    await show('/c/elixir/events/new');

    expect(screen.getByRole('heading', { name: "You can't schedule events here" })).toBeTruthy();
  });

  it('says when the community is not found', async () => {
    await show('/c/nowhere/events/new');

    expect(screen.getByRole('heading', { name: "We couldn't find that" })).toBeTruthy();
  });

  it('says when the event is not found', async () => {
    await show('/c/plang/e/nothing/edit');

    expect(screen.getByRole('heading', { name: "We couldn't find that" })).toBeTruthy();
  });

  it('asks for a name before scheduling', async () => {
    const { router } = await show('/c/plang/events/new');

    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Schedule event' })));

    expect(screen.getByRole('alert').textContent).toBe('Give the event a name');
    expect(router.state.location.pathname).toBe('/c/plang/events/new');
  });

  it('schedules an event and goes back to the events', async () => {
    const { store, router } = await show('/c/plang/events/new');

    fireEvent.change(screen.getByRole('textbox', { name: 'Name' }), {
      target: { value: 'Office hours' },
    });

    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Schedule event' })));

    expect(store.get().events.some((e) => e.title === 'Office hours')).toBe(true);
    expect(router.state.location.pathname).toBe('/c/plang/events');
  });
});
