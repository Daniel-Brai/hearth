import type { AppState } from '@/domain/app-state';
import { community, modLevel } from '@/domain/selectors';
import type { ModerationLevel } from '@/domain/types';

const list = new Intl.ListFormat('en');

function placesAt(state: AppState, cid: string, level: ModerationLevel): string[] {
  const c = community(state, cid);

  if (!c) return [];

  const own = c.moderation ?? 'none';

  if (own === level) return [c.name];
  if (own !== 'full' && level !== 'none') return [];

  return c.rooms
    .filter((r) => modLevel(state, cid, r.id) === level)
    .map((r) => `${c.name} #${r.name}`);
}

export function modOffNote(state: AppState, cid: string): string | null {
  const reports = placesAt(state, cid, 'reports');
  const none = placesAt(state, cid, 'none');

  const parts = [
    reports.length ? `Only reports from people come in from ${list.format(reports)}.` : null,
    none.length
      ? `${list.format(none)} ${none.length === 1 ? "isn't" : "aren't"} moderated, so nothing from there comes here.`
      : null,
  ].filter((p) => p !== null);

  return parts.length ? parts.join(' ') : null;
}
