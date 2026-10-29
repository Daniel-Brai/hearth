import { describe, expect, it, vi } from 'vitest';
import { toKind, toPost } from '../mappers';
import { community, file, gateway, kind, page, post, routes, sent, session } from './test-support';

vi.mock('../realtime', () => ({ getRealtime: () => ({ onPush: () => () => undefined }) }));

describe('load.community', () => {
  it('fails for a community it can not see', async () => {
    const r = await gateway().gateway.load.community('secret');

    expect(r).toEqual({ ok: false, error: 'Not Found' });
  });

  it('reads no posts from an invite only community it is not part of', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community: { ...community, visibility: 'invite_only' }, kinds: [], membership: null },
    };

    const { store, gateway: g } = gateway();

    expect((await g.load.community('gardeners')).ok).toBe(true);

    expect(store.get().communities.gardeners).toMatchObject({ visibility: 'invite' });
    expect(sent.some((r) => r.path.includes('/posts'))).toBe(false);
  });

  it('keeps the community, its kinds and posts under its slug', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [kind], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([post]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };

    const { store, gateway: g } = gateway();

    expect((await g.load.community('gardeners')).ok).toBe(true);

    expect(store.get().communities.gardeners?.kinds.map((k) => k.name)).toEqual(['Question']);
    expect(store.get().posts[0]).toMatchObject({ id: 'p1', c: 'gardeners', kind: 'Question' });
  });
});

describe('load.home', () => {
  const signedIn = async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };
    routes['GET /api/communities'] = { status: 200, body: [community] };

    routes['GET /api/communities/c1'] = {
      status: 200,
      body: { community, kinds: [kind], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([post]) };

    const opened = gateway();

    await opened.gateway.session.verifyCode('ada@example.com', '123456');

    return opened;
  };

  it('lists the public communities to someone signed out', async () => {
    routes['GET /api/public/communities'] = { status: 200, body: [community] };

    const { store, gateway: g } = gateway();

    expect((await g.load.home()).ok).toBe(true);

    expect(store.get().communities.gardeners).toMatchObject({
      visibility: 'public',
      joined: false,
    });
  });

  it('shows each post with its kind, though the list of communities carries none', async () => {
    const { store, gateway: g } = await signedIn();

    expect((await g.load.home()).ok).toBe(true);

    expect(store.get().posts[0]).toMatchObject({ id: 'p1', kind: 'Question' });
  });

  it('keeps a kind the server render already showed when it can not learn the kinds', async () => {
    const { store, gateway: g } = await signedIn();

    // The page was rendered on the server so the store arrived knowing the post's kind
    store.set((state) => {
      state.posts = [toPost(post, 'gardeners', 'Question')];
    });

    routes['GET /api/communities/c1'] = { status: 500, body: { message: 'Down' } };

    await g.load.home();

    expect(store.get().posts[0]?.kind).toBe('Question');
  });
});

