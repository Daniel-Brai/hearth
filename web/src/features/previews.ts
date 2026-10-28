import type { LinkPreviewData } from '@/design-system';
import { parseLink, stripSuffix } from '@/domain/links';
import { firstLink } from '@/features/markdown/plain-text';

type Known = { site: string; title: string | null; desc: string; hue: string };

const KNOWN: Record<string, Known> = {
  'elixirforum.com': {
    site: 'Elixir Forum',
    title: null,
    desc: 'The place to talk about Elixir, Phoenix, Nerves and the BEAM.',
    hue: 'violet',
  },
  'github.com': {
    site: 'GitHub',
    title: null,
    desc: 'Releases, changelog and source on GitHub.',
    hue: 'ink',
  },
  'hexdocs.pm': {
    site: 'HexDocs',
    title: null,
    desc: 'Documentation for Elixir and Erlang packages on Hex.',
    hue: 'violet',
  },
};

const titleCase = (s: string) => (s ? s[0]!.toUpperCase() + s.slice(1) : s);

const lastSegment = (path: string): string | null => {
  const last = path.split('/').filter(Boolean).at(-1);

  if (!last) return null;

  const seg = decodeURIComponent(last);

  return stripSuffix(stripSuffix(seg, '.html'), '.htm').replaceAll('-', ' ').replaceAll('_', ' ');
};

function titleFor(host: string, path: string, known: string | null): string {
  if (host === 'github.com') return path.split('/').filter(Boolean).slice(0, 3).join(' / ');
  if (known) return known;

  const segment = lastSegment(path);

  return segment ? titleCase(segment) : host;
}

export function previewFor(url: string): LinkPreviewData | null {
  const parsed = parseLink(url);

  if (!parsed) return null;

  const { host, path } = parsed;

  const k = KNOWN[host] ?? {
    site: host,
    title: null,
    desc: "Title, description and image come from the page's Open Graph tags.",
    hue: 'aqua',
  };

  const title = titleFor(host, path, k.title);

  return { url, site: k.site, title, desc: k.desc, hue: k.hue, letter: k.site[0]!.toUpperCase() };
}

export function firstUrl(text: string): string | null {
  return firstLink(text);
}
