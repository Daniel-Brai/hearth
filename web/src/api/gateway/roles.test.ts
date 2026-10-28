import { describe, expect, it, vi } from 'vitest';
import { community, gateway, kind, page, post, routes, sent } from './test-support';

vi.mock('../realtime', () => ({ getRealtime: () => ({ onPush: () => () => undefined }) }));

const role = (key: string, permissions: string[] = []) => ({
  id: `role-${key}`,
  key,
  name: key[0]!.toUpperCase() + key.slice(1),
  color: null,
  position: 0,
  is_default: key === 'member',
  is_system: key === 'owner',
  permissions,
});

const grace = { ...post.author, id: 'u2', username: 'grace', display_name: 'Grace' };

const loaded = async () => {
  routes['GET /api/communities/gardeners'] = {
    status: 200,
    body: { community, kinds: [kind], membership: null },
  };

  routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
  routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };

  routes['GET /api/communities/c1/roles'] = {
    status: 200,
    body: [role('owner'), role('helper', ['post.pin']), role('member')],
  };

  routes['GET /api/communities/c1/members'] = {
    status: 200,
    body: [{ user: grace, role_keys: ['helper'] }],
  };

  const g = gateway();

  await g.gateway.load.roles('gardeners');

  return g;
};

describe('roles', () => {
  it('says why a role could not be made', async () => {
    const { gateway: g } = await loaded();
    routes['POST /api/communities/c1/roles'] = {
      status: 422,
      body: { errors: { key: ['has already been taken'] } },
    };

    expect(await g.roles.create('gardeners', 'Helper')).toEqual({
      ok: false,
      error: 'key has already been taken',
    });
  });

  it('loads the roles with who holds each one', async () => {
    const { store } = await loaded();

    expect(store.get().roles.find((r) => r.id === 'helper')?.members).toEqual(['u2']);
    expect(store.get().people.u2?.username).toBe('grace');
  });

  it('makes a role keyed by its name', async () => {
    const { gateway: g } = await loaded();

    routes['POST /api/communities/c1/roles'] = { status: 201, body: role('night-owls') };

    expect(await g.roles.create('gardeners', 'Night Owls')).toEqual({
      ok: true,
      value: { id: 'night-owls' },
    });

    expect(sent.find((s) => s.method === 'POST')?.body).toEqual({
      key: 'night-owls',
      name: 'Night Owls',
      permissions: [],
    });
  });

  it('sends the whole list of permissions when one changes', async () => {
    const { gateway: g } = await loaded();

    routes['PATCH /api/roles/role-helper'] = {
      status: 200,
      body: role('helper', ['post.pin', 'post.answer']),
    };

    expect((await g.roles.setPermission('gardeners', 'helper', 'post.answer', true)).ok).toBe(true);

    expect(sent.find((s) => s.method === 'PATCH')?.body).toEqual({
      permissions: ['post.pin', 'post.answer'],
    });
  });

  it('keeps the other roles a member holds when giving them one', async () => {
    const { store, gateway: g } = await loaded();

    routes['PUT /api/communities/c1/members/u2/roles'] = {
      status: 200,
      body: { user_id: 'u2', keys: ['helper', 'member'] },
    };

    expect((await g.roles.addMember('gardeners', 'member', 'u2')).ok).toBe(true);
    expect(sent.find((s) => s.method === 'PUT')?.body).toEqual({ keys: ['helper', 'member'] });
    expect(store.get().roles.find((r) => r.id === 'member')?.members).toEqual(['u2']);
  });

  it('takes a role away from a member', async () => {
    const { store, gateway: g } = await loaded();

    routes['PUT /api/communities/c1/members/u2/roles'] = {
      status: 200,
      body: { user_id: 'u2', keys: [] },
    };

    expect((await g.roles.removeMember('gardeners', 'helper', 'u2')).ok).toBe(true);
    expect(sent.find((s) => s.method === 'PUT')?.body).toEqual({ keys: [] });
    expect(store.get().roles.find((r) => r.id === 'helper')?.members).toEqual([]);
  });

  it('deletes a role', async () => {
    const { store, gateway: g } = await loaded();

    routes['DELETE /api/roles/role-helper'] = { status: 204 };

    routes['GET /api/communities/c1/roles'] = {
      status: 200,
      body: [role('owner'), role('member')],
    };

    expect((await g.roles.remove('gardeners', 'helper')).ok).toBe(true);
    expect(store.get().roles.map((r) => r.id)).toEqual(['owner', 'member']);
  });
});