describe('communities.update', () => {
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

  const patch = {
    name: 'Growers',
    tagline: 'Dirt under the nails',
    intro: '',
    logo: null,
    banner: null,
    hue: 'aqua' as const,
    links: [{ label: 'Site', url: 'https://growers.example' }],
    kinds: [toKind(kind)],
    categories: ['games'],
    moderation: 'reports' as const,
    audience: 'indexed' as const,
  };

  it('fails for a community that is not loaded', async () => {
    expect(await gateway().gateway.communities.update('gardeners', patch)).toEqual({
      ok: false,
      error: 'That community is not loaded.',
    });
  });

  it('says why and puts the community back when the server refuses it', async () => {
    const { store, gateway: g } = await loaded();

    routes['PATCH /api/communities/c1'] = {
      status: 403,
      body: { message: "You can't do that.", code: 'forbidden' },
    };

    const saving = g.communities.update('gardeners', patch);

    expect(store.get().communities.gardeners?.name).toBe('Growers');

    expect(await saving).toEqual({ ok: false, error: "You can't do that." });
    expect(store.get().communities.gardeners?.name).toBe('Gardeners');
  });

  it('keeps the rest saved and says why when only the owner may change the level', async () => {
    const { store, gateway: g } = await loaded();

    routes['PATCH /api/communities/c1'] = { status: 200, body: { ...community, name: 'Growers' } };

    routes['PUT /api/communities/c1/moderation'] = {
      status: 403,
      body: { message: 'Forbidden', code: 'forbidden' },
    };

    expect(await g.communities.update('gardeners', patch)).toEqual({
      ok: false,
      error: "The rest is saved. Your role here can't change how much it is moderated.",
    });

    expect(store.get().communities.gardeners?.name).toBe('Growers');
  });

  it('sends the categories and keeps what the server saved', async () => {
    const { store, gateway: g } = await loaded();

    routes['PATCH /api/communities/c1'] = {
      status: 200,
      body: {
        ...community,
        name: 'Growers',
        hue: 'aqua',
        tagline: 'Dirt under the nails',
        categories: ['games'],
      },
    };

    routes['PUT /api/communities/c1/moderation'] = {
      status: 200,
      body: { level: 'reports', effective: 'reports' },
    };

    expect((await g.communities.update('gardeners', patch)).ok).toBe(true);

    expect(sent.find((r) => r.method === 'PATCH')?.body).toEqual({
      name: 'Growers',
      tagline: 'Dirt under the nails',
      description: null,
      hue: 'aqua',
      links: [{ label: 'Site', url: 'https://growers.example' }],
      categories: ['games'],
      visibility: 'public_indexed',
    });

    expect(sent.find((r) => r.method === 'PUT')?.body).toEqual({ level: 'reports' });
    expect(store.get().communities.gardeners?.moderation).toBe('reports');

    expect(store.get().communities.gardeners).toMatchObject({
      name: 'Growers',
      categories: ['games'],
      kinds: [expect.objectContaining({ name: 'Question' })],
    });
  });

  it('uploads a new logo and banner and sends them', async () => {
    const { gateway: g } = await loaded();
    const picked = 'data:image/png;base64,iVBORw0KGgo=';

    routes['POST /api/uploads'] = {
      status: 201,
      body: { media: file, upload: { url: 'https://storage.test/put', headers: {} } },
    };

    routes['PUT /put'] = { status: 200 };
    routes['POST /api/uploads/' + file.id + '/complete'] = { status: 200, body: file };
    routes['PATCH /api/communities/c1'] = { status: 200, body: community };
    routes['PUT /api/communities/c1/moderation'] = { status: 200, body: { level: 'reports' } };

    await g.communities.update('gardeners', { ...patch, logo: picked, banner: picked });

    expect(sent.find((r) => r.method === 'PATCH')?.body).toMatchObject({
      logo_id: file.id,
      banner_id: file.id,
    });
  });

  it('sends no logo once it is removed', async () => {
    const { store, gateway: g } = await loaded();

    store.set((state) => void (state.communities.gardeners!.logo = 'https://storage.test/l.webp'));
    routes['PATCH /api/communities/c1'] = { status: 200, body: community };
    routes['PUT /api/communities/c1/moderation'] = { status: 200, body: { level: 'reports' } };

    await g.communities.update('gardeners', patch);

    expect(sent.find((r) => r.method === 'PATCH')?.body).toMatchObject({ logo_id: null });
  });

  it('keeps the rest saved and says why Discussion stays', async () => {
    const { gateway: g } = await loaded();

    routes['PATCH /api/communities/c1'] = { status: 200, body: community };

    routes['PUT /api/communities/c1/kinds'] = {
      status: 400,
      body: { message: 'Keeps discussion.', code: 'keeps_discussion' },
    };

    const added = {
      name: 'Trip report',
      icon: 'map',
      hue: 'green' as const,
      hint: '',
      body: '',
      answers: false,
      mods: false,
      desc: null,
    };

    expect(await g.communities.update('gardeners', { ...patch, kinds: [added] })).toEqual({
      ok: false,
      error:
        'The rest is saved. Discussion has to stay, since posts from removed kinds move there.',
    });
  });

  it('saves added kinds and shows the list the server kept', async () => {
    const { store, gateway: g } = await loaded();

    routes['PATCH /api/communities/c1'] = { status: 200, body: community };

    routes['PUT /api/communities/c1/kinds'] = {
      status: 200,
      body: [kind, { ...kind, id: 'k2', key: 'trip-report', label: 'Trip report' }],
    };

    routes['PUT /api/communities/c1/moderation'] = {
      status: 200,
      body: { level: 'reports', effective: 'reports' },
    };

    const added = {
      name: 'Trip report',
      icon: 'map',
      hue: 'green' as const,
      hint: '',
      body: '',
      answers: false,
      mods: false,
      desc: null,
    };

    expect(
      (await g.communities.update('gardeners', { ...patch, kinds: [toKind(kind), added] })).ok,
    ).toBe(true);

    expect(sent.find((r) => r.path.endsWith('/kinds'))?.body).toMatchObject({
      kinds: [{ key: 'question' }, { key: null, label: 'Trip report' }],
    });

    expect(store.get().communities.gardeners?.kinds.map((k) => k.name)).toEqual([
      'Question',
      'Trip report',
    ]);
  });
});

