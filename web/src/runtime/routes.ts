import { matchPath } from 'react-router';

/* Letters that Unicode normalisation does not split into a base letter and an accent */
const SPELLED: Readonly<Record<string, string>> = {
  ß: 'ss',
  æ: 'ae',
  œ: 'oe',
  ø: 'o',
  đ: 'd',
  ð: 'd',
  ł: 'l',
  þ: 'th',
  ı: 'i',
};

const isWordChar = (c: string) => (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9');
const isAccent = (c: string) => c >= '\u0300' && c <= '\u036f';

export function slugify(text: string): string {
  let out = '';
  let dash = false;

  for (const c of text.toLowerCase().normalize('NFKD')) {
    if (isAccent(c)) continue;

    const letters = SPELLED[c] ?? (isWordChar(c) ? c : null);

    if (letters === null) {
      dash = out.length > 0;
      continue;
    }

    if (dash) out += '-';
    out += letters;
    dash = false;

    if (out.length >= 60) break;
  }

  let slug = out.slice(0, 60);

  while (slug.endsWith('-')) slug = slug.slice(0, -1);

  return slug;
}

const idSlug = (id: string, title?: string) => {
  const slug = title ? slugify(title) : null;
  return slug ? `${id}-${slug}` : id;
};

const UUID_LENGTH = 36;
const UUID_DASHES = new Set([8, 13, 18, 23]);
const HEX = new Set('0123456789abcdefABCDEF');

function leadingUuid(segment: string): string | null {
  if (segment.length < UUID_LENGTH) return null;
  if (segment.length > UUID_LENGTH && segment[UUID_LENGTH] !== '-') return null;

  for (let i = 0; i < UUID_LENGTH; i++) {
    const c = segment[i]!;
    const fits = UUID_DASHES.has(i) ? c === '-' : HEX.has(c);
    if (!fits) return null;
  }

  return segment.slice(0, UUID_LENGTH).toLowerCase();
}

// The slug is ignored so a link from an older title still finds its record
// UUIDs contain dashes so a segment starting with one keeps its first 36 characters
export function idFromSegment(segment: string | undefined): string | null {
  if (!segment) return null;

  return leadingUuid(segment) ?? segment.split('-')[0] ?? null;
}

export const routes = {
  home: '/',
  signIn: '/signin',
  join: (code: string) => `/join/${encodeURIComponent(code)}`,
  joinPreview: (code: string) => `/join/${encodeURIComponent(code)}?preview=1`,
  newPost: '/new',
  newCommunity: '/communities/new',
  events: '/events',
  people: '/people',
  dm: (handle: string) => `/dm/${encodeURIComponent(handle)}`,
  settings: '/settings',
  settingsProfile: '/settings/profile',
  settingsInstance: '/settings/instance',
  emailUndo: '/settings/email/undo',
  instanceReports: '/settings/instance/reports',
  requests: '/requests',
  myInvites: '/invites',
  profile: (handle: string) => `/u/${encodeURIComponent(handle)}`,
  community: (c: string) => `/c/${c}`,
  tag: (c: string, tag: string) => `/c/${c}/t/${encodeURIComponent(tag)}`,
  post: (c: string, id: string, title?: string) => `/c/${c}/p/${idSlug(id, title)}`,
  communityEvents: (c: string) => `/c/${c}/events`,
  event: (c: string, id: string, title?: string) => `/c/${c}/e/${idSlug(id, title)}`,
  chat: (c: string, room: string) => `/c/${c}/chat/${room}`,
  voice: (c: string, room: string) => `/c/${c}/voice/${room}`,
  session: (c: string, id: string) => `/c/${c}/sessions/${id}`,
  communityNew: (c: string) => `/c/${c}/new`,
  communityEdit: (c: string) => `/c/${c}/edit`,
  invite: (c: string) => `/c/${c}/invite`,
  moderation: (c: string) => `/c/${c}/moderation`,
  roles: (c: string) => `/c/${c}/roles`,
  log: (c: string) => `/c/${c}/log`,
} as const;

export const patterns = {
  community: '/c/:community',
  tag: '/c/:community/t/:tag',
  post: '/c/:community/p/:post',
  communityEvents: '/c/:community/events',
  event: '/c/:community/e/:event',
  chat: '/c/:community/chat/:room',
  voice: '/c/:community/voice/:room',
  session: '/c/:community/sessions/:session',
  communityNew: '/c/:community/new',
  communityEdit: '/c/:community/edit',
  invite: '/c/:community/invite',
  moderation: '/c/:community/moderation',
  roles: '/c/:community/roles',
  log: '/c/:community/log',
  profile: '/u/:handle',
  dm: '/dm/:handle',
  join: '/join/:code',
} as const;

const PUBLIC_PATTERNS = [
  patterns.community,
  patterns.tag,
  patterns.post,
  patterns.communityEvents,
  patterns.event,
  patterns.profile,
  patterns.log,
];

export function isPublicPath(href: string): boolean {
  const { pathname } = new URL(href, 'http://hearth.local');

  return pathname === '/' || PUBLIC_PATTERNS.some((pattern) => matchPath(pattern, pathname));
}
