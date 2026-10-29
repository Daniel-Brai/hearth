import { describe, expect, it, vi } from 'vitest';
import {
  at,
  community,
  file,
  gateway,
  kind,
  openPost,
  page,
  post,
  reply,
  roomSettings,
  routes,
  sent,
  session,
} from './test-support';

vi.mock('../realtime', () => ({ getRealtime: () => ({ onPush: () => () => undefined }) }));

describe('posts.create', () => {
  it('sends the ids the server knows the community and kind by', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [kind], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };
    routes['POST /api/communities/c1/posts'] = { status: 201, body: post };

    const { gateway: g } = gateway();

    await g.load.community('gardeners');

    const r = await g.posts.create({
      c: 'gardeners',
      kind: 'Question',
      title: 'Hi',
      body: 'Hello',
    });

    expect(r.ok).toBe(true);

    expect(sent.at(-1)?.body).toEqual({
      kind_id: 'k1',
      title: 'Hi',
      body: 'Hello',
      attachment_ids: [],
    });
  });

  it('uploads a new file first and points the text at it', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [kind], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };

    routes['POST /api/uploads'] = {
      status: 201,
      body: { media: file, upload: { url: 'https://storage.test/put', headers: {} } },
    };

    routes['PUT /put'] = { status: 200 };
    routes['POST /api/uploads/' + file.id + '/complete'] = { status: 200, body: file };

    routes['POST /api/communities/c1/posts'] = {
      status: 201,
      body: { ...post, attachments: [file] },
    };

    const { gateway: g, store } = gateway();

    await g.load.community('gardeners');

    const r = await g.posts.create({
      c: 'gardeners',
      kind: 'Question',
      title: 'Hi',
      body: 'Look ![plot](attachment:f1)',
      files: [
        { id: 'f1', name: 'plot.png', kind: 'image', size: 3, data: 'data:image/png;base64,AAAA' },
      ],
    });

    expect(r.ok).toBe(true);

    expect(sent.at(-1)?.body).toMatchObject({
      body: `Look ![plot](attachment:${file.id})`,
      attachment_ids: [file.id],
    });

    expect(store.get().posts[0]?.files).toMatchObject([
      { id: file.id, url: 'https://storage.test/plot.webp' },
    ]);
  });
});

describe('posts.edit', () => {
  it('puts the post back when the server refuses', async () => {
    const { gateway: g, store } = await openPost();

    routes['PATCH /api/posts/p1'] = { status: 403, body: { message: 'Forbidden' } };

    const r = await g.posts.edit('p1', {
      title: 'New',
      body: 'Changed',
      kind: 'Question',
      files: [],
    });

    expect(r).toEqual({ ok: false, error: 'Only the person who wrote this post can edit it.' });
    expect(store.get().posts[0]).toMatchObject({ title: 'Hi', body: ['Hello'], editedAt: null });
  });

  it('shows the change at once and keeps what the server answers', async () => {
    const { gateway: g, store } = await openPost();

    routes['PATCH /api/posts/p1'] = {
      status: 200,
      body: { ...post, title: 'New', body: 'Changed', edited_at: at },
    };

    const editing = g.posts.edit('p1', {
      title: ' New ',
      body: 'Changed',
      kind: 'Question',
      files: [],
    });

    expect(store.get().posts[0]?.title).toBe('New');
    expect((await editing).ok).toBe(true);

    expect(sent.at(-1)?.body).toEqual({
      title: 'New',
      body: 'Changed',
      kind_id: 'k1',
      attachment_ids: [],
    });

    expect(store.get().posts[0]).toMatchObject({ title: 'New', body: ['Changed'], editedAt: at });
  });
});

