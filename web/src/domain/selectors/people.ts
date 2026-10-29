import type { AppState } from '../app-state';
import { stripPrefix } from '../links';
import type { Person, Visibility } from '../types';

const HEARTH_PERSON: Person = {
  name: 'Hearth',
  username: 'hearth',
  hue: 'ink',
  private: false,
  bio: null,
  helped: 0,
  posts: 0,
  answers: 0,
  joined: null,
  location: null,
};

const SOMEONE: Person = { ...HEARTH_PERSON, name: 'Someone', username: 'someone' };

export const person = (state: AppState, id: string | null | undefined): Person =>
  (id && state.people[id]) || (id === 'hearth' ? HEARTH_PERSON : SOMEONE);

export const personIdByHandle = (state: AppState, handle: string) => {
  const h = stripPrefix(handle.toLowerCase(), ['@']);
  return (
    Object.keys(state.people).find((k) => state.people[k]!.username.toLowerCase() === h) ?? null
  );
};

export const canSeeName = (state: AppState, id: string) =>
  id === state.me || !person(state, id).private;

export const displayName = (state: AppState, id: string) => {
  const p = person(state, id);
  return canSeeName(state, id) ? p.name : '@' + p.username;
};

/** Content someone wrote names them as You to themselves */
export const authorName = (state: AppState, id: string) =>
  id === state.me ? 'You' : displayName(state, id);

export const shortName = (state: AppState, id: string) => {
  const p = person(state, id);
  return canSeeName(state, id) ? p.name.split(' ')[0]! : '@' + p.username;
};

export const handle = (state: AppState, id: string) => '@' + person(state, id).username;

export const initials = (state: AppState, id: string) => {
  if (id === 'hearth') return '✦';

  const p = person(state, id);

  if (!canSeeName(state, id)) return p.username.slice(0, 2).toUpperCase();

  return p.name
    .split(' ')
    .map((s) => s[0])
    .slice(0, 2)
    .join('');
};

export const sharesCommunity = (state: AppState, id: string) =>
  id === state.me ||
  state.roles.some((r) => r.members.includes(id) && state.communities[r.c]?.joined) ||
  Object.values(state.communities).some((c) => c.joined && c.maintainer === id);

export const visOf = (state: AppState, id: string, key: 'presence' | 'photo'): Visibility =>
  person(state, id).show?.[key] || 'everyone';

const canSeeVis = (state: AppState, id: string, key: 'presence' | 'photo') => {
  if (id === state.me) return true;
  const v = visOf(state, id, key);
  return v === 'everyone' || (v === 'members' && sharesCommunity(state, id));
};

export const commsVisOf = (state: AppState, id: string) =>
  person(state, id).show?.communities || 'common';

export function presence(state: AppState, id: string) {
  const p = state.people[id];

  if (!p || !canSeeVis(state, id, 'presence')) return null;

  const live = state.online[id];

  if (live ?? p.lastSeen === 'online') return { online: true, label: 'Online now' };
  if (live === false || p.lastSeen === 'now') return { online: false, label: 'Last seen just now' };
  if (!p.lastSeen) return null;

  return { online: false, label: 'Last seen ' + p.lastSeen + ' ago' };
}

export const photoOf = (state: AppState, id: string) => {
  const p = person(state, id);
  return p.photo && canSeeVis(state, id, 'photo') ? p.photo : null;
};

export function findPerson(state: AppState, text: string) {
  const h = text.toLowerCase();
  const ids = Object.keys(state.people);
  const byHandle = ids.find((k) => state.people[k]!.username.toLowerCase() === h);

  if (byHandle) return byHandle;

  const byFirst = ids.filter(
    (k) => canSeeName(state, k) && state.people[k]!.name.split(' ')[0]!.toLowerCase() === h,
  );

  if (byFirst.length === 1) return byFirst[0]!;

  const byFull = ids.filter(
    (k) => canSeeName(state, k) && state.people[k]!.name.toLowerCase().replaceAll(' ', '') === h,
  );

  return byFull.length === 1 ? byFull[0]! : null;
}

export const peopleOptions = (state: AppState, exclude: string[] = []) => {
  const excluded = new Set(exclude);
  return Object.keys(state.people)
    .filter((id) => sharesCommunity(state, id) && !excluded.has(id))
    .map((id) => ({
      value: id,
      label: displayName(state, id),
      hint: displayName(state, id) === handle(state, id) ? null : handle(state, id),
    }));
};
