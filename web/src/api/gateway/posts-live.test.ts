import { describe, expect, it, vi } from 'vitest';
import { useUi } from '@/runtime/ui-store';
import { community, gateway, kind, page, post, roomSettings, routes } from './test-support';

type Handler = (payload: Record<string, unknown>) => void;

const pushes = vi.hoisted(() => new Map<string, Handler>());
const sounds = vi.hoisted(() => [] as string[]);

vi.mock('../realtime', () => ({
  getRealtime: () => ({
    onPush: (topic: string, event: string, handler: Handler) => {
      pushes.set(`${topic} ${event}`, handler);
      return () => pushes.delete(`${topic} ${event}`);
    },
  }),
}));

vi.mock('@/runtime/sounds', async (actual) => ({
  ...(await actual<typeof import('@/runtime/sounds')>()),
  sfx: (name: string) => sounds.push(name),
}));

const voiceRoom = {
  id: 'v1',
  community_id: 'c1',
  type: 'voice',
  slug: 'office-hours',
  name: 'Office hours',
  topic: null,
  position: 1,
  moderation: null,
  settings: roomSettings,
  archived_at: null,
};

const started = {
  session_id: 's1',
  room_id: 'v1',
  community_id: 'c1',
  host_id: 'u1',
  mode: 'stage',
  topic: 'Hi',
  post_id: 'p1',
};

const reading = async (me: string) => {
  routes['GET /api/posts/p1'] = { status: 200, body: { ...post, live: null } };

  routes['GET /api/communities/c1'] = {
    status: 200,
    body: {
      community: { ...community, rooms: [...community.rooms, voiceRoom] },
      kinds: [kind],
      membership: null,
    },
  };

  routes['GET /api/posts/p1/replies'] = { status: 200, body: page([]) };

  const opened = gateway();

  await opened.gateway.load.post('p1');

  opened.store.set((state) => {
    state.me = me;
  });

  useUi.setState({ toasts: [] });
  sounds.length = 0;

  return opened;
};

const push = (event: string, payload: Record<string, unknown>) =>
  pushes.get(`post:p1 ${event}`)!(payload);

const roomOf = (store: Awaited<ReturnType<typeof reading>>['store']) =>
  store.get().communities['gardeners']?.voice.find((v) => v.id === 'office-hours');

describe('a live discussion of the post being read', () => {
  it('asks a reader to join, with a sound', async () => {
    const { store } = await reading('u2');

    push('VoiceSessionStarted', started);

    expect(roomOf(store)).toMatchObject({ live: true, postId: 'p1', host: 'u1' });
    expect(sounds[0]).toBe('live');

    expect(useUi.getState().toasts.map((t) => t.msg)).toEqual([
      expect.stringContaining('talking this post through live'),
    ]);
  });

  it("doesn't ask the author, who started it", async () => {
    await reading('u1');

    push('VoiceSessionStarted', started);

    expect(sounds).toEqual([]);
    expect(useUi.getState().toasts).toEqual([]);
  });

  it('takes the live note off when it ends', async () => {
    const { store } = await reading('u2');

    push('VoiceSessionStarted', started);

    push('VoiceSessionEnded', { ...started, reason: 'ended' });

    expect(roomOf(store)).toMatchObject({ live: false, postId: null });
  });
});

describe('a recording of the post being read', () => {
  it('goes from the post when the person who recorded it deletes it', async () => {
    const { store } = await reading('u2');

    store.set((state) => {
      state.recordings['r1'] = {
        id: 'r1',
        postId: 'p1',
        c: 'gardeners',
        room: 'Office hours',
        title: 'Office hours',
        duration: '1:00',
        date: 'Oct 28, 2026',
        by: 'u1',
        screen: false,
        real: true,
      };
    });

    push('VoiceRecordingDeleted', {
      recording_id: 'r1',
      session_id: 's1',
      post_id: 'p1',
      community_id: 'c1',
      room_id: 'v1',
    });

    expect(store.get().recordings['r1']).toBeUndefined();
  });
});
