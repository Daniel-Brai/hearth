import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router';
import { routes } from '@/runtime/routes';
import { useSignedIn } from './use-signed-in';

export function RequireAuth({ children }: { readonly children: ReactNode }) {
  const signedIn = useSignedIn();
  const location = useLocation();

  if (!signedIn) {
    const next = location.pathname + location.search;
    return (
      <Navigate
        replace
        to={routes.signIn + (next !== '/' ? '?next=' + encodeURIComponent(next) : '')}
      />
    );
  }

  return children;
}
