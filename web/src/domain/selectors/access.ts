import type { AppState } from '../app-state';
import type { Permission, Role } from '../types';
import { joinedCids } from './communities';

export const rolesOf = (state: AppState, cid: string): Role[] =>
  state.roles.filter((r) => r.c === cid);

// Rooms list roles by the server's id, and roles made without a server by their key
export const roleRef = (role: Role) => role.uid ?? role.id;

export function myRolesIn(state: AppState, cid: string) {
  if (!state.me || !state.communities[cid]?.joined) return [];
  const mine = rolesOf(state, cid)
    .filter((r) => r.members.includes(state.me!))
    .map((r) => r.id);
  return mine.length ? mine : ['member'];
}

export const isOwner = (state: AppState, cid: string) =>
  !!state.me && state.communities[cid]?.maintainer === state.me;

export function canDo(state: AppState, cid: string | null | undefined, perm: Permission) {
  if (!cid || !state.me) return false;
  return state.communities[cid]?.permissions.includes(perm) ?? false;
}

export const isMod = (state: AppState, cid: string | null | undefined) =>
  canDo(state, cid, 'content.remove');

export const modCids = (state: AppState) =>
  joinedCids(state).filter((k) => canDo(state, k, 'content.remove'));

export const canAny = (state: AppState, perm: Permission) =>
  joinedCids(state).some((k) => canDo(state, k, perm));

export const roleName = (state: AppState, cid: string, id: string) =>
  rolesOf(state, cid).find((r) => r.id === id || roleRef(r) === id)?.name ?? id;

export const isInstanceAdmin = (state: AppState) => !!state.me && state.instance.isAdmin;

export const roleOptions = (state: AppState, cid: string, withOwner = false) => {
  const all = rolesOf(state, cid).filter((r) => withOwner || !r.locked);
  return (canDo(state, cid, 'role.update') ? all : all.filter((r) => r.id === 'member')).map(
    (r) => ({
      value: r.id,
      label: r.name,
    }),
  );
};

export const creationMode = (state: AppState) => state.instance.communityCreation;

export const canStartCommunity = (state: AppState) =>
  !!state.me && (isInstanceAdmin(state) || creationMode(state) === 'anyone');

export const canRequestCommunity = (state: AppState) =>
  !!state.me && !isInstanceAdmin(state) && creationMode(state) === 'request';

export const transcriptionOn = (state: AppState) => state.instance.transcription;

export const voiceOn = (state: AppState) => state.instance.voice;

export const recordingOn = (state: AppState) => state.instance.recording;
