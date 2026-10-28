import { useState } from 'react';
import { EmptyState, Measure } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { isInstanceAdmin } from '@/domain/selectors';
import type { QueueItem } from '@/domain/types';
import { QueueCard } from '@/pages/moderation/QueueTab';
import { DEFAULT_REASON } from '@/pages/moderation/queue-reasons';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { useUi } from '@/runtime/ui-store';
import { PageHeader } from '@/shell/PageHeader';
import '@/pages/moderation/ModerationPage.css';

export function InstanceReportsPage() {
  const admin = useAppState((state) => isInstanceAdmin(state));

  if (!admin) return <ErrorPage code={403} forbidden="admins" />;

  return <InstanceReports />;
}

function InstanceReports() {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const load = useLoad(() => gateway.load.reportedMessages(), 'reported-messages');
  const [reasons, setReasons] = useState<Record<string, string>>({});

  const items = useAppState((state) =>
    state.queue.filter((x) => x.c === 'dm' && x.status === 'pending'),
  );

  if (load.status === 'error') return <ErrorPage code={500} />;

  const reasonFor = (x: QueueItem) => reasons[x.id] ?? DEFAULT_REASON;

  const keep = (x: QueueItem) =>
    void gateway.moderation
      .keep(x.id)
      .then((r) => flash(r.ok ? 'Kept. Nothing was removed.' : r.error));

  const remove = (x: QueueItem) =>
    void gateway.moderation
      .remove(x.id, reasonFor(x))
      .then((r) => flash(r.ok ? 'Removed' : r.error));

  return (
    <>
      <PageHeader label="reported messages" eyebrow="Instance" title="Reported messages" />

      <main id="main">
        <Measure className="grid gap-3" id="instance-reports">
          <p className="subtle small">
            Direct messages belong to no community, so reports about them come to the instance's
            admins. Removing one takes it out of the conversation for both people.
          </p>

          {items.map((x) => (
            <QueueCard
              key={x.id}
              item={x}
              reason={reasonFor(x)}
              onReason={(r) => setReasons((all) => ({ ...all, [x.id]: r }))}
              onKeep={() => keep(x)}
              onRemove={() => remove(x)}
            />
          ))}

          {!items.length ? (
            <EmptyState
              art="queue"
              title="No reported messages"
              text="When someone reports a direct message, it shows up here for you to keep or remove."
            />
          ) : null}
        </Measure>
      </main>
    </>
  );
}
