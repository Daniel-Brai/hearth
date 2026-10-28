import type { AppState } from '@/domain/app-state';
import { commsVisOf, myRolesIn, rolesOf } from '@/domain/selectors';
import type { Hue } from '@/domain/types';

export type ProfileCommunity = {
  cid: string;
  name: string;
  hue: Hue;
  letter: string;
  logo: string | null;
  members: number;
  role: string;
  roleHue: string;
  rank: number;
  shared: boolean;
};

const capitalize = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

/** Private communities you aren't in stay hidden so membership isn't revealed */
export function profileCommunities(state: AppState, id: string): ProfileCommunity[] {
  const mine = id === state.me;
  const out: ProfileCommunity[] = [];

  for (const [cid, c] of Object.entries(state.communities)) {
    const roles = rolesOf(state, cid);

    let held = mine
      ? myRolesIn(state, cid)
      : roles.filter((r) => r.members.includes(id)).map((r) => r.id);

    if (!mine && !held.length && c.maintainer === id) held = ['owner'];
    if (!held.length) continue;

    if (!mine && !c.joined && c.visibility === 'invite') continue;

    const vis = commsVisOf(state, id);

    if (!mine && (vis === 'nobody' || (vis === 'common' && !c.joined))) continue;

    const heldIds = new Set(held);
    const top = roles.find((r) => heldIds.has(r.id)) ?? null;
    const topId = top?.id ?? held[0] ?? 'member';

    out.push({
      cid,
      name: c.name,
      hue: c.hue,
      letter: c.letter,
      logo: c.logo,
      members: c.members,
      role: top?.name ?? capitalize(topId),
      roleHue: topId === 'member' ? 'ink' : (top?.hue ?? 'ink'),
      rank: top ? roles.indexOf(top) : -1,
      shared: !mine && c.joined,
    });
  }

  return out.sort(
    (a, b) =>
      Number(b.shared) - Number(a.shared) || a.rank - b.rank || a.name.localeCompare(b.name),
  );
}
