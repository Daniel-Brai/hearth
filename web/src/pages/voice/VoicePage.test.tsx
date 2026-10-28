import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { Suspense } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import type { AppState } from '@/domain/app-state';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { VoicePage } from './VoicePage';

async function show(change: (state: AppState) => void) {
  const store = new Store(createSeedState());

  store.set(change);

  const router = createMemoryRouter(
    [
      { path: '/c/:community/voice/:room', element: <VoicePage /> },
      // Leaving the room goes back to Catch up
      { path: routes.home, element: <main id="catch-up" /> },
    ],
    {
      initialEntries: [routes.voice('elixir', 'office-hours')],
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

const idle = (transcription: boolean, recording: boolean) => (state: AppState) => {
  const room = state.communities['elixir']!.voice.find((v) => v.id === 'office-hours')!;

  room.live = false;
  room.host = '';
  state.instance.transcription = transcription;
  state.instance.recording = recording;
};

const card = () => document.querySelector('#voice-room-card')?.textContent ?? '';

describe('VoicePage', () => {
  it('shows a few faces of who is in the room and counts the rest', async () => {
    await show((state) => {
      const room = state.communities['elixir']!.voice.find((v) => v.id === 'office-hours')!;
      room.present = ['ada', 'lin', 'sam', 'raj', 'kim', 'tom'];
    });

    const faces = document.querySelector('#voice-join-faces');

    expect(faces?.querySelectorAll('.avatar')).toHaveLength(4);
    expect(faces?.textContent).toContain('+2');
  });

  it('asks before going back from inside the room, and leaving takes you out', async () => {
    await show((state) => {
      state.live = { ...state.live, joined: true, key: 'elixir/office-hours', role: 'speaker' };
    });

    expect(document.querySelector('#voice-live')).toBeTruthy();

    fireEvent.click(screen.getByRole('link', { name: 'Catch up' }));

    const confirm = useUi.getState().confirm;
    expect(confirm?.action).toBe('Leave room');

    act(() => confirm?.onConfirm({ choice: null, note: '' }));

    await waitFor(() => expect(document.querySelector('#voice-live')).toBeNull());
  });

  it('says voice rooms are off instead of showing a room', async () => {
    await show((state) => {
      state.instance.voice = false;
    });

    expect(screen.getByText('Voice rooms are off on this instance')).toBeTruthy();
    expect(document.querySelector('#voice-room-card')).toBeNull();
  });

  it('makes no promise about transcripts or recordings on the card', async () => {
    await show(idle(true, true));

    expect(card()).not.toMatch(/transcript|recording/i);
  });

  it('leaves the community and room name to the header above the card', async () => {
    await show(idle(false, false));

    const head = document.querySelector('#voice-room-card .idle-room__head')?.textContent;

    expect(head).not.toContain('Office hours');
    expect(head).not.toContain('Elixir');
  });

  it('names no host for a room nobody is running', async () => {
    await show(idle(false, false));

    expect(card()).not.toContain('Hosted by');
    expect(card()).not.toContain('Someone');
  });

  it('leaves the mode off a room nobody is in, where the start choice shows it', async () => {
    await show(idle(false, false));

    expect(document.querySelector('#voice-mode')).toBeNull();
  });

  it('marks a live room you are outside of as live', async () => {
    await show(() => undefined);

    expect(document.querySelector('#voice-live-pill')).not.toBeNull();
  });

  it('drops the live pill once you are in the room', async () => {
    await show((state) => {
      state.live = { ...state.live, joined: true, key: 'elixir/office-hours', role: 'speaker' };
    });

    expect(document.querySelector('#voice-live-pill')).toBeNull();
  });

  it('puts the mode pill in the join card of a live room', async () => {
    await show(() => undefined);

    expect(document.querySelector('#voice-join-card #voice-mode')).not.toBeNull();
  });

  it('tells people about to join that the room is being recorded', async () => {
    await show((state) => {
      state.communities['elixir']!.voice.find((v) => v.id === 'office-hours')!.recording = true;
    });

    expect(document.querySelector('#voice-join-card #voice-join-recording')).not.toBeNull();
  });

  it('shows a recording still being put together, and why one failed', async () => {
    await show((state) => {
      // Neither has a video yet
      const { url: _url, download: _download, ...base } = state.recordings['rec1']!;
      state.recordings['busy'] = { ...base, id: 'busy', rid: 'office-hours', status: 'processing' };
      state.recordings['broken'] = {
        ...base,
        id: 'broken',
        rid: 'office-hours',
        status: 'failed',
        failure: 'Nobody spoke while it was recording.',
      };
    });

    expect(document.querySelector('#recording-busy [role="status"]')).not.toBeNull();
    expect(document.querySelector('#recording-play-busy')).toBeNull();
    expect(document.querySelector('#recording-broken')?.textContent).toContain('Nobody spoke');
  });

  it('offers older recordings when the room has more than one page', async () => {
    await show((state) => {
      const room = state.communities['elixir']!.voice.find((v) => v.id === 'office-hours')!;
      const base = state.recordings['rec1']!;

      state.recordings['older'] = { ...base, id: 'older', rid: 'office-hours' };
      room.recordingsAfter = 'older';
    });

    expect(document.querySelector('#voice-recordings-more')).not.toBeNull();
  });

  it('offers no more recordings once the last page is in', async () => {
    await show((state) => {
      const base = state.recordings['rec1']!;
      state.recordings['older'] = { ...base, id: 'older', rid: 'office-hours' };
    });

    expect(document.querySelector('#voice-recordings-more')).toBeNull();
  });

  it('reads the chat of a room nobody is in', async () => {
    await show(idle(false, false));

    fireEvent.click(document.getElementById('voice-chat-open')!);

    expect(document.querySelector('#voice-chat')).not.toBeNull();
  });

  it('starts a recording playing as soon as you press Play', async () => {
    await show((state) => {
      state.recordings['rec1']!.url = 'https://files.example.test/rec1.mp4';
    });

    fireEvent.click(document.getElementById('recording-play-rec1')!);

    expect(document.querySelector<HTMLVideoElement>('#recording-player-rec1 video')?.autoplay).toBe(
      true,
    );
  });

  it('shows who recorded each recording', async () => {
    await show(() => undefined);

    expect(
      document.querySelector('#recording-rec1 .recording-card__by')?.getAttribute('aria-label'),
    ).toMatch(/^Recorded by /);
  });

  it('starts an idle room with nothing scheduled open, with Open first', async () => {
    await show((state) => {
      idle(false, false)(state);
      state.communities['elixir']!.permissions.push('voice-session.create');
      state.events = [];
    });

    const modes = [...document.querySelectorAll<HTMLInputElement>('input[name="start-talk"]')];

    expect(modes.map((m) => m.value)).toEqual(['open', 'stage']);
    expect(modes.find((m) => m.checked)?.value).toBe('open');
  });

  it('plays a live discussion with a screen share and one without', async () => {
    await show(() => undefined);

    expect(document.querySelector('#recording-play-rec1')).not.toBeNull();
    expect(document.querySelector('#recording-download-rec1')).not.toBeNull();
    expect(document.querySelector('#recording-play-rec2')).not.toBeNull();
    expect(document.querySelector('#recording-download-rec2')).not.toBeNull();
  });

  it('lets only the person who recorded it delete a recording', async () => {
    await show((state) => {
      const base = state.recordings['rec1']!;
      state.recordings['mine'] = { ...base, id: 'mine', rid: 'office-hours', by: state.me! };
    });

    expect(document.querySelector('#recording-delete-mine')).not.toBeNull();
    expect(document.querySelector('#recording-delete-rec1')).toBeNull();
  });

  it('lets only the person who recorded it rename a recording', async () => {
    await show((state) => {
      const base = state.recordings['rec1']!;
      state.recordings['mine'] = { ...base, id: 'mine', rid: 'office-hours', by: state.me! };
    });

    expect(document.querySelector('#recording-rename-mine')).not.toBeNull();
    expect(document.querySelector('#recording-rename-rec1')).toBeNull();
  });

  it('renames a recording when you press Enter', async () => {
    await show((state) => {
      const base = state.recordings['rec1']!;
      state.recordings['mine'] = { ...base, id: 'mine', rid: 'office-hours', by: state.me! };
    });

    fireEvent.click(document.querySelector('#recording-rename-mine')!);
    fireEvent.change(document.querySelector('#recording-title-mine')!, {
      target: { value: 'Supervisor notes' },
    });
    fireEvent.submit(document.querySelector('#recording-rename-form-mine')!);

    await waitFor(() =>
      expect(document.querySelector('#recording-mine strong')?.textContent).toBe(
        'Supervisor notes',
      ),
    );
  });

  it('keeps the old title when you press Escape', async () => {
    await show((state) => {
      const base = state.recordings['rec1']!;
      state.recordings['mine'] = { ...base, id: 'mine', rid: 'office-hours', by: state.me! };
    });

    const before = document.querySelector('#recording-mine strong')?.textContent;

    fireEvent.click(document.querySelector('#recording-rename-mine')!);
    const field = document.querySelector('#recording-title-mine')!;
    fireEvent.change(field, { target: { value: 'Something else' } });
    fireEvent.keyDown(field, { key: 'Escape' });

    await waitFor(() => expect(document.querySelector('#recording-title-mine')).toBeNull());
    expect(document.querySelector('#recording-mine strong')?.textContent).toBe(before);
  });

  it('removes a recording once you confirm deleting it', async () => {
    await show((state) => {
      const base = state.recordings['rec1']!;
      state.recordings['mine'] = { ...base, id: 'mine', rid: 'office-hours', by: state.me! };
    });

    fireEvent.click(document.getElementById('recording-delete-mine')!);
    await act(async () => useUi.getState().confirm?.onConfirm({ choice: null, note: '' }));

    expect(document.querySelector('#recording-mine')).toBeNull();
  });
});
