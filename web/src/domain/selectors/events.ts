import type { AppState } from '../app-state';
import { evNext, evState } from '../events';
import type { CommunityEvent } from '../types';
import { canDo } from './access';
import { joinedCids } from './communities';

const evList = (state: AppState, cid?: string | null) => {
  const ids = new Set(cid ? [cid] : joinedCids(state));
  return state.events.filter((e) => ids.has(e.c));
};

export const upcomingEvents = (state: AppState, cid?: string | null) =>
  evList(state, cid)
    .filter((e) => evState(e) !== 'past')
    .sort((a, b) => Number(a.cancelled) - Number(b.cancelled) || +evNext(a) - +evNext(b));

export const pastEvents = (state: AppState, cid?: string | null) =>
  evList(state, cid)
    .filter((e) => evState(e) === 'past')
    .sort((a, b) => +evNext(b) - +evNext(a));

export const comingUp = (state: AppState, cid: string) =>
  upcomingEvents(state, cid).filter((e) => !e.cancelled && evState(e) !== 'live');

export function homeEvents(state: AppState) {
  const list = upcomingEvents(state, null).filter((e) => !e.cancelled && evState(e) !== 'live');
  const mine = list.filter((e) => state.me && e.interested.includes(state.me));
  const picked = new Set(mine);

  return mine
    .concat(list.filter((e) => !picked.has(e)))
    .slice(0, 3)
    .sort((a, b) => +evNext(a) - +evNext(b));
}

export const isInterested = (state: AppState, e: CommunityEvent) =>
  !!state.me && e.interested.includes(state.me);

export const canManageEvent = (state: AppState, e: CommunityEvent | null | undefined) =>
  !!e && (e.host === state.me || canDo(state, e.c, 'event.create'));

export const nextVoiceEvent = (state: AppState, cid: string, roomId: string) =>
  state.events
    .filter(
      (e) =>
        !e.cancelled &&
        e.c === cid &&
        e.where.type === 'voice' &&
        e.where.room === roomId &&
        evState(e) !== 'past',
    )
    .sort((a, b) => +evNext(a) - +evNext(b))[0] ?? null;
