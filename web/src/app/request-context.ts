import { createContext, useContext, useSyncExternalStore } from 'react';
import { onServer } from '@/data/env';

export type RequestInfo = {
  readonly origin: string;
  readonly zone: string;
  readonly signedIn: boolean;
  readonly setStatus: (status: number) => void;
};

export const RequestContext = createContext<RequestInfo | null>(null);

export function useOrigin(): string {
  const request = useContext(RequestContext);

  return request?.origin ?? '';
}

export function useResponseStatus(status: number) {
  const request = useContext(RequestContext);

  if (onServer) request?.setStatus(status);
}

const never = () => () => undefined;

export function useHydrated(): boolean {
  return useSyncExternalStore(
    never,
    () => true,
    () => false,
  );
}

// The browser's own zone once hydration ends
export function useDisplayZone(): string | undefined {
  const request = useContext(RequestContext);
  const hydrated = useHydrated();

  return hydrated ? undefined : (request?.zone ?? 'UTC');
}

const SIGNED_IN_COOKIE = 'hearth-signed-in';

const ZONE_COOKIE = 'hearth-tz';

/** Saves this browser's time zone so the server writes its next screens in local time */
export function rememberZone() {
  const zone = Intl.DateTimeFormat().resolvedOptions().timeZone;
  document.cookie = `${ZONE_COOKIE}=${encodeURIComponent(zone)}; path=/; max-age=31536000; samesite=lax`;
}

/**
 * Marks this browser as signed in so the server draws the app frame while the session restores.
 * It holds no token and decides no access, since the API and RequireAuth still do
 */
export function rememberSignedIn(signedIn: boolean) {
  if (typeof document === 'undefined') return;

  document.cookie = signedIn
    ? `${SIGNED_IN_COOKIE}=1; path=/; max-age=31536000; samesite=lax`
    : `${SIGNED_IN_COOKIE}=; path=/; max-age=0; samesite=lax`;
}

export function signedInFromCookies(cookies: string | null): boolean {
  return cookies?.split(';').some((part) => part.trim() === SIGNED_IN_COOKIE + '=1') ?? false;
}

export function zoneFromCookies(cookies: string | null): string {
  const raw = cookies
    ?.split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith(ZONE_COOKIE + '='))
    ?.slice(ZONE_COOKIE.length + 1);

  if (!raw) return 'UTC';

  try {
    const zone = decodeURIComponent(raw);
    new Intl.DateTimeFormat('en-US', { timeZone: zone });
    return zone;
  } catch {
    return 'UTC';
  }
}

/** Whether the browser said it was signed in, the same on the server and at hydration */
export function useSignedInHint(): boolean {
  return useContext(RequestContext)?.signedIn ?? false;
}
