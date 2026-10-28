import { act, fireEvent, render, screen } from '@testing-library/react';
import { Suspense } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import type { AppState } from '@/domain/app-state';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { routes } from '@/runtime/routes';
import { TranscriptPage } from './TranscriptPage';

async function show(transcription: boolean, change: (state: AppState) => void = () => {}) {
  const store = new Store(createSeedState());

  store.set((state) => {
    state.instance.transcription = transcription;
    change(state);
  });

  const router = createMemoryRouter(
    [{ path: '/c/:community/sessions/:session', element: <TranscriptPage /> }],
    {
      initialEntries: [routes.session('elixir', 't1')],
    },
  );

  await act(async () =>
    render(
      <LoadCacheContext value={new LoadCache()}>
        <StoreContext value={store}>
          <GatewayContext value={new MockGateway(store)}>
            <Suspense fallback={null}>
              <RouterProvider router={router} />
            </Suspense>
          </GatewayContext>
        </StoreContext>
      </LoadCacheContext>,
    ),
  );
}

describe('TranscriptPage', () => {
  it('says transcripts are off instead of showing one', async () => {
    await show(false);

    expect(screen.getByText('Transcripts are off on this instance')).toBeTruthy();
    expect(screen.queryByText('GenServer state across restarts')).toBeNull();
  });

  it('shows the transcript where the instance transcribes', async () => {
    await show(true);

    expect(screen.getByText('GenServer state across restarts')).toBeTruthy();
  });

  it('says the transcript is still being written', async () => {
    await show(true, (state) => {
      state.transcripts['t1']!.status = 'transcribing';
      state.transcripts['t1']!.lines = [];
    });

    expect(screen.getByText('The transcript is being written')).toBeTruthy();
    expect(screen.queryByText('Nobody said that')).toBeNull();
  });

  it('fixes a line the viewer said', async () => {
    await show(true, (state) => {
      const line = state.transcripts['t1']!.lines[0]!;
      line.id = 'line1';
      line.editable = true;
    });

    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Fix this line' })));

    const box = screen.getByRole('textbox', { name: 'What was said' });

    await act(async () => fireEvent.change(box, { target: { value: 'Welcome, everyone.' } }));
    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Save' })));

    expect(screen.getByText('Welcome, everyone.')).toBeTruthy();
    expect(screen.queryByRole('textbox', { name: 'What was said' })).toBeNull();
  });
});
