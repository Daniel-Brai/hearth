// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { signedInFromCookies, zoneFromCookies } from './request-context';

describe('zoneFromCookies', () => {
  it('falls back to UTC without a cookie or with a zone that does not exist', () => {
    expect(zoneFromCookies(null)).toBe('UTC');
    expect(zoneFromCookies('other=1')).toBe('UTC');
    expect(zoneFromCookies('hearth-tz=Mars%2FOlympus')).toBe('UTC');
  });

  it('reads the zone the browser saved', () => {
    expect(zoneFromCookies('a=1; hearth-tz=Africa%2FLagos')).toBe('Africa/Lagos');
  });
});

describe('signedInFromCookies', () => {
  it('is false without the hint or with anything but the flag', () => {
    expect(signedInFromCookies(null)).toBe(false);
    expect(signedInFromCookies('hearth-tz=UTC')).toBe(false);
    expect(signedInFromCookies('hearth-signed-in=0')).toBe(false);
    expect(signedInFromCookies('x-hearth-signed-in=1')).toBe(false);
  });

  it('reads the flag the browser saved', () => {
    expect(signedInFromCookies('a=1; hearth-signed-in=1; hearth-tz=UTC')).toBe(true);
  });
});
