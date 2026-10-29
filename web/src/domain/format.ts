export const cap = (n: number) => (n > 99 ? '99+' : String(n));

export const fmt = (n: number) =>
  n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1) + 'k' : String(n);

export const fmtSize = (b: number) =>
  b > 1048576 ? (b / 1048576).toFixed(1) + ' MB' : Math.max(1, Math.round(b / 1024)) + ' KB';

export function fileExtension(name: string): string | null {
  const dot = name.lastIndexOf('.');
  if (dot <= 0 || dot === name.length - 1) return null;

  return name.slice(dot + 1).toLowerCase();
}

export function shortFileName(name: string, max = 28): string {
  if (name.length <= max) return name;

  const ext = fileExtension(name);

  if (!ext) return name.slice(0, max - 1) + '…';

  const keep = Math.max(1, max - ext.length - 2);

  return name.slice(0, keep).trimEnd() + '….' + ext;
}

export const fmtLimit = (b: number) =>
  b >= 1073741824 ? b / 1073741824 + ' GB' : Math.round(b / 1048576) + ' MB';

export const plural = (n: number, one: string, many = one + 's') => `${n} ${n === 1 ? one : many}`;

export const noun = (n: number, one: string, many = one + 's') => (n === 1 ? one : many);

const AGE_UNITS: Record<string, number> = { m: 1, h: 60, d: 1440 };

export const ageMinutes = (a: string) => {
  if (a === 'now') return 0;
  const unit = AGE_UNITS[a.slice(-1)] ?? 1440;
  return parseInt(a, 10) * unit;
};

export const ageText = (a: string) => (a === 'now' ? 'just now' : a + ' ago');

export const todayIn = (zone?: string, now = new Date()) => {
  const { date, hour } = todayFormats(zone);

  return { date: date.format(now), hour: Number(hour.format(now)) };
};

const todayFormatters = new Map<string, { date: Intl.DateTimeFormat; hour: Intl.DateTimeFormat }>();

function todayFormats(zone?: string) {
  const key = zone ?? '';
  let found = todayFormatters.get(key);

  if (!found) {
    const opts = zone ? { timeZone: zone } : {};
    found = {
      date: new Intl.DateTimeFormat('en-US', {
        weekday: 'long',
        month: 'long',
        day: 'numeric',
        ...opts,
      }),
      hour: new Intl.DateTimeFormat('en-US', { hour: 'numeric', hourCycle: 'h23', ...opts }),
    };
    todayFormatters.set(key, found);
  }

  return found;
}

export const nowTime = () =>
  new Date().toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });

export const countText = (v: string, max: number) =>
  `${v.length.toLocaleString()} / ${max.toLocaleString()}`;

const HEX_DIGITS = new Set('0123456789abcdefABCDEF');
const HEX_LENGTHS = new Set([3, 4, 6, 8]);

export const isHex = (h: string) =>
  h.startsWith('#') &&
  HEX_LENGTHS.has(h.length - 1) &&
  [...h.slice(1)].every((ch) => HEX_DIGITS.has(ch));

export const tintStyle = (h: string | null | undefined) =>
  ({ '--tint': h && isHex(h) ? h : `var(--hue-${h ?? 'ink'})` }) as Record<string, string>;

const dateFormats = new Map<string, Intl.DateTimeFormat>();

// The locale is fixed so the server and browser write the same text
export function dateText(iso: string, zone?: string, withTime = false): string {
  const key = `${zone ?? ''}|${withTime}`;
  let format = dateFormats.get(key);

  if (!format) {
    format = new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      ...(withTime ? { hour: 'numeric', minute: '2-digit' } : {}),
      ...(zone ? { timeZone: zone } : {}),
    });
    dateFormats.set(key, format);
  }

  return format.format(new Date(iso));
}

// Three names fit before the rest become a count
export function typingLine(names: readonly string[]): string | null {
  const [first, second, third] = names;

  if (!first) return null;
  if (!second) return `${first} is typing`;
  if (!third) return `${first} and ${second} are typing`;
  if (names.length === 3) return `${first}, ${second} and ${third} are typing`;

  return `${first}, ${second} and ${plural(names.length - 2, 'other')} are typing`;
}
