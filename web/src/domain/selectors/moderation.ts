import type { AppState } from '../app-state';
import type { ModerationLevel, QueueItem } from '../types';
import { community } from './communities';

const modLevelOf = (
  o: { moderation?: ModerationLevel } | null | undefined,
  fallback: ModerationLevel,
) => o?.moderation || fallback;

export function modLevel(state: AppState, cid: string, rid?: string | null): ModerationLevel {
  const order: ModerationLevel[] = ['none', 'reports', 'full'];
  const c = modLevelOf(community(state, cid), 'none');
  const r = rid ? modLevelOf(state.roomSettings[cid + '/' + rid], 'full') : 'full';

  return order[Math.min(order.indexOf(c), order.indexOf(r))]!;
}

export const modLevelText = (v: ModerationLevel) =>
  ({ full: 'full moderation', reports: 'reports only', none: 'no moderation' })[v];

export const reportsOn = (state: AppState, cid: string, rid?: string | null) =>
  modLevel(state, cid, rid) !== 'none';

export const isHeld = (state: AppState, x: QueueItem) => {
  const l = modLevel(state, x.c, x.r);
  return l === 'full' || (l === 'reports' && !!x.reported);
};

export const hasQueue = (state: AppState, cid: string) =>
  (community(state, cid)?.moderation ?? 'none') !== 'none';

export const queueCountIn = (state: AppState, cid: string) =>
  hasQueue(state, cid)
    ? (state.queueCounts[cid] ??
      state.queue.filter((x) => x.status === 'pending' && x.c === cid && isHeld(state, x)).length)
    : 0;
