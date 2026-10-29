import type { HearthGateway, Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import type { Hue, Permission, Role } from '@/domain/types';
import {
  communityMemberIndex,
  communityRoleCreate,
  communityRoleDelete,
  communityRoleIndex,
  communityRoleMemberRoles,
  communityRoleUpdate,
} from '@/generated/api/communities/communities';
import type { Role as ApiRole } from '@/generated/schemas';
import { slugify } from '@/runtime/routes';
import type { GatewayContext } from './context';
import { NOT_READY, call, failed } from './context';
import { toPerson } from '../mappers';

const OWNER = 'owner';

const MEMBERS_SHOWN = 20;

const HUES: Record<string, Hue> = { owner: 'orange', moderator: 'blue', member: 'ink' };

const toRole = (role: ApiRole, cid: string): Role => ({
  c: cid,
  id: role.key,
  uid: role.id,
  name: role.name,
  hue: HUES[role.key] ?? 'violet',
  members: [],
  locked: role.key === OWNER,
  permissions: role.permissions as Permission[],
});

export function createRolesGateway(
  ctx: GatewayContext,
  loadCommunity: (cid: string) => Promise<Result>,
) {
  const roleIds = new Map<string, string>();

  const communityId = async (cid: string) => {
    if (!ctx.communityIds.has(cid)) await loadCommunity(cid);
    return ctx.communityIds.get(cid) ?? null;
  };

  const list = async (cid: string): Promise<Result> => {
    const id = await communityId(cid);

    if (!id) return fail("This community isn't here.");

    const answer = await call(() => communityRoleIndex(id));

    if (answer.status !== 200) return failed(answer);

    for (const role of answer.data) roleIds.set(`${cid}/${role.key}`, role.id);

    ctx.store.set((state) => {
      const before = state.roles.filter((r) => r.c === cid);

      state.roles = [
        ...state.roles.filter((r) => r.c !== cid),
        ...answer.data.map((r) => ({
          ...toRole(r, cid),
          members: before.find((b) => b.id === r.key)?.members ?? [],
        })),
      ];
    });

    return ok(undefined);
  };

  const memberKeys = async (id: string, q?: string) => {
    const answer = await call(() =>
      communityMemberIndex(id, q ? { q, limit: MEMBERS_SHOWN } : { limit: MEMBERS_SHOWN }),
    );

    if (answer.status !== 200) return null;

    ctx.store.set((state) => {
      for (const { user } of answer.data) state.people[user.id] ??= toPerson(user);
    });

    return new Map(answer.data.map((m) => [m.user.id, m.role_keys]));
  };

  const showMembers = (cid: string, keys: ReadonlyMap<string, readonly string[]>) =>
    ctx.store.set((state) => {
      for (const role of state.roles) {
        if (role.c !== cid) continue;

        const others = role.members.filter((m) => !keys.has(m));
        const holders = [...keys].filter(([, held]) => held.includes(role.id)).map(([m]) => m);

        role.members = [...others, ...holders];
      }
    });

  const roles = async (cid: string): Promise<Result> => {
    const listed = await list(cid);

    if (!listed.ok) return listed;

    const id = ctx.communityIds.get(cid);
    const keys = id ? await memberKeys(id) : null;

    if (keys) showMembers(cid, keys);

    return ok(undefined);
  };

  // Your own permissions may change with a role
  const changed = async (
    cid: string,
    answer: { status: number; data: unknown },
    expected: number,
  ) => {
    if (answer.status !== expected) return failed(answer);

    await Promise.all([list(cid), loadCommunity(cid)]);
    return ok(undefined);
  };

  const setMember = async (cid: string, key: string, who: string, on: boolean): Promise<Result> => {
    const id = ctx.communityIds.get(cid);

    if (!id) return fail(NOT_READY);

    const person = ctx.store.get().people[who];
    const found = await memberKeys(id, person?.username);

    const held =
      found?.get(who) ??
      ctx.store
        .get()
        .roles.filter((r) => r.c === cid && r.members.includes(who))
        .map((r) => r.id);

    const keys = on ? [...new Set([...held, key])] : held.filter((k) => k !== key);

    const answer = await call(() =>
      communityRoleMemberRoles(id, who, { keys: keys.filter((k) => k !== OWNER) }),
    );

    if (answer.status !== 200) return failed(answer);

    showMembers(cid, new Map([[who, answer.data.keys]]));

    return ok(undefined);
  };

  const roleActions = {
    create: async (cid: string, name: string): Promise<Result<{ id: string }>> => {
      const id = ctx.communityIds.get(cid);

      if (!id) return fail(NOT_READY);

      const key = slugify(name).slice(0, 30);

      if (!key) return fail('Give the role a name');

      const answer = await call(() =>
        communityRoleCreate(id, { key, name: name.trim(), permissions: [] }),
      );

      if (answer.status !== 201) return failed(answer);

      await list(cid);

      return ok({ id: answer.data.key });
    },

    remove: async (cid: string, key: string): Promise<Result> => {
      const id = roleIds.get(`${cid}/${key}`);
      if (!id) return fail(NOT_READY);

      return changed(cid, await call(() => communityRoleDelete(id)), 204);
    },

    setPermission: async (
      cid: string,
      key: string,
      perm: Permission,
      on: boolean,
    ): Promise<Result> => {
      const id = roleIds.get(`${cid}/${key}`);
      const role = ctx.store.get().roles.find((r) => r.c === cid && r.id === key);

      if (!id || !role) return fail(NOT_READY);

      const permissions = on
        ? [...new Set([...role.permissions, perm])]
        : role.permissions.filter((p) => p !== perm);

      return changed(cid, await call(() => communityRoleUpdate(id, { permissions })), 200);
    },

    addMember: (cid: string, key: string, who: string) => setMember(cid, key, who, true),
    removeMember: (cid: string, key: string, who: string) => setMember(cid, key, who, false),
  } satisfies HearthGateway['roles'];

  return {
    load: { roles } satisfies Partial<HearthGateway['load']>,
    list,
    roles: roleActions,
  };
}
