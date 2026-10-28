import { useEffect, useMemo } from 'react';
import { useLocation, useNavigationType } from 'react-router';
import { useHydrated } from '@/app/request-context';
import { peekVisit, recordVisit, type TrailEntry } from '@/runtime/trail';

/** The trail lives in session storage, which the server cannot read */
export function useTrail(label: string): TrailEntry | null {
  const hydrated = useHydrated();
  const { pathname, search } = useLocation();
  const navigation = useNavigationType();
  const href = pathname + search;
  const isHome = pathname === '/';
  const replaced = navigation === 'REPLACE';

  const from = useMemo(
    () => peekVisit(href, label, isHome, replaced),
    [href, label, isHome, replaced],
  );

  useEffect(() => {
    recordVisit(href, label, isHome, replaced);
  }, [href, label, isHome, replaced]);

  return hydrated ? from : null;
}
