// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { idFromSegment, isPublicPath, slugify } from './routes';

describe('slugify', () => {
  it('returns empty if no latin letters', () => {
    expect(slugify('東京')).toBe('');
  });

  it('caps length at 60', () => {
    const slug = slugify('word '.repeat(40));

    expect(slug.length).toBeLessThanOrEqual(60);
    expect(slug.startsWith('-') || slug.endsWith('-')).toBe(false);
  });

  it('joins words with dashes', () => {
    expect(slugify('  Café Crème: the Ünïcode test!! ')).toBe('cafe-creme-the-unicode-test');
    expect(slugify('Straße & Smørrebrød')).toBe('strasse-smorrebrod');
  });
});

describe('idFromSegment', () => {
  const id = '0192f7a8-3c4d-7e5f-8a9b-0c1d2e3f4a5b';

  it('returns null if empty', () => {
    expect(idFromSegment(undefined)).toBeNull();
    expect(idFromSegment('')).toBeNull();
  });

  it('ends at first dash if not a uuid', () => {
    expect(idFromSegment('p1-morphing-questions')).toBe('p1');
    expect(idFromSegment(`${id}x`)).toBe('0192f7a8');
    expect(idFromSegment('zzzzzzzz-3c4d-7e5f-8a9b-0c1d2e3f4a5b')).toBe('zzzzzzzz');
  });

  it('reads uuid', () => {
    expect(idFromSegment(id)).toBe(id);
    expect(idFromSegment(`${id}-an-old-title`)).toBe(id);
  });

  it('lowercases uuid', () => {
    expect(idFromSegment(id.toUpperCase())).toBe(id);
  });
});

describe('isPublicPath', () => {
  it('is false for screens that need an account', () => {
    expect(isPublicPath('/settings/profile')).toBe(false);
    expect(isPublicPath('/c/elixir/chat/general')).toBe(false);
    expect(isPublicPath('/c/elixir/voice/office-hours')).toBe(false);
    expect(isPublicPath('/c/elixir/moderation')).toBe(false);
    expect(isPublicPath('/people')).toBe(false);
  });

  it('is true for the screens anyone can read, with or without a query', () => {
    expect(isPublicPath('/')).toBe(true);
    expect(isPublicPath('/c/elixir')).toBe(true);
    expect(isPublicPath('/c/elixir/p/p1-some-title?sort=new')).toBe(true);
    expect(isPublicPath('/c/elixir/e/e1')).toBe(true);
    expect(isPublicPath('/u/mira_member')).toBe(true);
    expect(isPublicPath('/c/elixir/log')).toBe(true);
  });
});
