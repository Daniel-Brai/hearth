import {
  addDays,
  addMonths,
  eachDayOfInterval,
  endOfWeek,
  format,
  isBefore,
  isValid,
  parse,
  startOfDay,
  startOfMonth,
  startOfWeek,
} from 'date-fns';

const DAY_KEY = 'yyyy-MM-dd';
const TIME_KEY = 'HH:mm';

export const dayKey = (d: Date) => format(d, DAY_KEY);

export function parseDay(key: string | null): Date | null {
  if (!key) return null;
  const d = parse(key, DAY_KEY, new Date());
  return isValid(d) ? d : null;
}

export function dayLabel(key: string): string | null {
  const d = parseDay(key);
  if (!d) return null;
  return format(
    d,
    d.getFullYear() === new Date().getFullYear() ? 'EEE, MMM d' : 'EEE, MMM d, yyyy',
  );
}

export const monthLabel = (d: Date) => format(d, 'MMMM yyyy');

export const weekdayLabels = (): { key: string; label: string }[] =>
  eachDayOfInterval({ start: startOfWeek(new Date()), end: endOfWeek(new Date()) }).map((d) => ({
    key: format(d, 'EEE'),
    label: format(d, 'EEEEE'),
  }));

export type CalendarDay = { key: string; day: number; inMonth: boolean };

export function calendarDays(month: Date): CalendarDay[] {
  const first = startOfMonth(month);
  const start = startOfWeek(first);

  return Array.from({ length: 42 }, (_, i) => {
    const d = addDays(start, i);
    return { key: dayKey(d), day: d.getDate(), inMonth: d.getMonth() === first.getMonth() };
  });
}

export const isPastDay = (d: Date) => isBefore(d, startOfDay(new Date()));

export const shiftMonth = (d: Date, by: number) => addMonths(startOfMonth(d), by);

export const timeSlots = (): string[] =>
  Array.from({ length: 96 }, (_, i) =>
    format(new Date(2000, 0, 1, Math.floor(i / 4), (i % 4) * 15), TIME_KEY),
  );

export function timeLabel(t: string): string | null {
  const d = parse(t, TIME_KEY, new Date());
  return isValid(d) ? format(d, 'h:mm a') : null;
}

const isDigits = (s: string) => s.length > 0 && [...s].every((ch) => ch >= '0' && ch <= '9');

const MERIDIEMS = ['am', 'pm', 'a', 'p'];

/** Accepts "6:30 pm", "630p", "18:30", "noon" and "midnight" */
export function parseTimeText(text: string): string | null {
  const s = text.trim().toLowerCase().replaceAll(' ', '').replaceAll('.', ':');

  if (s === 'noon') return '12:00';
  if (s === 'midnight') return '00:00';

  const suffix = MERIDIEMS.find((m) => s.endsWith(m)) ?? null;
  const core = suffix ? s.slice(0, -suffix.length) : s;

  let hours: string;
  let minutes = '0';

  if (core.includes(':')) {
    const parts = core.split(':');
    const [h, m] = parts;

    if (parts.length !== 2 || h === undefined || m === undefined || m.length !== 2) return null;
    hours = h;
    minutes = m;
  } else if (core.length > 2) {
    hours = core.slice(0, -2);
    minutes = core.slice(-2);
  } else {
    hours = core;
  }

  if (!isDigits(hours) || hours.length > 2 || !isDigits(minutes)) return null;

  let h = Number(hours);
  const m = Number(minutes);

  if (m > 59 || h > 23) return null;

  if (suffix) {
    if (h < 1 || h > 12) return null;
    if (suffix.startsWith('p') && h < 12) h += 12;
    if (suffix.startsWith('a') && h === 12) h = 0;
  }

  return format(new Date(2000, 0, 1, h, m), TIME_KEY);
}

export function combine(day: string, time: string): Date | null {
  const d = parse(`${day} ${time}`, `${DAY_KEY} ${TIME_KEY}`, new Date());
  return isValid(d) ? d : null;
}
