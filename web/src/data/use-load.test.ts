// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { ok } from './gateway';
import { LoadCache } from './use-load';

describe('LoadCache', () => {
  it('hands on only the keys that finished', async () => {
    const cache = new LoadCache();
    const done = cache.start('post:p1', () => Promise.resolve(ok(undefined)));

    cache.start('post:p2', () => new Promise(() => undefined));

    await done.promise;

    expect(cache.readyKeys()).toEqual(['post:p1']);
  });

  it('treats seeded keys as ready but due for a refresh', () => {
    const cache = new LoadCache();
    cache.seed(['community:elixir']);

    expect(cache.get('community:elixir')?.state).toEqual({ status: 'ready', at: 0 });
  });
});

describe('LoadCache errors', () => {
  it('lists what each failed load said', async () => {
    const cache = new LoadCache();
    const done = cache.start('post:p1', () => Promise.resolve({ ok: false, error: 'Gone' }));

    await done.promise;

    expect(cache.errors()).toEqual(['Gone']);
  });
});
