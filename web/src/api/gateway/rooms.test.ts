import { afterEach, describe, expect, it, vi } from 'vitest';
import { community, gateway, kind, message, page, routes, sent } from './test-support';

vi.mock('../realtime', () => ({ getRealtime: () => ({ onPush: () => () => undefined }) }));

const room = community.rooms[0]!;

const loaded = async () => {
  routes['GET /api/communities/gardeners'] = {
    status: 200,
    body: { community, kinds: [kind], membership: null },
  };

  routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
  routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };

  const g = gateway();

  await g.gateway.load.community('gardeners');

  return g;
};

describe('rooms', () => {
  it('says why a room could not be archived', async () => {
    const { gateway: g } = await loaded();
    routes['POST /api/rooms/r1/archive'] = {
      status: 403,
      body: { message: "You can't do that.", code: 'forbidden' },
    };

    expect(await g.rooms.archive('gardeners', 'general')).toEqual({
      ok: false,
      error: "You can't do that.",
    });
  });

  it('archives a room and shows the community without it', async () => {
    const { store, gateway: g } = await loaded();

    routes['POST /api/rooms/r1/archive'] = {
      status: 200,
      body: { ...room, archived_at: '2026-10-25T10:00:00Z' },
    };

    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community: { ...community, rooms: [] }, kinds: [kind], membership: null },
    };

    expect((await g.rooms.archive('gardeners', 'general')).ok).toBe(true);
    expect(store.get().communities.gardeners?.rooms).toEqual([]);
  });

  it('lists archived rooms by their key, then restores one', async () => {
    const { store, gateway: g } = await loaded();

    const archived = {
      ...room,
      id: 'r2',
      slug: 'old',
      name: 'old',
      archived_at: '2026-10-25T10:00:00Z',
    };

    routes['GET /api/communities/c1/rooms/archived'] = [
      { status: 200, body: [archived] },
      { status: 200, body: [] },
    ];

    routes['POST /api/rooms/r2/restore'] = {
      status: 200,
      body: { ...archived, archived_at: null },
    };

    await g.load.archivedRooms('gardeners');

    expect(store.get().archivedRooms.gardeners).toEqual([
      { id: 'old', name: 'old', type: 'text', archivedAt: '2026-10-25T10:00:00Z' },
    ]);

    expect((await g.rooms.restore('gardeners', 'old')).ok).toBe(true);
    expect(store.get().archivedRooms.gardeners).toEqual([]);
  });

  it('deletes a room for good', async () => {
    const { gateway: g } = await loaded();

    routes['DELETE /api/rooms/r1'] = { status: 204 };

    expect((await g.rooms.destroy('gardeners', 'general')).ok).toBe(true);
    expect(sent.some((r) => r.method === 'DELETE' && r.path === '/api/rooms/r1')).toBe(true);
  });
});

describe('rooms.updateSettings', () => {
  it('puts the topic back when the server refuses it', async () => {
    const { store, gateway: g } = await loaded();

    routes['PATCH /api/rooms/r1'] = {
      status: 403,
      body: { message: "You can't do that.", code: 'forbidden' },
    };

    g.rooms.updateSettings('gardeners/general', { topic: 'Seeds' });
    expect(g.rooms.settings('gardeners/general').topic).toBe('Seeds');

    await vi.waitFor(() => expect(store.get().roomSettings['gardeners/general']?.topic).toBeNull());
  });

  it('puts the previews back when the server refuses them', async () => {
    const { store, gateway: g } = await loaded();

    routes['PATCH /api/rooms/r1'] = {
      status: 403,
      body: { message: "You can't do that.", code: 'forbidden' },
    };

    g.rooms.updateSettings('gardeners/general', { previews: false });
    expect(g.rooms.settings('gardeners/general').previews).toBe(false);

    await vi.waitFor(() =>
      expect(store.get().roomSettings['gardeners/general']?.previews).toBe(true),
    );
  });

  it('saves who can play sounds with the room', async () => {
    const { gateway: g } = await loaded();
    const sounds = { enabled: true, mode: 'people' as const, roles: [], people: ['u2'] };

    routes['PATCH /api/rooms/r1'] = { status: 200, body: room };

    g.rooms.updateSettings('gardeners/general', { sounds });

    await vi.waitFor(() =>
      expect(sent).toContainEqual({
        method: 'PATCH',
        path: '/api/rooms/r1',
        body: {
          settings: {
            sounds_enabled: true,
            sounds_mode: 'people',
            sounds_role_ids: [],
            sounds_user_ids: ['u2'],
          },
        },
      }),
    );
  });

  it('shows the settings the server kept when the community loads', async () => {
    const { gateway: g } = await loaded();
    const settings = { ...room.settings, link_previews: false, sounds_enabled: false };

    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: {
        community: { ...community, rooms: [{ ...room, settings }] },
        kinds: [kind],
        membership: null,
      },
    };

    await g.load.community('gardeners');

    expect(g.rooms.settings('gardeners/general')).toMatchObject({
      previews: false,
      sounds: { enabled: false },
    });
  });

  it('saves the topic, which shows when the community loads again', async () => {
    const { gateway: g } = await loaded();

    routes['PATCH /api/rooms/r1'] = { status: 200, body: { ...room, topic: 'Seeds' } };

    g.rooms.updateSettings('gardeners/general', { topic: 'Seeds' });

    await vi.waitFor(() =>
      expect(sent).toContainEqual({
        method: 'PATCH',
        path: '/api/rooms/r1',
        body: { topic: 'Seeds' },
      }),
    );

    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: {
        community: { ...community, rooms: [{ ...room, topic: 'Seeds' }] },
        kinds: [kind],
        membership: null,
      },
    };

    await g.load.community('gardeners');

    expect(g.rooms.settings('gardeners/general').topic).toBe('Seeds');
  });
});

describe('rooms.markRead', () => {
  const opened = async () => {
    const g = await loaded();

    routes['GET /api/rooms/r1/messages'] = {
      status: 200,
      body: page([message('m2', 'Later'), message('m1', 'Hi')]),
    };

    await g.gateway.load.chat('gardeners/general');

    g.store.set((state) => {
      const general = state.communities.gardeners?.rooms[0];
      if (general) general.unread = 2;
    });

    vi.useFakeTimers();

    return g;
  };

  const unread = (store: ReturnType<typeof gateway>['store']) =>
    store.get().communities.gardeners?.rooms[0]?.unread;

  afterEach(() => vi.useRealTimers());

  it('shows the room unread again when the server refuses the mark', async () => {
    const { store, gateway: g } = await opened();

    routes['POST /api/messages/m2/read'] = {
      status: 403,
      body: { message: 'Forbidden', code: 'forbidden' },
    };

    g.rooms.markRead('gardeners', 'general');
    vi.advanceTimersByTime(1000);
    expect(unread(store)).toBe(0);

    await vi.waitFor(() => expect(unread(store)).toBe(2));
  });

  it('marks the room read up to its newest message once, after it has been open a moment', async () => {
    const { store, gateway: g } = await opened();

    routes['POST /api/messages/m2/read'] = { status: 204 };

    g.rooms.markRead('gardeners', 'general');
    g.rooms.markRead('gardeners', 'general');
    expect(unread(store)).toBe(2);

    vi.advanceTimersByTime(1000);
    g.rooms.markRead('gardeners', 'general');
    vi.advanceTimersByTime(1000);

    expect(unread(store)).toBe(0);

    expect(sent.filter((r) => r.path.endsWith('/read'))).toEqual([
      { method: 'POST', path: '/api/messages/m2/read', body: null },
    ]);
  });
});
