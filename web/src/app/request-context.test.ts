// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { zoneFromCookies } from './request-context';

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
