import { PageMeta } from '@/shell/PageMeta';
import { RouteSkeleton } from '@/shell/RouteSkeleton';

export function ClientOnlyFallback() {
  return (
    <>
      <PageMeta title={[]} noindex />
      <RouteSkeleton />
    </>
  );
}
