import { useState } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router';
import { Badge, ButtonLink, Icon, Measure, Segmented, Select } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { canDo, community, hasQueue, modCids, queueCountIn } from '@/domain/selectors';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { routes } from '@/runtime/routes';
import { PageHeader } from '@/shell/PageHeader';
import { BansTab } from './BansTab';
import { LogTab } from './LogTab';
import { QueueTab } from './QueueTab';
import './ModerationPage.css';

type Tab = 'queue' | 'log' | 'bans';

const parseTab = (value: string | null): Tab =>
  value === 'log' || value === 'bans' ? value : 'queue';

export function ModerationPage() {
  const { community: cid } = useParams();

  if (!cid) return <ErrorPage code={404} />;

  return <ModerationScreen cid={cid} />;
}

function ModerationScreen({ cid }: { readonly cid: string }) {
  const gateway = useGateway();
  const load = useLoad(() => gateway.load.moderation(cid), 'moderation:' + cid);
  const name = useAppState((state) => community(state, cid)?.name ?? null);

  const canModerate = useAppState(
    (state) => canDo(state, cid, 'content.remove') || canDo(state, cid, 'member.ban'),
  );

  if (load.status === 'error') return <ErrorPage code={500} />;
  if (!name) return <ErrorPage code={404} />;
  if (!canModerate) return <ErrorPage code={403} forbidden="moderators" />;

  return <ModerationView key={cid} cid={cid} name={name} />;
}

function ModerationView({ cid, name }: { readonly cid: string; readonly name: string }) {
  const withQueue = useAppState((state) => hasQueue(state, cid));
  const canRoles = useAppState((state) => canDo(state, cid, 'role.update'));

  return (
    <>
      <PageHeader
        label="Moderation"
        eyebrow={name}
        title="Moderation"
        actions={canRoles ? <RolesLink cid={cid} /> : null}
      />

      <main id="main">
        <Measure className="grid gap-4">
          <ModerationTabs cid={cid} name={name} withQueue={withQueue} />
        </Measure>
      </main>
    </>
  );
}

function RolesLink({ cid }: { readonly cid: string }) {
  return (
    <ButtonLink to={routes.roles(cid)} circle size="small" aria-label="Roles" data-tip="Roles">
      <Icon name="roles" />
    </ButtonLink>
  );
}

function ModerationTabs({
  cid,
  name,
  withQueue,
}: {
  readonly cid: string;
  readonly name: string;
  readonly withQueue: boolean;
}) {
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const [picked, setPicked] = useState<Tab>(() => parseTab(params.get('tab')));

  const waiting = useAppState((state) => queueCountIn(state, cid));
  const banned = useAppState((state) => state.bans.filter((b) => b.c === cid).length);
  const canBan = useAppState((state) => canDo(state, cid, 'member.ban'));
  const canRemove = useAppState((state) => canDo(state, cid, 'content.remove'));
  const cids = useAppState(modCids);
  const names = useAppState((state) => cids.map((k) => community(state, k)?.name ?? k));

  const queue = withQueue && canRemove;

  const tab: Tab =
    (!queue && picked === 'queue') || (!canBan && picked === 'bans') ? 'log' : picked;

  const communities = cids.map((value, i) => ({ value, label: names[i] ?? value }));

  return (
    <>
      <div className="flex items-center justify-center gap-3 flex-wrap">
        <Segmented
          name="modtab"
          label="Moderation sections"
          value={tab}
          onChange={setPicked}
          options={[
            ...(queue
              ? [
                  {
                    value: 'queue' as const,
                    label: <>Queue{waiting ? <Badge red count={waiting} /> : null}</>,
                  },
                ]
              : []),
            { value: 'log', label: 'Public log' },
            ...(canBan
              ? [
                  {
                    value: 'bans' as const,
                    label: <>Banned{banned ? <Badge count={banned} /> : null}</>,
                  },
                ]
              : []),
          ]}
        />

        {communities.length > 1 ? (
          <Select
            value={cid}
            options={communities}
            onChange={(next) => void navigate(routes.moderation(next))}
            label="Community"
          />
        ) : null}
      </div>

      {tab === 'queue' ? <QueueTab cid={cid} name={name} /> : null}
      {tab === 'log' ? <LogTab cid={cid} name={name} withQueue={withQueue} /> : null}
      {tab === 'bans' ? <BansTab cid={cid} name={name} canBan={canBan} /> : null}
    </>
  );
}
