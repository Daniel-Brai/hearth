import { addDays, addMonths, addWeeks } from 'date-fns';
import type { Community, CommunityEvent, EventRepeat } from '@/domain/types';
import { parseLink } from '@/domain/links';
import { routes } from '@/runtime/routes';

// Server and browser use the same zone until hydration ends so both write the same times
const formatter = (options: Intl.DateTimeFormatOptions) => {
  const built = new Map<string, Intl.DateTimeFormat>();

  return {
    format: (d: Date, zone?: string) => {
      const key = zone ?? '';
      let f = built.get(key);

      if (!f) {
        f = new Intl.DateTimeFormat('en-US', zone ? { ...options, timeZone: zone } : options);
        built.set(key, f);
      }

      return f.format(d);
    },
  };
};

const TIME = formatter({ hour: 'numeric', minute: '2-digit' });
const MONTH = formatter({ month: 'short' });
const WEEKDAY = formatter({ weekday: 'short' });
const WEEKDAY_LONG = formatter({ weekday: 'long' });
const DAY = formatter({ month: 'short', day: 'numeric' });
const DAY_NUMBER = formatter({ day: 'numeric' });
const WEEKDAY_DAY = formatter({ weekday: 'short', month: 'short', day: 'numeric' });
const CALENDAR_DAY = formatter({ year: 'numeric', month: 'numeric', day: 'numeric' });

function calendarDaysBetween(from: Date, to: Date, zone?: string): number {
  const midnight = (d: Date) => {
    const [m, day, y] = CALENDAR_DAY.format(d, zone).split('/').map(Number);
    return Date.UTC(y!, m! - 1, day!);
  };

  return Math.round((midnight(to) - midnight(from)) / 86_400_000);
}

export type EventState = 'cancelled' | 'live' | 'past' | 'soon' | 'upcoming';

const HOUR = 3600000;

function step(d: Date, repeat: Exclude<EventRepeat, 'none'>): Date {
  switch (repeat) {
    case 'daily':
      return addDays(d, 1);
    case 'weekly':
      return addWeeks(d, 1);
    case 'biweekly':
      return addWeeks(d, 2);
    case 'monthly':
      return addMonths(d, 1);
  }
}

export function evNext(e: CommunityEvent, now = Date.now()): Date {
  let d = new Date(e.start);

  if (e.repeat === 'none') return d;

  let guard = 0;

  while (d.getTime() + e.mins * 60000 < now && guard++ < 500) d = step(d, e.repeat);

  return d;
}

export const evEnd = (e: CommunityEvent) => new Date(evNext(e).getTime() + e.mins * 60000);

export function evState(e: CommunityEvent, now = Date.now()): EventState {
  if (e.cancelled) return 'cancelled';

  const s = evNext(e, now).getTime();
  const end = s + e.mins * 60000;

  if (now >= s && now < end) return 'live';
  if (end <= now) return 'past';
  if (s - now < HOUR) return 'soon';

  return 'upcoming';
}

export const evTime = (d: Date, zone?: string) => TIME.format(d, zone);

export const evDay = (e: CommunityEvent, zone?: string) => {
  const d = evNext(e);
  return {
    mon: MONTH.format(d, zone),
    day: Number(DAY_NUMBER.format(d, zone)),
    dow: WEEKDAY.format(d, zone),
  };
};

export const evWhen = (e: CommunityEvent, zone?: string) =>
  `${WEEKDAY_DAY.format(evNext(e), zone)} · ${evTime(evNext(e), zone)} to ${evTime(evEnd(e), zone)}`;

export const evZone = (zone?: string) =>
  (zone ?? Intl.DateTimeFormat().resolvedOptions().timeZone).replaceAll('_', ' ');

export function evRel(e: CommunityEvent, zone?: string, now = Date.now()): string {
  const st = evState(e, now);

  if (st === 'cancelled') return 'Cancelled';
  if (st === 'live') return 'Happening now';

  const s = evNext(e, now);

  if (st === 'past') return DAY.format(s, zone);

  const diff = s.getTime() - now;

  if (diff < HOUR) return 'Starts in ' + Math.max(1, Math.round(diff / 60000)) + ' min';

  const days = calendarDaysBetween(new Date(now), s, zone);

  if (days === 0) return 'Today at ' + evTime(s, zone);
  if (days === 1) return 'Tomorrow at ' + evTime(s, zone);
  if (days < 7) return WEEKDAY_LONG.format(s, zone) + ' at ' + evTime(s, zone);

  return 'In ' + days + ' days';
}

const REPEAT_LABELS: Record<Exclude<EventRepeat, 'none'>, string> = {
  daily: 'Every day',
  weekly: 'Every week',
  biweekly: 'Every 2 weeks',
  monthly: 'Every month',
};

export const evRepeatLabel = (e: CommunityEvent): string | null =>
  e.repeat === 'none' ? null : REPEAT_LABELS[e.repeat];

const PROVIDERS: readonly [domain: string, name: string][] = [
  ['meet.google.com', 'Google Meet'],
  ['zoom.us', 'Zoom'],
  ['zoom.com', 'Zoom'],
  ['teams.microsoft.com', 'Microsoft Teams'],
  ['teams.live.com', 'Microsoft Teams'],
  ['discord.gg', 'Discord'],
  ['discord.com', 'Discord'],
  ['youtube.com', 'YouTube'],
  ['youtu.be', 'YouTube'],
  ['twitch.tv', 'Twitch'],
  ['meet.jit.si', 'Jitsi Meet'],
  ['whereby.com', 'Whereby'],
  ['webex.com', 'Webex'],
  ['gather.town', 'Gather'],
];

export type Provider = { name: string; known: boolean; host: string | null };

export function evProvider(url: string): Provider | null {
  const parsed = parseLink(url);

  if (!parsed) return null;

  const hit = PROVIDERS.find(([d]) => parsed.host === d || parsed.host.endsWith('.' + d));

  return { name: hit ? hit[1] : parsed.host, known: !!hit, host: parsed.host };
}

const isMapLink = (host: string, path: string) =>
  host.includes('maps') ||
  host === 'openstreetmap.org' ||
  (host.includes('google.') && path.startsWith('/maps'));

export type EventPlace = {
  icon: string;
  label: string;
  sub: string;
  href: string;
  join: string;
  external?: boolean;
};

export function evWhere(e: CommunityEvent, c: Community | undefined): EventPlace {
  const w = e.where;
  switch (w.type) {
    case 'voice': {
      const v = c?.voice.find((x) => x.id === w.room);
      return {
        icon: 'volume',
        label: v ? v.name : 'Voice room',
        sub: 'Voice room on Hearth',
        href: routes.voice(e.c, w.room),
        join: 'Join the room',
      };
    }
    case 'chat':
      return {
        icon: 'hash',
        label: '#' + w.room,
        sub: 'Chat room on Hearth',
        href: routes.chat(e.c, w.room),
        join: 'Open the room',
      };
    case 'link': {
      const parsed = parseLink(w.url);

      if (parsed && isMapLink(parsed.host, parsed.path)) {
        return {
          icon: 'map',
          label: w.label ?? 'On the map',
          sub: 'In person, opens the map',
          href: w.url,
          join: 'Get directions',
          external: true,
        };
      }

      const pr = evProvider(w.url) ?? { name: 'Online', known: false, host: null };

      return {
        icon: pr.known ? 'video' : 'external',
        label: w.label ?? pr.name,
        sub: 'Opens ' + (pr.known ? pr.name : 'the link') + ' in a new tab',
        href: w.url,
        join: 'Join on ' + pr.name,
        external: true,
      };
    }
  }
}