const request = {
  id: 'rq1',
  name: 'Beekeepers',
  tagline: null,
  hue: 'yellow',
  visibility: 'public',
  template: 'club',
  note: 'For the hives on Allen Avenue',
  status: 'pending',
  requester: {
    id: 'u2',
    username: 'bola',
    display_name: 'Bola',
    avatar_id: null,
    avatar_url: null,
  },
  community_id: null,
  community_slug: null,
  decided_at: null,
  inserted_at: new Date().toISOString(),
};

describe('load.requests', () => {
  it('fails when the server refuses', async () => {
    routes['GET /api/community-requests'] = { status: 403, body: { message: 'Forbidden' } };

    expect(await gateway().gateway.load.requests()).toEqual({ ok: false, error: 'Forbidden' });
  });

  it('keeps waiting and decided requests with who asked', async () => {
    const declined = { ...request, id: 'rq2', status: 'declined', decided_at: request.inserted_at };

    routes['GET /api/community-requests'] = [
      { status: 200, body: [request] },
      { status: 200, body: [] },
      { status: 200, body: [declined] },
    ];

    const { store, gateway: g } = gateway();

    expect((await g.load.requests()).ok).toBe(true);

    expect(store.get().communityRequests).toEqual([
      expect.objectContaining({ id: 'rq1', by: 'u2', status: 'pending', age: 'now' }),
      expect.objectContaining({ id: 'rq2', status: 'declined', decided: 'now' }),
    ]);

    expect(store.get().people.u2).toMatchObject({ username: 'bola' });
  });
});

describe('communities.decideRequest', () => {
  it('fails when the server refuses', async () => {
    routes['POST /api/community-requests/rq1/decision'] = {
      status: 400,
      body: { code: 'already_decided', message: 'Already decided.' },
    };

    expect(await gateway().gateway.communities.decideRequest('rq1', 'approved')).toEqual({
      ok: false,
      error: 'Already decided.',
    });
  });

  it('marks it approved and leads to the new community', async () => {
    routes['GET /api/community-requests'] = [
      { status: 200, body: [request] },
      { status: 200, body: [] },
      { status: 200, body: [] },
    ];

    routes['POST /api/community-requests/rq1/decision'] = {
      status: 200,
      body: { ...request, status: 'approved', community_id: 'c9', community_slug: 'beekeepers' },
    };

    const { store, gateway: g } = gateway();

    await g.load.requests();

    expect(await g.communities.decideRequest('rq1', 'approved')).toEqual({
      ok: true,
      value: { community: 'beekeepers' },
    });

    expect(sent.at(-1)?.body).toEqual({ decision: 'approved' });

    expect(store.get().communityRequests[0]).toMatchObject({
      status: 'approved',
      communityId: 'beekeepers',
    });
  });
});

