import { describe, expect, it, vi } from 'vitest';
import {
  community,
  file,
  gateway,
  kind,
  message,
  page,
  post,
  routes,
  sent,
  session,
} from './test-support';

const pushes = vi.hoisted(() => new Map<string, (payload: { message_id: string }) => void>());

vi.mock('../realtime', () => ({
  getRealtime: () => ({
    onPush: (topic: string, event: string, handler: (payload: { message_id: string }) => void) => {
      pushes.set(`${topic} ${event}`, handler);
      return () => pushes.delete(`${topic} ${event}`);
    },
  }),
}));

describe('chat.send', () => {
  it('shows the message at once, then the one the server kept', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };

    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };
    routes['POST /api/rooms/r1/messages'] = { status: 201, body: message('m1', 'Hello') };

    const { store, gateway: g } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    expect(g.chat.send('gardeners/general', 'Hello').ok).toBe(true);
    expect(store.get().chats['gardeners/general']?.[0]?.id).toMatch(/^pending-/);

    await vi.waitFor(() =>
      expect(store.get().chats['gardeners/general']?.map((m) => m.id)).toEqual(['m1']),
    );
  });

  it('takes the message back when the server refuses it', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };

    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };

    routes['POST /api/rooms/r1/messages'] = {
      status: 403,
      body: { message: 'Forbidden', code: 'forbidden' },
    };

    const { store, gateway: g } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    g.chat.send('gardeners/general', 'Hello');

    await vi.waitFor(() => expect(store.get().chats['gardeners/general']).toEqual([]));
  });
});

describe('chat.edit', () => {
  it('keeps a file the server has without sending it again', async () => {
    routes['PATCH /api/messages/m1'] = {
      status: 200,
      body: { ...message('m1', ''), attachments: [file] },
    };

    const { store, gateway: g } = gateway();
    const shown = { id: file.id, name: 'plot.png', kind: 'image' as const, size: 3, url: 'x' };

    store.set((state) => {
      state.chats['gardeners/general'] = [
        { id: 'm1', who: 'u1', text: 'Look', time: '9:00', boosts: [], files: [shown] },
      ];
    });

    expect(g.chat.edit('gardeners/general', 'm1', { text: '', files: [shown] }).ok).toBe(true);

    await vi.waitFor(() =>
      expect(sent.at(-1)).toMatchObject({ body: { body: '', attachment_ids: [file.id] } }),
    );

    expect(sent.some((r) => r.path === '/api/uploads')).toBe(false);
  });
});

describe('chat.toggleBoost', () => {
  const opened = async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };
    routes['GET /api/rooms/r1/messages'] = { status: 200, body: page([message('m1', 'Hi')]) };

    const g = gateway();

    await g.gateway.load.chat('gardeners/general');

    return g;
  };

  const boosts = (store: ReturnType<typeof gateway>['store']) =>
    store.get().chats['gardeners/general']?.[0]?.boosts;

  it('takes the reaction back when the server refuses it', async () => {
    const { store, gateway: g } = await opened();

    routes['POST /api/messages/m1/reactions'] = {
      status: 403,
      body: { message: 'Forbidden', code: 'forbidden' },
    };

    g.chat.toggleBoost('gardeners/general', 'm1', '🔥');
    expect(boosts(store)).toEqual([{ e: '🔥', n: 1, mine: true }]);

    await vi.waitFor(() => expect(boosts(store)).toEqual([]));
  });

  it('follows the server when it says the reaction is off', async () => {
    const { store, gateway: g } = await opened();

    routes['POST /api/messages/m1/reactions'] = { status: 200, body: { on: false } };

    g.chat.toggleBoost('gardeners/general', 'm1', '🔥');

    await vi.waitFor(() => expect(boosts(store)).toEqual([]));
  });

  it('adds the reaction at once and sends it', async () => {
    const { store, gateway: g } = await opened();

    routes['POST /api/messages/m1/reactions'] = { status: 200, body: { on: true } };

    g.chat.toggleBoost('gardeners/general', 'm1', '🔥');

    await vi.waitFor(() =>
      expect(sent).toContainEqual({
        method: 'POST',
        path: '/api/messages/m1/reactions',
        body: { emoji: '🔥' },
      }),
    );

    expect(boosts(store)).toEqual([{ e: '🔥', n: 1, mine: true }]);
  });
});

