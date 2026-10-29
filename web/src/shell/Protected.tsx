import { Suspense } from 'react';
import { Outlet } from 'react-router';
import { RequireAuth } from './RequireAuth';
import { RouteSkeleton } from './RouteSkeleton';

export function PublicPages() {
  return (
    <Suspense fallback={<RouteSkeleton />}>
      <Outlet />
    </Suspense>
  );
}

export function Protected() {
  return (
    <RequireAuth>
      <Suspense fallback={<RouteSkeleton />}>
        <Outlet />
      </Suspense>
    </RequireAuth>
  );
}
