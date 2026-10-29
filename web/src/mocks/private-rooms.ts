import { current, isDraft, type Draft } from 'immer';
import type { AppState } from '@/domain/app-state';
import { canDo, isOwner, myRolesIn } from '@/domain/selectors';
import type { Room, VoiceRoom } from '@/domain/types';

// Private rooms someone can't see wait here, as the server leaves them out of its answers
export type Offstage = Map<string, { rooms: Room[]; voice: VoiceRoom[] }>;

function canSeeRoom(state: AppState, cid: string, room: Room | VoiceRoom) {
  if (room.access !== 'roles') return true;
  if (isOwner(state, cid) || canDo(state, cid, 'room.update')) return true;

  const mine = new Set(myRolesIn(state, cid));

  return (room.roleIds ?? []).some((id) => mine.has(id));
}

const plain = <T extends object>(value: T): T =>
  isDraft(value) ? (current(value as Draft<T>) as T) : value;

function split<T extends Room | VoiceRoom>(
  listed: T[],
  waiting: T[],
  visible: (room: T) => boolean,
) {
  const leaving = listed.filter((r) => !visible(r));
  const coming = waiting.filter(visible);

  if (!leaving.length && !coming.length) return null;

  return {
    listed: [...listed.filter(visible), ...coming],
    waiting: [...waiting.filter((r) => !visible(r)), ...leaving.map(plain)],
  };
}

export function showVisibleRooms(state: AppState, offstage: Offstage) {
  for (const [cid, community] of Object.entries(state.communities)) {
    const held = offstage.get(cid) ?? { rooms: [], voice: [] };
    const visible = (room: Room | VoiceRoom) => canSeeRoom(state, cid, room);
    const text = split(community.rooms, held.rooms, visible);
    const voice = split(community.voice, held.voice, visible);

    if (text) community.rooms = text.listed;
    if (voice) community.voice = voice.listed;
    if (text || voice)
      offstage.set(cid, {
        rooms: text?.waiting ?? held.rooms,
        voice: voice?.waiting ?? held.voice,
      });
  }
}
