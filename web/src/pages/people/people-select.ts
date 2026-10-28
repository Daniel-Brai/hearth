import type { AppState } from '@/domain/app-state';
import { dmCount, displayName, person, presence } from '@/domain/selectors';
import { plainText } from '@/features/markdown/plain-text';

export function peopleIndex(state: AppState): Map<string, string[]> {
  const found = new Map<string, Set<string>>();

  const add = (id: string | null | undefined, cid: string) => {
    if (!id || id === state.me || !state.people[id] || !state.communities[cid]?.joined) return;

    const set = found.get(id) ?? new Set<string>();

    set.add(cid);
    found.set(id, set);
  };

  state.posts.forEach((p) => {
    add(p.author, p.c);
    p.replies.forEach((r) => add(r.who, p.c));
  });

  Object.entries(state.chats).forEach(([key, list]) => {
    const cid = key.split('/')[0];
    if (cid && cid !== 'dm') list.forEach((m) => add(m.who, cid));
  });

  state.roles.forEach((r) => r.members.forEach((id) => add(id, r.c)));

  Object.entries(state.sharedCommunities).forEach(([id, cids]) =>
    cids.forEach((cid) => add(id, cid)),
  );

  Object.entries(state.communities).forEach(([cid, c]) => {
    add(c.maintainer, cid);
    c.voice.forEach((v) => add(v.host, cid));
  });

  return new Map([...found].map(([id, set]) => [id, [...set]]));
}

export const onlineFirst = (state: AppState) => (a: string, b: string) => {
  const rank = (id: string) => (presence(state, id)?.online ? 0 : 1);

  return rank(a) - rank(b) || displayName(state, a).localeCompare(displayName(state, b));
};

export function peopleIds(state: AppState, query: string, filter: string): string[] {
  const trimmed = query.trim().toLowerCase();
  const q = trimmed.startsWith('@') ? trimmed.slice(1) : trimmed;

  return [...peopleIndex(state)]
    .filter(([, cids]) => filter === 'all' || cids.includes(filter))
    .map(([id]) => id)
    .filter(
      (id) =>
        !q ||
        displayName(state, id).toLowerCase().includes(q) ||
        person(state, id).username.toLowerCase().includes(q),
    )
    .sort(onlineFirst(state));
}

const SHOWN_COMMUNITIES = 2;

export function sharedNames(state: AppState, id: string): string[] {
  return (peopleIndex(state).get(id) ?? [])
    .map((cid) => state.communities[cid]?.name)
    .filter((name): name is string => !!name);
}

export function sharedSummary(names: readonly string[]): { shown: string | null; more: number } {
  return {
    shown: names.length ? names.slice(0, SHOWN_COMMUNITIES).join(', ') : null,
    more: Math.max(0, names.length - SHOWN_COMMUNITIES),
  };
}

export function lastDmLine(state: AppState, who: string): string {
  const last = (state.chats['dm/' + who] ?? []).at(-1);
  if (!last) return 'No messages yet';

  return (last.who === state.me ? 'You: ' : '') + plainText(last.text).slice(0, 80);
}

export const directUnread = (state: AppState, who: string) => {
  const d = state.directs.find((x) => x.who === who);

  return d ? dmCount(d) : 0;
};
