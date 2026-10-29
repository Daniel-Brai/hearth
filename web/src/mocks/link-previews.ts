import type { LinkPreview } from '@/domain/types';
import { parseLink } from '@/domain/links';

const segments = (path: string) => path.split('/').filter(Boolean);

function github(url: string, path: string): LinkPreview {
  const [owner = 'github', repo] = segments(path);

  if (!repo) {
    return {
      url,
      site: 'GitHub',
      title: `${owner} - Overview`,
      desc: `${owner} has 35 repositories available. Follow their code on GitHub.`,
      image: `https://github.com/${owner}.png`,
    };
  }

  return {
    url,
    site: 'GitHub',
    title: `GitHub - ${owner}/${repo}`,
    desc: `Contribute to ${owner}/${repo} development by creating an account on GitHub.`,
    image: `https://opengraph.githubassets.com/1/${owner}/${repo}`,
  };
}

function hexdocs(url: string, path: string): LinkPreview {
  const [pkg = 'hexdocs', page] = segments(path);
  const name = page ? page.replace(/\.html?$/, '') : pkg;

  return {
    url,
    site: 'HexDocs',
    title: `${name} — ${pkg}`,
    desc: `Documentation for ${pkg} on Hex.`,
    image: null,
  };
}

// What the server would read from each page's Open Graph tags, for the mock data only
export function mockLinkPreview(url: string): LinkPreview | null {
  const parsed = parseLink(url);

  if (!parsed) return null;

  const { host, path } = parsed;

  if (host === 'github.com') return github(url, path);
  if (host === 'hexdocs.pm') return hexdocs(url, path);
  if (host === 'elixirforum.com')
    return {
      url,
      site: 'Elixir Programming Language Forum',
      title: 'Elixir Forum',
      desc: 'The place to talk about Elixir, Phoenix, Nerves and the BEAM.',
      image: null,
    };

  return null;
}
