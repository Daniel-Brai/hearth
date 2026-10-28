import { Skeleton } from '@/design-system';
import { PageMeta } from '@/shell/PageMeta';

export function ClientOnlyFallback() {
  return (
    <>
      <PageMeta title={[]} noindex />
      <main id="main">
        <div className="measure">
          <Skeleton kind="feed" />
        </div>
      </main>
    </>
  );
}
