import { describe, expect, it } from 'vitest';
import {
  at,
  community,
  gateway,
  kind,
  page,
  post,
  reply,
  routes,
  sent,
  session,
} from './test-support';

const profile = {
  id: 'u2',
  username: 'bo',
  display_name: 'Bo',
  avatar_id: null,
  avatar_url: null,
  bio: 'Grows tomatoes',
  pronouns: null,
  location: null,
  links: [],
  joined_at: at,
  counts: { posts: 3, answers: 1, people_helped: 2 },
};

const detail = { status: 200, body: { community, kinds: [kind], membership: null } };

describe('people', () => {
  it('loads a profile by username', async () => {
    routes['GET /api/users/bo'] = { status: 200, body: profile };

    const { gateway: g, store } = gateway();

    expect(await g.load.profile('bo')).toEqual({ ok: true, value: undefined });

    expect(store.get().people['u2']).toMatchObject({
      username: 'bo',
      bio: 'Grows tomatoes',
      posts: 3,
      answers: 1,
      helped: 2,
    });
  });

  it('leaves a name with no account out, for the screen to show as not found', async () => {
    routes['GET /api/users/nobody'] = { status: 404, body: { message: 'Not Found' } };

    const { gateway: g, store } = gateway();

    expect(await g.load.profile('nobody')).toEqual({ ok: true, value: undefined });
    expect(Object.values(store.get().people).some((p) => p.username === 'nobody')).toBe(false);
  });

  it('loads nothing for a person it does not know', async () => {
    const { gateway: g } = gateway();

    expect(await g.load.activity('nobody', 'posts')).toEqual({ ok: true, value: undefined });
    expect(sent).toHaveLength(0);
  });

  it('lists the posts a profile shows, a page at a time', async () => {
    routes['GET /api/users/bo'] = { status: 200, body: profile };
    routes['GET /api/communities/c1'] = detail;

    routes['GET /api/users/bo/posts'] = [
      {
        status: 200,
        body: {
          ...page([{ ...post, id: 'p2' }]),
          meta: { ...page([]).meta, after: 'a1', has_next: true },
        },
      },
      { status: 200, body: page([post]) },
    ];

    const { gateway: g, store } = gateway();

    await g.load.profile('bo');

    await g.load.activity('bo', 'posts');
    expect(store.get().activity['u2']).toMatchObject({ posts: ['p2'], postsAfter: 'a1' });
    expect(store.get().posts.find((p) => p.id === 'p2')).toMatchObject({ c: 'gardeners' });

    await g.load.activity('bo', 'posts', true);
    expect(store.get().activity['u2']).toMatchObject({ posts: ['p2', 'p1'], postsAfter: null });
  });

  it('lists replies with the post each answers', async () => {
    routes['GET /api/users/bo'] = { status: 200, body: profile };
    routes['GET /api/communities/c1'] = detail;

    routes['GET /api/users/bo/replies'] = {
      status: 200,
      body: page([
        {
          reply: reply('r1', 'Try mulch'),
          post: { id: 'p1', title: 'Hi', community_id: 'c1' },
          answer: true,
        },
      ]),
    };

    const { gateway: g, store } = gateway();

    await g.load.profile('bo');

    await g.load.activity('bo', 'replies');

    expect(store.get().activity['u2']?.replies).toEqual([
      {
        id: 'r1',
        postId: 'p1',
        c: 'gardeners',
        title: 'Hi',
        excerpt: 'Try mulch',
        helpful: 0,
        age: 'now',
        answer: true,
      },
    ]);
  });

  it('looks up the people a post mentions, once', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };
    routes['GET /api/communities'] = { status: 200, body: [community] };

    routes['GET /api/communities/c1/posts'] = {
      status: 200,
      body: page([{ ...post, body: 'Thanks @bo and @ada' }]),
    };

    routes['GET /api/users'] = {
      status: 200,
      body: [{ id: 'u2', username: 'bo', display_name: 'Bo', avatar_id: null, avatar_url: null }],
    };

    const { gateway: g, store } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    await g.load.home();
    await new Promise((resolve) => setTimeout(resolve, 0));

    const lookups = sent.filter((r) => r.path === '/api/users');

    expect(lookups).toHaveLength(1);
    expect(store.get().people['u2']?.username).toBe('bo');
  });
});

describe('load.people', () => {
  const person = (id: string, more: object) => ({
    id,
    username: id,
    display_name: null,
    avatar_id: null,
    avatar_url: null,
    online: false,
    last_seen_at: null,
    community_ids: ['c1'],
    ...more,
  });

  it('fails when the server refuses', async () => {
    routes['GET /api/people'] = { status: 401, body: { message: 'Unauthorized' } };

    expect(await gateway().gateway.load.people()).toEqual({ ok: false, error: 'Unauthorized' });
  });

  it('keeps who is online, when the rest were last seen and the communities shared', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };

    routes['GET /api/people'] = {
      status: 200,
      body: [
        person('bola', { online: true }),
        person('chidi', { last_seen_at: new Date(Date.now() - 2 * 3_600_000).toISOString() }),
        person('dayo', {}),
      ],
    };

    const { store, gateway: g } = gateway();

    await g.load.community('gardeners');
    await g.load.people();

    expect(store.get().people.bola?.lastSeen).toBe('online');
    expect(store.get().people.chidi?.lastSeen).toBe('2h');
    expect(store.get().people.dayo?.lastSeen).toBeUndefined();
    expect(store.get().sharedCommunities.bola).toEqual(['gardeners']);
  });
});