describe('load.chat', () => {
  const voiceRoom = {
    ...community.rooms[0]!,
    id: 'r2',
    type: 'voice',
    slug: 'hangout',
    name: 'Hangout',
  };

  it('fetches again when a message is edited or deleted', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };
    routes['GET /api/rooms/r1/messages'] = { status: 200, body: page([message('m1', 'Hi')]) };

    const { store, gateway: g } = gateway();

    await g.load.chat('gardeners/general');

    routes['GET /api/rooms/r1/messages'] = { status: 200, body: page([message('m1', 'Hello')]) };
    pushes.get('room:r1 MessageEdited')?.({ message_id: 'm1' });

    await vi.waitFor(() => expect(store.get().chats['gardeners/general']?.[0]?.text).toBe('Hello'));

    routes['GET /api/rooms/r1/messages'] = { status: 200, body: page([]) };
    pushes.get('room:r1 MessageRemoved')?.({ message_id: 'm1' });

    await vi.waitFor(() => expect(store.get().chats['gardeners/general']).toEqual([]));
  });

  it("shows someone else's reaction as it happens", async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };
    routes['GET /api/rooms/r1/messages'] = { status: 200, body: page([message('m1', 'Hi')]) };

    const { store, gateway: g } = gateway();

    await g.load.chat('gardeners/general');

    const reacted = { message_id: 'm1', user_id: 'u9', emoji: '🔥', on: true, count: 2 };
    pushes.get('room:r1 MessageReacted')?.(reacted);

    expect(store.get().chats['gardeners/general']?.[0]?.boosts).toEqual([
      { e: '🔥', n: 2, mine: false },
    ]);

    const takenBack = { ...reacted, on: false, count: 0 };
    pushes.get('room:r1 MessageReacted')?.(takenBack);

    expect(store.get().chats['gardeners/general']?.[0]?.boosts).toEqual([]);
  });

  it('loads the chat beside a voice room', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community: { ...community, rooms: [voiceRoom] }, kinds: [], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };

    routes['GET /api/rooms/r2/messages'] = {
      status: 200,
      body: page([{ ...message('m1', 'Link from the call'), room_id: 'r2' }]),
    };

    const { store, gateway: g } = gateway();

    expect((await g.load.chat('gardeners/hangout')).ok).toBe(true);

    expect(store.get().chats['gardeners/hangout']?.map((m) => m.text)).toEqual([
      'Link from the call',
    ]);
  });
});

describe('chat inbox', () => {
  it('loads direct messages and unread counts after sign in, and counts new room messages', async () => {
    const other = {
      id: 'u2',
      username: 'lin',
      display_name: 'Lin',
      avatar_id: null,
      avatar_url: null,
    };
    const self = {
      id: 'u1',
      username: 'ada',
      display_name: 'Ada',
      avatar_id: null,
      avatar_url: null,
    };

    routes['POST /api/auth/sessions'] = { status: 200, body: session };
    routes['GET /api/communities'] = { status: 200, body: [community] };

    routes['GET /api/conversations'] = {
      status: 200,
      body: [
        { id: 'cv1', kind: 'direct', name: null, member_ids: ['u1', 'u2'], members: [self, other] },
      ],
    };

    routes['GET /api/unread'] = {
      status: 200,
      body: {
        rooms: [{ id: 'r1', community_id: 'c1', count: 3 }],
        conversations: [{ id: 'cv1', count: 2 }],
      },
    };

    const { store, gateway: g } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    await vi.waitFor(() => expect(store.get().directs).toEqual([{ who: 'u2', unread: 2 }]));

    const general = () =>
      store.get().communities['gardeners']?.rooms.find((r) => r.id === 'general')?.unread;

    expect(general()).toBe(3);
    expect(store.get().people['u2']?.name).toBe('Lin');

    const activity = { message_id: 'x', room_id: 'r1', community_id: 'c1' };
    pushes.get('community:c1 RoomActivity')?.(activity);

    expect(general()).toBe(4);

    g.chat.open('dm/u2');

    expect(store.get().directs).toEqual([{ who: 'u2', unread: 0 }]);
  });
});

describe('chat.hidePreview', () => {
  it('takes the link card off and puts it back when the server refuses', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };
    routes['GET /api/rooms/r1/messages'] = { status: 200, body: page([message('m1', 'Hi')]) };
    routes['PUT /api/messages/m1/preview'] = { status: 403, body: { message: 'Forbidden' } };

    const { store, gateway: g } = gateway();

    await g.load.chat('gardeners/general');

    g.chat.hidePreview('gardeners/general', 'm1');

    expect(store.get().chats['gardeners/general']?.[0]?.previewHidden).toBe(true);

    await vi.waitFor(() =>
      expect(store.get().chats['gardeners/general']?.[0]?.previewHidden).toBe(false),
    );
  });
});

describe('chat.promote', () => {
  const open = async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [kind], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };

    const opened = gateway();

    await opened.gateway.load.community('gardeners');

    return opened;
  };

  it('fails for a room that is not loaded', async () => {
    const r = await gateway().gateway.chat.promote('gardeners/general', ['m1'], {
      title: 'Watering',
      kind: 'Question',
    });

    expect(r).toEqual({ ok: false, error: 'That room is not loaded.' });
  });

  it('says why when the server refuses', async () => {
    const { gateway: g } = await open();

    routes['POST /api/rooms/r1/posts'] = { status: 403, body: { message: 'Forbidden' } };

    const r = await g.chat.promote('gardeners/general', ['m1'], {
      title: 'Watering',
      kind: 'Question',
    });

    expect(r).toEqual({ ok: false, error: 'Forbidden' });
  });

  it('sends the picked messages and keeps the post with where it started', async () => {
    const { store, gateway: g } = await open();

    routes['POST /api/rooms/r1/posts'] = {
      status: 201,
      body: { ...post, from_chat: { room_id: 'r1', message_count: 2, promoted_by: null } },
    };

    const r = await g.chat.promote('gardeners/general', ['m2', 'm1'], {
      title: ' Watering ',
      kind: 'Question',
    });

    expect(sent.at(-1)?.body).toEqual({
      message_ids: ['m2', 'm1'],
      kind_id: kind.id,
      title: 'Watering',
    });
    expect(r.ok && r.value.post.fromChat).toEqual({ room: 'general', count: 2 });
    expect(store.get().posts[0]?.fromChat).toEqual({ room: 'general', count: 2 });
  });
});
