// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { cleanUrl, dedupeLinks, isValidLink, linkKind, linkText, normalizeUrl } from './links';

describe('linkKind', () => {
  it('recognises common sites from the host, ignoring www and the scheme', () => {
    expect(linkKind('github.com/Daniel-Brai')?.name).toBe('GitHub');
    expect(linkKind('https://www.youtube.com/@adapark')?.icon).toBe('youtube');
    expect(linkKind('https://github.com/sponsors/someone')?.name).toBe('GitHub Sponsors');
  });

  it('recognises writing sites, blogs on their subdomains too', () => {
    expect(linkKind('medium.com/@ada')).toEqual({ name: 'Medium', icon: 'medium' });
    expect(linkKind('ada.medium.com')).toEqual({ name: 'Medium', icon: 'medium' });
    expect(linkKind('https://dev.to/ada')).toEqual({ name: 'DEV', icon: 'devto' });
    expect(linkKind('ada.hashnode.dev')).toEqual({ name: 'Hashnode', icon: 'hashnode' });
  });

  it('returns null for an unknown site or an address that cannot be parsed', () => {
    expect(linkKind('https://adapark.dev')).toBeNull();
    expect(linkKind('not a link')).toBeNull();
  });
});

describe('labels and validity', () => {
  it('prefers a typed label, then the site, then the cleaned address', () => {
    expect(linkText({ url: 'https://github.com/x', label: 'Code' })).toBe('Code');
    expect(linkText({ url: 'https://github.com/x', label: null })).toBe('GitHub');
    expect(linkText({ url: 'https://www.adapark.dev/', label: null })).toBe('adapark.dev');
  });

  it('accepts bare hosts and mailto, rejects a word', () => {
    expect(isValidLink('adapark.dev')).toBe(true);
    expect(isValidLink('mailto:a@b.co')).toBe(true);
    expect(isValidLink('hello')).toBe(false);
  });

  it('normalises and dedupes by address', () => {
    expect(normalizeUrl('adapark.dev')).toBe('https://adapark.dev');
    expect(cleanUrl('https://www.adapark.dev/talks/')).toBe('adapark.dev/talks');
    expect(
      dedupeLinks([{ url: 'https://a.dev' }, { url: 'a.dev/' }, { url: 'https://b.dev' }]).map(
        (l) => l.url,
      ),
    ).toEqual(['https://a.dev', 'https://b.dev']);
  });
});
