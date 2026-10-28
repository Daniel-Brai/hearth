import { Suspense } from 'react';
import { Outlet } from 'react-router';
import { Skeleton } from '@/design-system';
import { RequireAuth } from './RequireAuth';

function Loading() {
  return (
    <main id="main">
      <div className="measure">
        <Skeleton kind="feed" />
      </div>
    </main>
  );
}

export function PublicPages() {
  return (
    <Suspense fallback={<Loading />}>
      <Outlet />
    </Suspense>
  );
}

export function Protected() {
  return (
    <RequireAuth>
      <Suspense fallback={<Loading />}>
        <Outlet />
      </Suspense>
    </RequireAuth>
  );
}
