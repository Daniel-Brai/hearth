import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { customFetch, refreshSession } from './custom-fetch';
import { accessToken, setAccessToken } from './session-token';

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

const session = (token: string) => ({
  access_token: token,
  token_type: 'Bearer',
  expires_in: 900,
  user: { id: 'u1' },
});

let calls: { url: string; init: RequestInit }[];

const stubFetch = (...answers: Response[]) => {
  calls = [];
  vi.stubGlobal(
    'fetch',
    vi.fn((url: string, init: RequestInit) => {
      calls.push({ url, init });
      return Promise.resolve(answers.shift() ?? json(500, {}));
    }),
  );
};

const header = (i: number, name: string) =>
  (calls[i]!.init.headers as Record<string, string>)[name];

beforeEach(() => setAccessToken(null));

afterEach(() => vi.unstubAllGlobals());

describe('customFetch', () => {
  it('fails without throwing on an error answer', async () => {
    stubFetch(json(404, { message: 'Not Found' }));

    await expect(customFetch('/api/posts/x')).resolves.toMatchObject({
      status: 404,
      data: { message: 'Not Found' },
    });
  });

  it('signs out when the token ran out and refreshing fails', async () => {
    setAccessToken('old');
    stubFetch(json(401, { code: 'invalid_token' }), json(401, { code: 'invalid_refresh' }));

    await expect(customFetch('/api/auth/me')).resolves.toMatchObject({ status: 401 });
    expect(accessToken()).toBeNull();
  });

  it('does not refresh a request that had no token', async () => {
    stubFetch(json(401, { code: 'missing_token' }));

    await customFetch('/api/auth/me');

    expect(calls).toHaveLength(1);
  });

  it('sends the version header and the access token', async () => {
    setAccessToken('abc');
    stubFetch(json(200, { ok: true }));

    await customFetch('/api/instance');

    expect(header(0, 'Authorization')).toBe('Bearer abc');
    expect(header(0, 'Hearth-Version')).toBeTruthy();
    expect(calls[0]!.init.credentials).toBe('include');
  });

  it('refreshes once and retries when the token ran out', async () => {
    setAccessToken('old');

    stubFetch(
      json(401, { code: 'invalid_token' }),
      json(200, session('new')),
      json(200, { id: 'u1' }),
    );

    await expect(customFetch('/api/auth/me')).resolves.toMatchObject({
      status: 200,
      data: { id: 'u1' },
    });

    expect(calls[1]!.url).toContain('/api/auth/refresh');
    expect(header(2, 'Authorization')).toBe('Bearer new');
  });
});

describe('refreshSession', () => {
  it('shares one refresh between calls made at once', async () => {
    stubFetch(json(200, session('one')));

    const [a, b] = await Promise.all([refreshSession(), refreshSession()]);

    expect(calls).toHaveLength(1);
    expect(a).toMatchObject({ access_token: 'one' });
    expect(b).toBe(a);
  });

  it('signs out when the server refuses the cookie', async () => {
    stubFetch(json(401, { message: 'Unauthorized' }));

    expect(await refreshSession()).toBe('signed-out');
  });

  it('is signed out when there is no cookie to refresh', async () => {
    stubFetch(new Response(null, { status: 204 }));

    expect(await refreshSession()).toBe('signed-out');
  });

  it('keeps the session when the server is down', async () => {
    stubFetch(json(503, { message: 'Service Unavailable' }));

    expect(await refreshSession()).toBe('unreachable');
  });
});
