import { createContext, useContext, useSyncExternalStore } from 'react';
import { onServer } from '@/data/env';

export type RequestInfo = {
  readonly origin: string;
  readonly zone: string;
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

export const ZONE_COOKIE = 'hearth-tz';

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
