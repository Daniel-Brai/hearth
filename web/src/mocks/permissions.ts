import type { AppState } from '@/domain/app-state';
import { PERMISSIONS, type Permission } from '@/domain/permissions';
import { isOwner, myRolesIn, rolesOf } from '@/domain/selectors';

function permissionsIn(state: AppState, cid: string): Permission[] {
  if (!state.me || !state.communities[cid]?.joined) return [];
  if (isOwner(state, cid)) return [...PERMISSIONS];

  const mine = new Set(myRolesIn(state, cid));
  const granted = new Set<Permission>();

  for (const role of rolesOf(state, cid)) {
    if (!mine.has(role.id)) continue;
    for (const perm of role.locked ? PERMISSIONS : role.permissions) granted.add(perm);
  }

  return PERMISSIONS.filter((p) => granted.has(p));
}

export function grantPermissions(state: AppState) {
  for (const [cid, community] of Object.entries(state.communities)) {
    const next = permissionsIn(state, cid);
    const same =
      community.permissions?.length === next.length &&
      next.every((p, i) => community.permissions[i] === p);

    if (!same) community.permissions = next;
  }
}