describe('communities.requestTransferCode', () => {
  it('fails when the server refuses', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [kind], membership: null },
    };

    routes['POST /api/communities/c1/owner/code'] = { status: 403, body: { message: 'Forbidden' } };

    const { gateway: g } = gateway();

    await g.load.community('gardeners');

    expect(await g.communities.requestTransferCode('gardeners')).toEqual({
      ok: false,
      error: 'Forbidden',
    });
  });

  it('asks the server to email the code', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [kind], membership: null },
    };

    routes['POST /api/communities/c1/owner/code'] = { status: 204 };

    const { gateway: g } = gateway();

    await g.load.community('gardeners');

    expect((await g.communities.requestTransferCode('gardeners')).ok).toBe(true);
  });
});

describe('communities.transferOwnership', () => {
  it('fails for a community that is not loaded', async () => {
    expect(
      await gateway().gateway.communities.transferOwnership('gardeners', 'u2', '042917'),
    ).toEqual({
      ok: false,
      error: 'That community is not loaded.',
    });
  });

  it('hands it over and reloads the community', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community, kinds: [kind], membership: null },
    };

    routes['PUT /api/communities/c1/owner'] = {
      status: 200,
      body: { ...community, owner_id: 'u2' },
    };

    const { gateway: g } = gateway();

    await g.load.community('gardeners');

    expect((await g.communities.transferOwnership('gardeners', 'u2', '042917')).ok).toBe(true);

    expect(sent.find((r) => r.method === 'PUT')?.body).toEqual({ user_id: 'u2', code: '042917' });
    const reads = sent.filter((r) => r.path === '/api/communities/gardeners');

    expect(reads).toHaveLength(2);
  });
});

describe('communities.create', () => {
  const spec = {
    name: 'Beekeepers',
    tagline: 'Hives on Allen Avenue',
    description: ' How we keep bees in the city. ',
    hue: 'yellow' as const,
    audience: 'indexed' as const,
    logo: null,
    template: 'club',
  };

  it('says why the server refuses', async () => {
    routes['POST /api/communities'] = { status: 403, body: { message: 'Forbidden' } };

    expect(await gateway().gateway.communities.create(spec)).toEqual({
      ok: false,
      error: 'Forbidden',
    });
  });

  it('sends the description and asks to be indexed as the form says', async () => {
    routes['POST /api/communities'] = { status: 202, body: request };

    expect(await gateway().gateway.communities.create(spec)).toEqual({
      ok: true,
      value: { requested: true },
    });

    expect(sent.find((r) => r.path === '/api/communities')?.body).toMatchObject({
      tagline: 'Hives on Allen Avenue',
      description: 'How we keep bees in the city.',
      visibility: 'public_indexed',
    });
  });
});

describe('communities.slugFor', () => {
  it('gives nothing when the server can not answer', async () => {
    routes['GET /api/community-slugs'] = { status: 500, body: { message: 'Down' } };

    expect(await gateway().gateway.communities.slugFor('Beekeepers')).toBeNull();
  });

  it('gives the address the server would use', async () => {
    routes['GET /api/community-slugs'] = { status: 200, body: { slug: 'beekeepers-2' } };

    expect(await gateway().gateway.communities.slugFor('Beekeepers')).toBe('beekeepers-2');
  });
});

describe('audience', () => {
  it('keeps the exact visibility the server sends', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community: { ...community, visibility: 'private' }, kinds: [], membership: null },
    };

    const { store, gateway: g } = gateway();

    await g.load.community('gardeners');

    expect(store.get().communities.gardeners).toMatchObject({
      visibility: 'invite',
      audience: 'private',
    });
  });
});
