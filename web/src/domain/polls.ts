import type { NewPoll, Poll } from './types';

export const QUESTION_MAX = 300;
export const CHOICE_MAX = 100;
export const LEAST_CHOICES = 2;
export const MOST_CHOICES = 10;

export type CloseAfter = { readonly id: string; readonly label: string; readonly minutes: number };

/** How long a poll runs before it closes by itself. Leaving it out keeps it open until closed */
export const CLOSE_AFTER: readonly CloseAfter[] = [
  { id: '5m', label: 'In 5 minutes', minutes: 5 },
  { id: '15m', label: 'In 15 minutes', minutes: 15 },
  { id: '1h', label: 'In 1 hour', minutes: 60 },
  { id: '1d', label: 'In 1 day', minutes: 1440 },
];

const LONGEST_DAYS = 7;

/** A poll set to close by itself does so at least a minute and at most a week ahead */
export function closesAtProblem(at: Date, now: Date): string | null {
  if (at.getTime() < now.getTime() + 60_000) return 'Pick a time at least a minute from now.';
  if (at.getTime() > now.getTime() + LONGEST_DAYS * 86_400_000)
    return `A poll can stay open for up to ${LONGEST_DAYS} days.`;

  return null;
}

export function pollProblem(poll: NewPoll): string | null {
  const choices = poll.options.map((o) => o.trim());
  const folded = choices.map((o) => o.toLowerCase());

  if (!poll.question.trim()) return 'Ask a question first.';
  if (poll.question.trim().length > QUESTION_MAX)
    return `Keep the question under ${QUESTION_MAX} characters.`;
  if (choices.some((o) => !o)) return 'Fill in every choice or remove the empty one.';
  if (choices.length < LEAST_CHOICES) return 'Add at least two choices.';
  if (choices.length > MOST_CHOICES) return `A poll can have up to ${MOST_CHOICES} choices.`;
  if (choices.some((o) => o.length > CHOICE_MAX))
    return `Keep each choice under ${CHOICE_MAX} characters.`;
  if (new Set(folded).size !== folded.length) return 'Each choice needs to be different.';

  return null;
}

export const pollOpen = (poll: Poll, now: Date) =>
  poll.closedAt === null && (poll.closesAt === null || new Date(poll.closesAt) > now);

/** Tapping a picked choice takes it back. In a single choice poll a new pick replaces the old */
export function nextPicks(poll: Poll, optionId: string): string[] {
  const picked = poll.mine.includes(optionId);

  if (!poll.multiple) return picked ? [] : [optionId];

  return picked ? poll.mine.filter((id) => id !== optionId) : [...poll.mine, optionId];
}

/** Shares of everyone who voted, so several picks each can add up past 100 */
export const share = (poll: Poll, votes: number) =>
  poll.voters ? Math.round((votes / poll.voters) * 100) : 0;

/** Minutes round up, so a poll with seconds to go never reads as closing in 0 min */
export function closingLabel(poll: Poll, now: Date): string | null {
  if (!pollOpen(poll, now)) return 'Closed';
  if (!poll.closesAt) return null;

  const minutes = Math.max(
    1,
    Math.ceil((new Date(poll.closesAt).getTime() - now.getTime()) / 60_000),
  );

  if (minutes < 60) return `Closes in ${minutes} min`;
  if (minutes < 1440) return `Closes in ${Math.round(minutes / 60)} h`;

  return `Closes in ${Math.round(minutes / 1440)} d`;
}

/** Applies a vote to the totals the way the server counts it */
export function withVote(poll: Poll, picks: readonly string[]): Poll {
  const before = new Set(poll.mine);
  const after = new Set(picks);

  return {
    ...poll,
    mine: [...picks],
    voters: poll.voters + (after.size ? 1 : 0) - (before.size ? 1 : 0),
    options: poll.options.map((o) => ({
      ...o,
      votes: o.votes + (after.has(o.id) ? 1 : 0) - (before.has(o.id) ? 1 : 0),
    })),
  };
}
