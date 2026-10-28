import type { AppState } from '../app-state';
import type { Community, Template } from '../types';

export const community = (state: AppState, cid: string | null | undefined): Community | null =>
  cid ? (state.communities[cid] ?? null) : null;

export const joinedCids = (state: AppState) =>
  Object.keys(state.communities).filter((k) => state.communities[k]!.joined);

export const myRequests = (state: AppState) =>
  state.communityRequests.filter((r) => r.by === state.me && r.status === 'pending');

export const pendingRequests = (state: AppState) =>
  state.communityRequests.filter((r) => r.status === 'pending');

export const templateOf = (state: AppState, id: string): Template | null =>
  state.templates.find((t) => t.id === id) ?? state.templates.at(-1) ?? null;

export const openCommunities = (state: AppState) =>
  Object.entries(state.communities)
    .filter(([, c]) => !c.joined && c.visibility !== 'invite' && c.listed !== false)
    .slice(0, 8);

export const isTech = (state: AppState, cid: string | null | undefined) =>
  !!(cid && state.communities[cid]?.categories.includes('tech'));

export const communityUnread = (state: AppState, cid: string) => {
  const c = state.communities[cid];
  return !!c && (c.rooms.some((r) => r.unread) || state.posts.some((p) => p.c === cid && !p.seen));
};