describe('posts.remove', () => {
  it('fails for someone else’s post without asking the server', async () => {
    const { gateway: g, store } = await openPost();

    store.set((state) => {
      state.me = 'u2';
    });

    const r = await g.posts.remove('p1');

    expect(r.ok).toBe(false);
    expect(sent.at(-1)?.method).toBe('GET');
  });

  it('puts the post back when the server refuses', async () => {
    const { gateway: g, store } = await openPost();

    routes['DELETE /api/posts/p1'] = { status: 500 };

    const r = await g.posts.remove('p1');

    expect(r.ok).toBe(false);
    expect(store.get().posts.map((p) => p.id)).toEqual(['p1']);
  });

  it('deletes the post', async () => {
    const { gateway: g, store } = await openPost();

    routes['DELETE /api/posts/p1'] = { status: 204 };

    expect((await g.posts.remove('p1')).ok).toBe(true);
    expect(store.get().posts).toEqual([]);
  });
});

describe('posts.toggleAnswer', () => {
  it('unmarks the answer again when the server refuses', async () => {
    const { gateway: g, store } = await openPost([reply('r1', 'Try this')]);

    routes['PUT /api/posts/p1/answer'] = { status: 403, body: { message: 'Forbidden' } };

    const r = await g.posts.toggleAnswer('p1', 'r1');

    expect(r).toEqual({
      ok: false,
      error: 'Only the person who asked or a moderator can mark the answer.',
    });

    expect(store.get().posts[0]?.answer).toBeNull();
  });

  it('marks the reply as the answer', async () => {
    const { gateway: g, store } = await openPost([reply('r1', 'Try this')]);

    routes['PUT /api/posts/p1/answer'] = { status: 200, body: { ...post, answer_reply_id: 'r1' } };

    expect((await g.posts.toggleAnswer('p1', 'r1')).ok).toBe(true);
    expect(sent.at(-1)?.body).toEqual({ reply_id: 'r1' });
    expect(store.get().posts[0]?.answer).toBe('r1');
    expect(store.get().posts[0]?.replies).toHaveLength(1);
  });

  it('unmarks the answer it already is', async () => {
    const { gateway: g } = await openPost([reply('r1', 'Try this')]);

    routes['PUT /api/posts/p1/answer'] = [
      { status: 200, body: { ...post, answer_reply_id: 'r1' } },
      { status: 200, body: post },
    ];

    await g.posts.toggleAnswer('p1', 'r1');

    await g.posts.toggleAnswer('p1', 'r1');

    expect(sent.at(-1)?.body).toEqual({ reply_id: null });
  });
});

describe('posts.toggleWatch', () => {
  it('stops watching again and says why when the server refuses', async () => {
    const { gateway: g, store } = await openPost([]);

    routes['PUT /api/posts/p1/watch'] = { status: 404, body: { message: 'Not found' } };

    const watching = g.posts.toggleWatch('p1');

    expect(store.get().posts[0]?.watching).toBe(true);
    expect(await watching).toEqual({ ok: false, error: 'Not found' });
    expect(store.get().posts[0]?.watching).toBe(false);
  });

  it('watches the post', async () => {
    const { gateway: g, store } = await openPost([]);

    routes['PUT /api/posts/p1/watch'] = { status: 200, body: { on: true } };

    expect((await g.posts.toggleWatch('p1')).ok).toBe(true);
    expect(sent.at(-1)?.body).toEqual({ watching: true });
    expect(store.get().posts[0]?.watching).toBe(true);
  });
});

describe('posts.toggleHelpful', () => {
  it('takes the mark back and says why when the server refuses', async () => {
    const { gateway: g, store } = await openPost([]);

    routes['POST /api/posts/p1/helpful'] = { status: 404, body: { message: 'Not found' } };

    const marking = g.posts.toggleHelpful('p1');

    expect(store.get().posts[0]?.helpfulMine).toBe(true);
    expect(await marking).toEqual({ ok: false, error: 'Not found' });
    expect(store.get().posts[0]?.helpfulMine).toBe(false);
  });
});

