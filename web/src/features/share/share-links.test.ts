import { describe, expect, it } from 'vitest';
import { shareNetworks, shareUrl } from './share-links';

const target = {
  url: 'https://hearth.example/c/elixir/p/p1-genserver-state',
  title: 'GenServer state & restarts',
  text: 'Keep it in ETS',
};

const href = (id: string) => shareNetworks(target).find((n) => n.id === id)!.href;
const params = (id: string) => new URL(href(id)).searchParams;

describe('shareUrl', () => {
  it('makes an app path absolute on the site', () => {
    expect(shareUrl('/c/elixir', 'https://hearth.example')).toBe('https://hearth.example/c/elixir');
  });
});

describe('shareNetworks', () => {
  it('offers each network once', () => {
    expect(shareNetworks(target).map((n) => n.id)).toEqual([
      'x',
      'linkedin',
      'bluesky',
      'reddit',
      'whatsapp',
      'email',
    ]);
  });

  it('builds X and Reddit links with the title and address apart', () => {
    expect(params('x').get('text')).toBe(target.title);
    expect(params('x').get('url')).toBe(target.url);
    expect(params('reddit').get('title')).toBe(target.title);
    expect(params('reddit').get('url')).toBe(target.url);
  });

  it('builds LinkedIn from the address alone', () => {
    expect(params('linkedin').get('url')).toBe(target.url);
  });

  it('puts the title and address in one line for Bluesky and WhatsApp', () => {
    expect(params('bluesky').get('text')).toBe(`${target.title} ${target.url}`);
    expect(params('whatsapp').get('text')).toBe(`${target.title} ${target.url}`);
  });

  it('spells spaces out in the email link', () => {
    expect(href('email')).toBe(
      `mailto:?subject=${encodeURIComponent(target.title)}&body=${encodeURIComponent(`${target.text}\n\n${target.url}`)}`,
    );
    expect(href('email')).not.toContain('+');
  });
});
