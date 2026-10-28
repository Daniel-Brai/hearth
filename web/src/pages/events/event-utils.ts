import { addDays } from 'date-fns';
import { evEnd, evNext, evState, evWhere } from '@/domain/events';
import type { Community, CommunityEvent, EventRepeat, VoiceMode } from '@/domain/types';
import type { IconName } from '@/design-system';
import { routes, slugify } from '@/runtime/routes';

export const VOICE_MODES: readonly {
  id: VoiceMode;
  label: string;
  icon: IconName;
  text: string;
}[] = [
  {
    id: 'open',
    label: 'Open',
    icon: 'mic',
    text: 'Anyone here can talk. You join muted and unmute when ready.',
  },
  {
    id: 'stage',
    label: 'Stage',
    icon: 'hand',
    text: 'Speakers talk on stage. Raise your hand to be invited up.',
  },
];

export const voiceModeInfo = (id: VoiceMode | undefined) =>
  VOICE_MODES.find((m) => m.id === (id ?? 'open')) ?? VOICE_MODES[0]!;

export const DURATIONS: readonly { value: string; label: string }[] = [
  { value: '15', label: '15 minutes' },
  { value: '30', label: '30 minutes' },
  { value: '45', label: '45 minutes' },
  { value: '60', label: '1 hour' },
  { value: '90', label: '1.5 hours' },
  { value: '120', label: '2 hours' },
  { value: '180', label: '3 hours' },
];

export const REPEATS: readonly { value: EventRepeat; label: string }[] = [
  { value: 'none', label: "Doesn't repeat" },
  { value: 'weekly', label: 'Every week' },
  { value: 'biweekly', label: 'Every 2 weeks' },
  { value: 'monthly', label: 'Every month' },
];

/** The mock store mutates events in place so views copy them to re-render */
export const snapshot = (e: CommunityEvent): CommunityEvent => ({
  ...e,
  interested: [...e.interested],
});

export const alwaysChanged = () => false;

export const eventLink = (e: CommunityEvent, origin: string) =>
  origin + routes.event(e.c, e.id, e.title);

export const eventFile = (e: CommunityEvent) => (slugify(e.title) || 'event') + '.ics';

export const interestedText = (e: CommunityEvent) =>
  e.interested.length
    ? `${e.interested.length} interested`
    : "Be the first to say you're interested";

const RULES: Record<EventRepeat, string | null> = {
  none: null,
  daily: 'RRULE:FREQ=DAILY',
  weekly: 'RRULE:FREQ=WEEKLY',
  biweekly: 'RRULE:FREQ=WEEKLY;INTERVAL=2',
  monthly: 'RRULE:FREQ=MONTHLY',
};

const stamp = (d: Date) =>
  d.toISOString().replace('.000', '').replaceAll('-', '').replaceAll(':', '');

const escapeText = (s: string) =>
  s.replaceAll('\\', '\\\\').replaceAll('\n', '\\n').replaceAll(',', '\\,').replaceAll(';', '\\;');

/** Depends only on the event so the server and the browser make the same link */
export function eventIcs(
  e: CommunityEvent,
  community: Community | undefined,
  origin: string,
): string {
  const place = evWhere(e, community);

  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Hearth//Events//EN',
    'BEGIN:VEVENT',
    `UID:${e.id}@hearth`,
    `DTSTAMP:${stamp(new Date(e.start))}`,
    `DTSTART:${stamp(evNext(e))}`,
    `DTEND:${stamp(evEnd(e))}`,
    RULES[e.repeat],
    `SUMMARY:${escapeText(e.title)}`,
    e.desc ? `DESCRIPTION:${escapeText(e.desc)}` : null,
    `LOCATION:${escapeText(place.external ? place.href : `${community?.name ?? 'Hearth'} ${place.label}`)}`,
    `URL:${eventLink(e, origin)}`,
    'END:VEVENT',
    'END:VCALENDAR',
  ].filter((l): l is string => l !== null);

  return 'data:text/calendar;charset=utf-8,' + encodeURIComponent(lines.join('\r\n'));
}

export type EventGroup = { label: string; items: CommunityEvent[] };

export function groupEvents(list: CommunityEvent[], past: boolean, now = Date.now()): EventGroup[] {
  if (past) return list.length ? [{ label: 'Earlier', items: list }] : [];

  const week = addDays(now, 7).getTime();

  const groups: EventGroup[] = [
    { label: 'Happening now', items: [] },
    { label: 'This week', items: [] },
    { label: 'Later', items: [] },
  ];

  const [live, soon, later] = groups;

  for (const e of list) {
    if (evState(e, now) === 'live') live?.items.push(e);
    else if (evNext(e).getTime() < week) soon?.items.push(e);
    else later?.items.push(e);
  }

  return groups.filter((g) => g.items.length);
}