describe('posts.toggleBoost', () => {
  it('takes the boost back and says why when the server refuses', async () => {
    const { gateway: g, store } = await openPost([]);

    routes['POST /api/posts/p1/reactions'] = { status: 404, body: { message: 'Not found' } };

    const boosting = g.posts.toggleBoost('p1', '🎉');

    expect(store.get().posts[0]?.boosts).toEqual([{ e: '🎉', n: 1, mine: true }]);
    expect(await boosting).toEqual({ ok: false, error: 'Not found' });
    expect(store.get().posts[0]?.boosts).toEqual([]);
  });

  it('boosts the post', async () => {
    const { gateway: g, store } = await openPost([]);

    routes['POST /api/posts/p1/reactions'] = { status: 200, body: { on: true } };

    expect((await g.posts.toggleBoost('p1', '🎉')).ok).toBe(true);
    expect(sent.at(-1)?.body).toEqual({ emoji: '🎉' });
    expect(store.get().posts[0]?.boosts).toEqual([{ e: '🎉', n: 1, mine: true }]);
  });

  it("shows the post's boosts from the server", async () => {
    const { store } = await openPost([], {
      reactions: [{ emoji: '👍', count: 3, mine: false }],
    });

    expect(store.get().posts[0]?.boosts).toEqual([{ e: '👍', n: 3, mine: false }]);
  });
});

describe('posts.markAllSeen', () => {
  it('marks every post read here and on the server', async () => {
    const { gateway: g, store } = await openPost([]);

    routes['POST /api/posts/seen'] = { status: 204, body: undefined };

    expect((await g.posts.markAllSeen()).ok).toBe(true);
    expect(sent.at(-1)?.path).toBe('/api/posts/seen');
    expect(store.get().posts[0]?.seen).toBe(true);
  });

  it('puts the posts back unread when the server refuses', async () => {
    const { gateway: g, store } = await openPost([]);

    routes['POST /api/communities/c1/posts/seen'] = { status: 500, body: { message: 'Down' } };

    expect((await g.posts.markCommunitySeen('gardeners')).ok).toBe(false);
    expect(store.get().posts[0]?.seen).toBe(false);
  });
});

describe('posts.toggleLock', () => {
  it('locks the post here and on the server', async () => {
    const { gateway: g, store } = await openPost([]);

    routes['PUT /api/posts/p1/lock'] = { status: 200, body: { ...post, locked: true } };

    expect((await g.posts.toggleLock('p1')).ok).toBe(true);
    expect(sent.at(-1)?.body).toEqual({ locked: true });
    expect(store.get().posts[0]?.locked).toBe(true);
  });

  it('opens the post again when the server refuses', async () => {
    const { gateway: g, store } = await openPost([]);

    routes['PUT /api/posts/p1/lock'] = { status: 403, body: { message: 'Forbidden' } };

    expect(await g.posts.toggleLock('p1')).toEqual({ ok: false, error: 'Forbidden' });
    expect(store.get().posts[0]?.locked).toBe(false);
  });
});

describe('posts.reply', () => {
  it('takes the reply out and says why when the server refuses', async () => {
    const { gateway: g, store } = await openPost([]);

    routes['POST /api/posts/p1/replies'] = {
      status: 422,
      body: { message: 'Invalid', errors: { body: ["can't be blank"] } },
    };

    const replying = g.posts.reply('p1', { parent: null, body: 'Try this' });

    expect(store.get().posts[0]?.replies).toHaveLength(1);
    expect(await replying).toEqual({ ok: false, error: "body can't be blank" });
    expect(store.get().posts[0]?.replies).toEqual([]);
  });

  it('answers with the reply the server made', async () => {
    const { gateway: g, store } = await openPost([]);

    routes['POST /api/posts/p1/replies'] = { status: 201, body: reply('r9', 'Try this') };

    const r = await g.posts.reply('p1', { parent: null, body: 'Try this' });

    expect(r.ok && r.value.reply.id).toBe('r9');
    expect(store.get().posts[0]?.replies.map((x) => x.id)).toEqual(['r9']);
  });
});

