import { useParams } from 'react-router';
import { Measure } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { community, hasQueue } from '@/domain/selectors';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { PageHeader } from '@/shell/PageHeader';
import { LogTab } from './LogTab';
import './ModerationPage.css';

/** Rendered on the server but kept out of search */
export function PublicLogPage() {
  const { community: cid } = useParams();

  if (!cid) return <ErrorPage code={404} />;

  return <PublicLog cid={cid} />;
}

function PublicLog({ cid }: { readonly cid: string }) {
  const gateway = useGateway();
  const load = useLoad(() => gateway.load.moderationLog(cid), 'moderation-log:' + cid);
  const name = useAppState((state) => community(state, cid)?.name ?? null);
  const withQueue = useAppState((state) => hasQueue(state, cid));

  if (load.status === 'error' || !name) return <ErrorPage code={404} />;

  return (
    <>
      <PageHeader label="the public log" eyebrow={name} title="Public log" noindex />

      <main id="main">
        <Measure className="grid gap-4">
          <LogTab cid={cid} name={name} withQueue={withQueue} publicView />
        </Measure>
      </main>
    </>
  );
}
