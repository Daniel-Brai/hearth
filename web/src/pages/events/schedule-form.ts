import { addMinutes, format } from 'date-fns';
import type { SelectOption } from '@/design-system';
import { evTime, evZone } from '@/domain/events';
import { isValidLink, normalizeUrl } from '@/domain/links';
import type { Community, CommunityEvent, EventRepeat, EventWhere } from '@/domain/types';
import { REPEATS } from './event-utils';

export type Place = 'hearth' | 'link';
export type Problem = { field: 'title' | 'url' | null; text: string };

export const roomOptions = (c: Community | undefined, voice: boolean): SelectOption<string>[] => [
  ...(voice ? (c?.voice ?? []) : []).map((v) => ({
    value: `voice:${v.id}`,
    label: v.name,
    hint: 'Voice',
  })),
  ...(c?.rooms ?? []).map((r) => ({ value: `chat:${r.id}`, label: '#' + r.name, hint: 'Chat' })),
];

export const tomorrowAtFive = () => {
  const d = new Date();

  d.setDate(d.getDate() + 1);
  d.setHours(17, 0, 0, 0);

  return d;
};

export function initialRoom(
  event: CommunityEvent | null,
  rooms: SelectOption<string>[],
): string | null {
  if (event && event.where.type !== 'link') return `${event.where.type}:${event.where.room}`;
  return rooms[0]?.value ?? null;
}

export function initialPlace(event: CommunityEvent | null, rooms: SelectOption<string>[]): Place {
  if (event) return event.where.type === 'link' ? 'link' : 'hearth';
  return rooms.length ? 'hearth' : 'link';
}

export function flashText(
  event: CommunityEvent | null,
  notify: boolean,
  community: string,
): string {
  if (event) return 'Event updated. Everyone interested gets the new time.';
  if (notify) return `Scheduled. Everyone in ${community} has been told.`;
  return 'Event scheduled';
}

export function whenSummary(when: Date | null, mins: string, repeat: EventRepeat): string | null {
  if (!when) return null;

  const range = `${format(when, 'EEEE, MMMM d')}, ${evTime(when)} to ${evTime(addMinutes(when, Number(mins)))} ${evZone()}`;
  const repeatLabel = REPEATS.find((r) => r.value === repeat)?.label ?? null;

  return repeat !== 'none' && repeatLabel ? `${range}. ${repeatLabel}.` : `${range}.`;
}

export function resolveWhere(
  place: Place,
  url: string,
  room: string | null,
): { where: EventWhere } | { problem: Problem } {
  if (place === 'link') {
    if (!url.trim()) return { problem: { field: 'url', text: 'Paste the meeting or stream link' } };

    const href = normalizeUrl(url);

    if (!isValidLink(href))
      return { problem: { field: 'url', text: "That doesn't look like a link" } };

    return { where: { type: 'link', url: href } };
  }

  if (!room) return { problem: { field: null, text: 'Pick a room' } };

  const split = room.indexOf(':');
  const kind = room.slice(0, split);
  const id = room.slice(split + 1);

  return { where: kind === 'voice' ? { type: 'voice', room: id } : { type: 'chat', room: id } };
}

/** Allows a minute in the past so submitting at "now" works */
export const alreadyPassed = (when: Date) => when.getTime() < Date.now() - 60000;