describe('posts.editReply', () => {
  it('puts the reply back when the server refuses', async () => {
    const { gateway: g, store } = await openPost([reply('r1', 'Try this')]);

    routes['PATCH /api/replies/r1'] = { status: 403, body: { message: 'Forbidden' } };

    const r = await g.posts.editReply('p1', 'r1', { body: 'Try that', files: [] });

    expect(r).toEqual({ ok: false, error: 'Only the person who wrote this reply can edit it.' });
    expect(store.get().posts[0]?.replies[0]).toMatchObject({ body: ['Try this'], edited: false });
  });

  it('saves the new words', async () => {
    const { gateway: g, store } = await openPost([reply('r1', 'Try this')]);

    routes['PATCH /api/replies/r1'] = {
      status: 200,
      body: { ...reply('r1', 'Try that'), edited_at: at },
    };

    expect((await g.posts.editReply('p1', 'r1', { body: 'Try that\n', files: [] })).ok).toBe(true);
    expect(sent.at(-1)?.body).toEqual({ body: 'Try that', attachment_ids: [] });
    expect(store.get().posts[0]?.replies[0]).toMatchObject({ body: ['Try that'], edited: true });
  });
});

describe('posts.removeReply', () => {
  it('puts the reply back when the server refuses', async () => {
    const { gateway: g, store } = await openPost([reply('r1', 'Try this')]);

    routes['DELETE /api/replies/r1'] = { status: 500 };

    expect((await g.posts.removeReply('p1', 'r1')).ok).toBe(false);
    expect(store.get().posts[0]?.replies.map((r) => r.id)).toEqual(['r1']);
  });

  it('leaves a marker for a reply with replies under it', async () => {
    const { gateway: g, store } = await openPost([
      reply('r1', 'Try this'),
      reply('r2', 'Thanks', 'r1'),
    ]);

    routes['DELETE /api/replies/r1'] = { status: 204 };

    expect((await g.posts.removeReply('p1', 'r1')).ok).toBe(true);

    expect(store.get().posts[0]?.replies).toMatchObject([
      { id: 'r1', removed: true, body: [] },
      { id: 'r2' },
    ]);
  });

  it('deletes the reply', async () => {
    const { gateway: g, store } = await openPost([reply('r1', 'Try this')]);

    routes['DELETE /api/replies/r1'] = { status: 204 };

    expect((await g.posts.removeReply('p1', 'r1')).ok).toBe(true);
    expect(store.get().posts[0]?.replies).toEqual([]);
  });
});

describe('load.post', () => {
  it('names the kind of a post in a community first seen in a list', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };
    routes['GET /api/communities'] = { status: 200, body: [community] };
    routes['GET /api/events'] = { status: 200, body: [] };
    routes['GET /api/posts/p1'] = { status: 200, body: post };

    routes['GET /api/communities/c1'] = {
      status: 200,
      body: { community, kinds: [kind], membership: null },
    };

    routes['GET /api/posts/p1/replies'] = { status: 200, body: page([]) };

    const { gateway: g, store } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');
    // The events screen learns communities from the list, which carries no kinds
    await g.load.events(null);
    expect(store.get().communities['gardeners']?.kinds).toEqual([]);

    await g.load.post('p1');

    expect(store.get().posts.find((p) => p.id === 'p1')?.kind).toBe(kind.label);
  });
});

describe('load.post after signing in', () => {
  it('fetches the community again for the permissions of whoever signed in', async () => {
    routes['GET /api/posts/p1'] = { status: 200, body: post };

    routes['GET /api/communities/c1'] = {
      status: 200,
      body: { community, kinds: [kind], membership: null },
    };

    routes['GET /api/posts/p1/replies'] = { status: 200, body: page([]) };

    const { gateway: g, store } = gateway();

    await g.load.post('p1');
    expect(store.get().communities['gardeners']?.permissions).toEqual([]);

    routes['POST /api/auth/sessions'] = { status: 200, body: session };
    routes['GET /api/communities'] = { status: 200, body: [community] };

    routes['GET /api/communities/c1'] = {
      status: 200,
      body: {
        community,
        kinds: [kind],
        membership: { permissions: ['content.remove'], roles: [], joined_at: post.inserted_at },
      },
    };

    await g.session.verifyCode('ada@example.com', '123456');
    await g.load.post('p1');

    expect(store.get().communities['gardeners']?.permissions).toEqual(['content.remove']);
  });
});

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

