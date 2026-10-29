import type { IconName } from '@/design-system/icons/icons';

export type LinkKind = { name: string; icon: IconName };

type Rule = { test: (host: string, path: string) => boolean; name: string; icon: IconName };

const under = (host: string, domain: string) => host === domain || host.endsWith('.' + domain);
const anyOf = (host: string, ...domains: string[]) => domains.some((d) => under(host, d));

const MASTODON_PREFIXES = ['mastodon.', 'fosstodon.', 'hachyderm.', 'mstdn.', 'infosec.'];

const isMastodon = (host: string, path: string) =>
  MASTODON_PREFIXES.some((p) => host.startsWith(p)) ||
  host === 'mastodon.social' ||
  (path.startsWith('/@') &&
    !path.slice(2).includes('/') &&
    (host.includes('social') || host.includes('masto')));

const RULES: Rule[] = [
  {
    test: (h, p) => under(h, 'github.com') && p.startsWith('/sponsors'),
    name: 'GitHub Sponsors',
    icon: 'heart',
  },
  { test: (h) => under(h, 'github.com'), name: 'GitHub', icon: 'github' },
  { test: (h) => under(h, 'gitlab.com'), name: 'GitLab', icon: 'code' },
  { test: (h) => under(h, 'codeberg.org'), name: 'Codeberg', icon: 'code' },
  { test: (h) => anyOf(h, 'youtube.com', 'youtu.be'), name: 'YouTube', icon: 'youtube' },
  { test: (h) => anyOf(h, 'x.com', 'twitter.com'), name: 'X', icon: 'xsocial' },
  { test: (h) => under(h, 'linkedin.com'), name: 'LinkedIn', icon: 'linkedin' },
  { test: (h) => under(h, 'instagram.com'), name: 'Instagram', icon: 'instagram' },
  { test: (h) => under(h, 'tiktok.com'), name: 'TikTok', icon: 'tiktok' },
  { test: (h) => under(h, 'twitch.tv'), name: 'Twitch', icon: 'twitch' },
  { test: (h) => anyOf(h, 'discord.gg', 'discord.com'), name: 'Discord', icon: 'discord' },
  { test: (h) => under(h, 'bsky.app'), name: 'Bluesky', icon: 'bluesky' },
  { test: isMastodon, name: 'Mastodon', icon: 'mastodon' },
  { test: (h) => under(h, 'threads.net'), name: 'Threads', icon: 'at' },
  { test: (h) => anyOf(h, 'facebook.com', 'fb.com'), name: 'Facebook', icon: 'users' },
  {
    test: (h) => anyOf(h, 'buymeacoffee.com', 'buymeacoff.ee'),
    name: 'Buy Me a Coffee',
    icon: 'coffee',
  },
  { test: (h) => under(h, 'ko-fi.com'), name: 'Ko-fi', icon: 'coffee' },
  { test: (h) => under(h, 'patreon.com'), name: 'Patreon', icon: 'patreon' },
  { test: (h) => under(h, 'opencollective.com'), name: 'Open Collective', icon: 'heart' },
  { test: (h) => under(h, 'liberapay.com'), name: 'Liberapay', icon: 'heart' },
  { test: (h) => anyOf(h, 'paypal.me', 'paypal.com'), name: 'PayPal', icon: 'heart' },
  { test: (h) => anyOf(h, 'paystack.com', 'paystack.shop'), name: 'Paystack', icon: 'heart' },
  { test: (h) => anyOf(h, 'selar.co', 'selar.com'), name: 'Selar', icon: 'heart' },
  { test: (h) => under(h, 'substack.com'), name: 'Substack', icon: 'pen' },
  { test: (h) => under(h, 'medium.com'), name: 'Medium', icon: 'medium' },
  { test: (h) => under(h, 'dev.to'), name: 'DEV', icon: 'devto' },
  { test: (h) => anyOf(h, 'hashnode.dev', 'hashnode.com'), name: 'Hashnode', icon: 'hashnode' },
  { test: (h) => under(h, 'ghost.io'), name: 'Blog', icon: 'pen' },
  { test: (h) => under(h, 'spotify.com'), name: 'Spotify', icon: 'music' },
  { test: (h) => under(h, 'soundcloud.com'), name: 'SoundCloud', icon: 'music' },
  { test: (h) => under(h, 'music.apple.com'), name: 'Apple Music', icon: 'music' },
  { test: (h) => under(h, 'bandcamp.com'), name: 'Bandcamp', icon: 'music' },
  { test: (h) => under(h, 'podcasts.apple.com'), name: 'Podcast', icon: 'mic' },
  { test: (h) => under(h, 'dribbble.com'), name: 'Dribbble', icon: 'image' },
  { test: (h) => under(h, 'behance.net'), name: 'Behance', icon: 'image' },
  { test: (h) => under(h, 'figma.com'), name: 'Figma', icon: 'shapes' },
  { test: (h) => under(h, 'stackoverflow.com'), name: 'Stack Overflow', icon: 'question' },
  { test: (h) => anyOf(h, 't.me', 'telegram.me'), name: 'Telegram', icon: 'send' },
  { test: (h) => anyOf(h, 'wa.me', 'whatsapp.com'), name: 'WhatsApp', icon: 'chat' },
  { test: (h) => anyOf(h, 'calendly.com', 'cal.com'), name: 'Book a call', icon: 'calendar' },
  { test: (h) => under(h, 'linktr.ee'), name: 'Linktree', icon: 'link' },
  { test: (h) => under(h, 'strava.com'), name: 'Strava', icon: 'map' },
  { test: (h) => under(h, 'goodreads.com'), name: 'Goodreads', icon: 'list' },
  { test: (h) => under(h, 'hexdocs.pm'), name: 'HexDocs', icon: 'scroll' },
];

