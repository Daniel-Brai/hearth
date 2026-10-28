import type { Session } from '@/generated/schemas';
import { onServer, serverEnv } from '@/data/env';
import { accessToken, setAccessToken } from './session-token';
import { apiHeaders } from './version';

// The server render reaches the API on an internal address that browsers never see
export const apiBaseUrl = (): string =>
  onServer
    ? (serverEnv('API_INTERNAL_URL') ?? import.meta.env.VITE_API_URL ?? 'http://localhost:4000')
    : (import.meta.env.VITE_API_URL ?? window.location.origin);

export type ErrorType<E> = { status: number; data: E };
export type BodyType<B> = B;

type Answer = { data: unknown; status: number; headers: Headers };

export type Refreshed = Session | 'signed-out' | 'unreachable';

let refreshing: Promise<Refreshed> | null = null;

// Each cookie works once and tabs share it so tabs take turns through a Web Lock
export function refreshSession(): Promise<Refreshed> {
  refreshing ??= inTurn(requestRefresh).finally(() => (refreshing = null));

  return refreshing;
}

function inTurn(run: () => Promise<Refreshed>): Promise<Refreshed> {
  if (typeof navigator === 'undefined' || !navigator.locks) return run();

  return navigator.locks.request('hearth-refresh', run);
}

async function requestRefresh(): Promise<Refreshed> {
  let response: Response;

  try {
    response = await fetch(apiBaseUrl() + '/api/auth/refresh', {
      method: 'POST',
      credentials: 'include',
      headers: apiHeaders(false),
    });
  } catch (error) {
    if (error instanceof TypeError) return 'unreachable';
    throw error;
  }

  // Only the server saying no ends the session and an outage doesn't
  if (response.status >= 500) return 'unreachable';

  // 204 means there was no cookie to refresh so nobody is signed in here
  if (!response.ok || response.status === 204) {
    setAccessToken(null);
    return 'signed-out';
  }

  const session = (await response.json()) as Session;

  setAccessToken(session.access_token);

  return session;
}

function send(url: string, init: RequestInit): Promise<Response> {
  const token = accessToken();

  return fetch(apiBaseUrl() + url, {
    ...init,
    credentials: 'include',
    headers: {
      ...apiHeaders(init.body != null),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
  });
}

async function read(response: Response): Promise<Answer> {
  const answer: Answer = { data: null, status: response.status, headers: response.headers };
  const json = response.headers.get('content-type')?.includes('application/json') ?? false;

  if (!json) return answer;

  const text = await response.text();

  if (text) answer.data = JSON.parse(text) as unknown;

  return answer;
}

const expiredToken = (answer: Answer) =>
  answer.status === 401 &&
  typeof answer.data === 'object' &&
  answer.data !== null &&
  'code' in answer.data &&
  answer.data.code === 'invalid_token';

export async function customFetch<T>(url: string, init: RequestInit = {}): Promise<T> {
  let answer = await read(await send(url, init));

  if (expiredToken(answer) && typeof (await refreshSession()) === 'object') {
    answer = await read(await send(url, init));
  }

  return answer as T;
}
