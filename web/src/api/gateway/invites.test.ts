import { describe, expect, it } from 'vitest';
import { at, community, gateway, routes, sent, session } from './test-support';

const detail = { community, kinds: [], membership: null };

const invite = {
  id: 'i1',
  code: 'abc',
  role_key: 'member',
  max_uses: 50,
  uses_count: 2,
  expires_at: new Date(Date.parse(at) + 7 * 24 * 60 * 60 * 1000).toISOString(),
  revoked_at: null,
  created_by_id: 'u1',
  inserted_at: at,
};

const signedIn = async () => {
  routes['POST /api/auth/sessions'] = { status: 200, body: session };
  routes['GET /api/communities/gardeners'] = { status: 200, body: detail };
  routes['GET /api/communities/c1/posts'] = { status: 200, body: { data: [], meta: {} } };
  routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };

  routes['GET /api/communities/c1/roles'] = {
    status: 200,
    body: [
      {
        id: 'role1',
        key: 'member',
        name: 'Member',
        color: null,
        position: 2,
        is_default: true,
        is_system: true,
        permissions: [],
      },
    ],
  };

  const { gateway: g, store } = gateway();

  await g.session.verifyCode('ada@example.com', '123456');

  return { g, store };
};

describe('invites', () => {
  it('reads back the choices a link was made with, and the roles to pick from', async () => {
    routes['GET /api/communities/c1/invites'] = {
      status: 200,
      body: {
        links: [invite],
        emails: [
          {
            id: 'e1',
            email: 'bo@example.com',
            role_key: 'member',
            status: 'accepted',
            inserted_at: at,
          },
        ],
      },
    };

    const { g } = await signedIn();

    expect(await g.load.invites('gardeners')).toEqual({ ok: true, value: undefined });

    expect(g.invites.current('gardeners')).toMatchObject({
      code: 'abc',
      expires: '7d',
      max: '50',
      uses: 2,
    });
  });

  it('makes a new link and stops the old one', async () => {
    routes['GET /api/communities/c1/invites'] = {
      status: 200,
      body: { links: [invite], emails: [] },
    };

    routes['POST /api/communities/c1/invites'] = {
      status: 201,
      body: { ...invite, code: 'new', max_uses: null },
    };

    routes['DELETE /api/invites/abc'] = { status: 200, body: invite };

    const { g } = await signedIn();

    await g.load.invites('gardeners');

    await g.invites.newLink('gardeners', { expires: 'never', max: 'none', role: 'member' });

    expect(sent.find((r) => r.method === 'POST' && r.path.endsWith('/invites'))?.body).toEqual({
      role_key: 'member',
      max_uses: null,
      expires_at: null,
    });

    expect(sent.some((r) => r.method === 'DELETE' && r.path === '/api/invites/abc')).toBe(true);
    expect(g.invites.current('gardeners')).toMatchObject({ code: 'new', max: 'none' });
  });

  it('joins through an invite loaded first', async () => {
    routes['GET /api/invites/abc'] = {
      status: 200,
      body: {
        code: 'abc',
        usable: true,
        role_key: 'member',
        inviter: {
          id: 'u2',
          username: 'bo',
          display_name: 'Bo',
          avatar_id: null,
          avatar_url: null,
        },
        community: {
          id: 'c1',
          slug: 'gardeners',
          name: 'Gardeners',
          tagline: null,
          hue: 'green',
          logo_id: null,
        },
      },
    };

    routes['POST /api/invites/abc/accept'] = {
      status: 201,
      body: { joined_at: at, permissions: [], roles: [] },
    };

    const { g, store } = await signedIn();

    await g.load.invite('abc');
    expect(store.get().communities['gardeners']?.joined).toBe(false);

    expect(await g.session.acceptInvite('abc')).toEqual({
      ok: true,
      value: { community: 'gardeners' },
    });
  });
});
