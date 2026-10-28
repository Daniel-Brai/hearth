import type { AppState } from '@/domain/app-state';

const USERNAME_CHARS = new Set('abcdefghijklmnopqrstuvwxyz0123456789_');

export const isUsername = (u: string) =>
  u.length >= 3 && u.length <= 20 && [...u].every((ch) => USERNAME_CHARS.has(ch));

export function usernameProblem(state: AppState, u: string, self: string | null): string | null {
  if (!u) return 'Pick a username';
  if (!isUsername(u)) return 'Use 3 to 20 lowercase letters, numbers or underscores';

  const taken = Object.entries(state.people).some(([id, p]) => p.username === u && id !== self);

  return taken ? takenText(u, state.seq) : null;
}

export const takenText = (u: string, seq: number) =>
  '@' + u + ' is taken. Try @' + u + '_' + ((seq % 90) + 10);

export const toUsername = (text: string) =>
  [...text.toLowerCase()]
    .filter((ch) => USERNAME_CHARS.has(ch))
    .join('')
    .slice(0, 20);
