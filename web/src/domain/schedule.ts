import { addDays, addHours, addMinutes, format, isSameDay, nextMonday, set } from 'date-fns';

const LATEST_DAYS = 30;
export const MOST_SCHEDULED = 50;

export type SendChoice = { readonly id: string; readonly label: string; readonly at: Date };

const morning = (day: Date) => set(day, { hours: 9, minutes: 0, seconds: 0, milliseconds: 0 });

// Rounded up to the next five minutes so the time reads cleanly
function roundUp(d: Date): Date {
  const minute = set(d, { seconds: 0, milliseconds: 0 });

  return addMinutes(minute, 5 - (minute.getMinutes() % 5));
}

export function sendChoices(now: Date): SendChoice[] {
  const tomorrow = morning(addDays(now, 1));
  const monday = morning(nextMonday(now));
  const evening = set(now, { hours: 18, minutes: 0, seconds: 0, milliseconds: 0 });

  return [
    { id: 'hour', label: 'In 1 hour', at: roundUp(addHours(now, 1)) },
    ...(now.getHours() < 17 ? [{ id: 'evening', label: 'This evening', at: evening }] : []),
    { id: 'tomorrow', label: 'Tomorrow 9 AM', at: tomorrow },
    ...(isSameDay(monday, tomorrow) ? [] : [{ id: 'monday', label: 'Monday 9 AM', at: monday }]),
  ];
}

export function sendAtLabel(at: Date, now: Date): string {
  const time = format(at, 'h:mm a');

  if (isSameDay(at, now)) return 'today at ' + time;
  if (isSameDay(at, addDays(now, 1))) return 'tomorrow at ' + time;

  const day = at.getFullYear() === now.getFullYear() ? 'EEE, MMM d' : 'EEE, MMM d, yyyy';

  return format(at, day) + ' at ' + time;
}

export function sendAtProblem(at: Date, now: Date): string | null {
  if (at < addMinutes(now, 1)) return 'Pick a time at least a minute from now.';
  if (at > addDays(now, LATEST_DAYS)) return 'Pick a time in the next ' + LATEST_DAYS + ' days.';

  return null;
}

const FAILURES: Record<string, string> = {
  forbidden: "You can't post there any more.",
  not_found: 'The room, conversation or community is gone.',
  archived: 'The room was archived.',
  pending: 'The message it answered is waiting for a moderator.',
  too_many_attachments: 'It has more files than a message can carry.',
  invalid_attachment: 'One of its files is missing.',
  unknown_kind: "That kind of post isn't available any more.",
};

/** The server keeps a short code for why something couldn't go out */
export const failureText = (code: string): string =>
  FAILURES[code] ?? "It couldn't go out. Move it to try again.";
