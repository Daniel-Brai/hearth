import type { AppState } from '../app-state';
import type { RoomAccess, RoomSettings } from '../types';
import { ROOM_DEFAULTS } from '@/domain/catalog';
import { canDo, isOwner, myRolesIn, roleName, roleRef, rolesOf } from './access';
import { community } from './communities';

export const findRoom = (state: AppState, name: string, cid: string | null | undefined) => {
  const c = community(state, cid);
  return c ? c.rooms.find((r) => r.name.toLowerCase() === String(name).toLowerCase()) : undefined;
};

export function roomAccess(
  state: AppState,
  cid: string | null | undefined,
  rid: string | null | undefined,
): RoomAccess {
  const c = community(state, cid);
  const room = c?.rooms.find((r) => r.id === rid) ?? c?.voice.find((v) => v.id === rid);

  return room?.access ?? 'everyone';
}

export const roomSettings = (state: AppState, key: string): RoomSettings =>
  state.roomSettings[key] || (ROOM_DEFAULTS as RoomSettings);

export function soundAccess(state: AppState, key: string) {
  if (key.startsWith('dm/')) return { ok: true as const };

  const s = roomSettings(state, key);
  const cid = key.split('/')[0]!;
  const room = '#' + (key.split('/')[1] || 'room');

  if (!s.sounds.enabled) return { ok: false as const, reason: 'Sounds are off in ' + room };
  if (isOwner(state, cid) || canDo(state, cid, 'room.update')) return { ok: true as const };
  if (s.sounds.mode === 'everyone') return { ok: true as const };

  if (s.sounds.mode === 'roles') {
    const allowed = new Set(s.sounds.roles);
    const mine = new Set(myRolesIn(state, cid));

    if (rolesOf(state, cid).some((r) => mine.has(r.id) && allowed.has(roleRef(r))))
      return { ok: true as const };

    const roles =
      s.sounds.roles.map((r) => `${roleName(state, cid, r)}s`).join(' and ') || 'picked roles';

    return { ok: false as const, reason: `Only ${roles} can play sounds here` };
  }

  if (state.me && s.sounds.people.includes(state.me)) return { ok: true as const };

  return { ok: false as const, reason: 'Only people an admin picked can play sounds here' };
}

export function liveRooms(state: AppState) {
  const out: {
    key: string;
    cid: string;
    id: string;
    name: string;
    topic: string | null;
    listeners: number;
    community: string;
    hue: string;
    letter: string;
    logo: string | null;
  }[] = [];
  Object.entries(state.communities).forEach(([cid, c]) => {
    if (!c.joined) return;
    c.voice.forEach((v) => {
      if (v.live && !(state.live.joined && state.live.key === cid + '/' + v.id))
        out.push({
          key: cid + '/' + v.id,
          cid,
          id: v.id,
          name: v.name,
          topic: v.topic,
          listeners: v.listeners,
          community: c.name,
          hue: c.hue,
          letter: c.letter,
          logo: c.logo,
        });
    });
  });
  return out;
}

export function liveRoom(state: AppState) {
  if (!state.live.key) return null;

  const [cid, rid] = state.live.key.split('/') as [string, string];
  const v = state.communities[cid]?.voice.find((x) => x.id === rid);

  return v ? { cid, room: v } : null;
}

/** Everyone in an open room may talk, whatever role they joined with */
export function mayTalk(state: AppState): boolean {
  const { role, key } = state.live;
  const [cid, rid] = key?.split('/') ?? [];
  const room = cid ? state.communities[cid]?.voice.find((v) => v.id === rid) : undefined;

  return role !== 'listener' || room?.mode === 'open';
}
