// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { blurUrl } from './blur';

const hash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';

describe('blurUrl', () => {
  it('returns nothing for a hash that is not a blurhash', () => {
    expect(blurUrl('nope')).toBeNull();
  });

  it('makes a small image the browser can scale up', () => {
    expect(blurUrl(hash, 400, 300)).toMatch(/^data:image\/bmp;base64,Qk/);
  });

  it('gives the same image each time so the server and browser agree', () => {
    expect(blurUrl(hash, 400, 300)).toBe(blurUrl(hash, 400, 300));
  });
});