const discussed = {
  id: 's1',
  room_id: 'v1',
  community_id: 'c1',
  host_id: 'u1',
  event_id: null,
  post_id: 'p1',
  mode: 'stage',
  topic: 'Hi',
  started_at: at,
  ended_at: null,
  recording: false,
};

const withVoice = { ...community, rooms: [...community.rooms, voiceRoom] };

const openWithVoice = async (live: unknown = null) => {
  routes['GET /api/posts/p1'] = { status: 200, body: { ...post, live } };

  routes['GET /api/communities/c1'] = {
    status: 200,
    body: { community: withVoice, kinds: [kind], membership: null },
  };

  routes['GET /api/posts/p1/replies'] = { status: 200, body: page([]) };

  const opened = gateway();

  await opened.gateway.load.post('p1');

  return opened;
};

const voiceRoomOf = (store: ReturnType<typeof gateway>['store']) =>
  store.get().communities['gardeners']?.voice.find((v) => v.id === 'office-hours');

describe('posts.startLive', () => {
  it('says why when every voice room is busy', async () => {
    const { gateway: g } = await openWithVoice();

    routes['POST /api/posts/p1/live'] = { status: 400, body: { code: 'rooms_busy' } };

    const r = await g.posts.startLive('p1');

    expect(r).toEqual({ ok: false, error: expect.stringContaining('busy') });
  });

  it('opens the room it started in, live on the post', async () => {
    const { gateway: g, store } = await openWithVoice();

    routes['POST /api/posts/p1/live'] = { status: 201, body: discussed };

    expect(await g.posts.startLive('p1')).toEqual({ ok: true, value: { room: 'office-hours' } });

    expect(voiceRoomOf(store)).toMatchObject({ live: true, postId: 'p1', host: 'u1' });
  });
});

describe('load.post with a live discussion', () => {
  it('shows the discussion on its room', async () => {
    const { store } = await openWithVoice({ session_id: 's1', room_id: 'v1', mode: 'open' });

    expect(voiceRoomOf(store)).toMatchObject({ live: true, postId: 'p1', mode: 'open' });
  });
});

describe('drafts', () => {
  const opened = async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [kind], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };

    const { store, gateway: g } = gateway();

    await g.load.community('gardeners');

    return { store, g };
  };

  it('loads my drafts after sign in', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };
    routes['GET /api/communities'] = { status: 200, body: [community] };

    routes['GET /api/drafts'] = {
      status: 200,
      body: [
        {
          community_id: 'c1',
          kind_id: kind.id,
          kind: 'Question',
          title: 'Tomatoes',
          body: null,
          updated_at: at,
        },
      ],
    };

    const { store, gateway: g } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    await vi.waitFor(() =>
      expect(store.get().drafts.gardeners).toMatchObject({
        title: 'Tomatoes',
        body: '',
        kind: 'Question',
      }),
    );
  });

  it('keeps a draft at once and saves it with its kind', async () => {
    const { store, g } = await opened();

    routes['PUT /api/communities/c1/draft'] = { status: 200, body: {} };

    g.posts.saveDraft('gardeners', { title: 'Tomatoes', body: 'Too much rain', kind: 'Question' });

    expect(store.get().drafts.gardeners).toMatchObject({ title: 'Tomatoes', kind: 'Question' });

    await vi.waitFor(() =>
      expect(sent.find((r) => r.method === 'PUT')?.body).toEqual({
        title: 'Tomatoes',
        body: 'Too much rain',
        kind_id: kind.id,
      }),
    );
  });

  it('throws a draft away here and on the server', async () => {
    const { store, g } = await opened();

    routes['DELETE /api/communities/c1/draft'] = { status: 204 };

    g.posts.saveDraft('gardeners', { title: 'Tomatoes', body: '', kind: 'Question' });
    g.posts.discardDraft('gardeners');

    expect(store.get().drafts.gardeners).toBeUndefined();
    await vi.waitFor(() => expect(sent.some((r) => r.method === 'DELETE')).toBe(true));
  });
});
