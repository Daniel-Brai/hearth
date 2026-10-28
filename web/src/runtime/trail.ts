import { sessionStore } from './browser-storage';

export type TrailEntry = { readonly href: string; readonly label: string };

const KEY = 'hearth-trail';
const MAX = 12;

function read(): TrailEntry[] {
  try {
    const raw = sessionStore()?.getItem(KEY);
    return raw ? (JSON.parse(raw) as TrailEntry[]) : [];
  } catch {
    return [];
  }
}

function write(trail: TrailEntry[]) {
  try {
    sessionStore()?.setItem(KEY, JSON.stringify(trail));
  } catch (error) {
    console.warn('Back buttons will not remember earlier pages in this tab.', error);
  }
}

const pageKey = (href: string) => href.split('#')[0]!.split('?')[0]!;

// A replaced page overwrites the last entry so Back never leads to a page the person left
export function recordVisit(
  href: string,
  label: string,
  isHome: boolean,
  replaced = false,
): TrailEntry | null {
  const trail = visit(href, label, isHome, replaced);
  write(trail);
  return previous(trail);
}

export function peekVisit(
  href: string,
  label: string,
  isHome: boolean,
  replaced = false,
): TrailEntry | null {
  return previous(visit(href, label, isHome, replaced));
}

function visit(href: string, label: string, isHome: boolean, replaced: boolean): TrailEntry[] {
  let trail = isHome ? [] : read();
  const key = pageKey(href);
  const i = trail.findIndex((x) => pageKey(x.href) === key);

  if (i >= 0) {
    trail = trail.slice(0, i + 1);
    trail[i] = { href, label };
  } else if (replaced && trail.length) trail[trail.length - 1] = { href, label };
  else trail.push({ href, label });

  return trail.slice(-MAX);
}

const previous = (trail: TrailEntry[]) => (trail.length >= 2 ? trail[trail.length - 2]! : null);