const SCHEMES = ['http://', 'https://', 'mailto:'];

export const stripPrefix = (s: string, prefixes: readonly string[]) => {
  const hit = prefixes.find((p) => s.startsWith(p));
  return hit ? s.slice(hit.length) : s;
};

export const stripSuffix = (s: string, suffix: string) =>
  s.endsWith(suffix) ? s.slice(0, -suffix.length) : s;

export function normalizeUrl(input: string): string {
  const u = input.trim();
  const lower = u.toLowerCase();
  return SCHEMES.some((s) => lower.startsWith(s)) ? u : 'https://' + u;
}

export type ParsedLink = { host: string; path: string; protocol: string };

export function parseLink(url: string): ParsedLink | null {
  try {
    const x = new URL(normalizeUrl(url));
    return {
      host: stripPrefix(x.hostname.toLowerCase(), ['www.', 'm.']),
      path: x.pathname.toLowerCase(),
      protocol: x.protocol,
    };
  } catch {
    return null;
  }
}

export function linkKind(url: string): LinkKind | null {
  const u = url.trim();

  if (!u) return null;
  if (u.toLowerCase().startsWith('mailto:')) return { name: 'Email', icon: 'mail' };

  const parsed = parseLink(u);

  if (!parsed) return null;

  const hit = RULES.find((r) => r.test(parsed.host, parsed.path));

  return hit ? { name: hit.name, icon: hit.icon } : null;
}

export const linkIcon = (url: string): IconName => linkKind(url)?.icon ?? 'link';

export function cleanUrl(u: string): string {
  const parsed = parseLink(u);
  if (!parsed) return u.trim();
  return stripSuffix(parsed.host + parsed.path, '/');
}

// Keeps the host and the last part of the path, which say the most about where a link goes
export function shortLink(url: string, max = 48): string {
  if (!URL.canParse(url)) return url;

  const u = new URL(url);
  const clean = stripSuffix(u.host.replace(/^www\./, '') + u.pathname + u.search + u.hash, '/');

  if (clean.length <= max) return clean;

  const slash = clean.lastIndexOf('/');
  const tail = slash > clean.indexOf('/') ? clean.slice(slash) : '';

  if (!tail || tail.length > max / 2) return clean.slice(0, max - 1) + '…';

  return clean.slice(0, max - tail.length - 1) + '…' + tail;
}

export function linkText(l: { url: string; label?: string | null }): string {
  const label = l.label?.trim();
  if (label) return label;
  return linkKind(l.url)?.name ?? cleanUrl(l.url);
}

export function isValidLink(url: string): boolean {
  const parsed = parseLink(url);
  return !!parsed && (parsed.protocol === 'mailto:' || parsed.host.includes('.'));
}

export function dedupeLinks<T extends { url: string }>(links: T[]): T[] {
  const seen = new Set<string>();
  return links.filter((l) => {
    const key = stripSuffix(normalizeUrl(l.url), '/').toLowerCase();

    if (seen.has(key)) return false;
    seen.add(key);

    return true;
  });
}
