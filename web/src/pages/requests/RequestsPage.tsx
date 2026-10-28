import { useState } from 'react';
import { useNavigate } from 'react-router';
import {
  Badge,
  Button,
  ButtonLink,
  CommunityMark,
  EmptyState,
  Icon,
  Link,
  Measure,
  Pill,
  Segmented,
  type IconName,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import {
  creationMode,
  displayName,
  isInstanceAdmin,
  shortName,
  templateOf,
} from '@/domain/selectors';
import type { CommunityRequest } from '@/domain/types';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PageHeader } from '@/shell/PageHeader';
import { PersonAvatar } from '@/shell/people';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import './RequestsPage.css';

type Tab = 'waiting' | 'decided';

const MODE_NOTES = {
  admins:
    'New requests are off: only instance admins start communities right now. Anything already waiting is below.',
  anyone:
    'Anyone can start a community right now, so nobody needs to ask. Anything already waiting is below.',
} as const;

const age = (when: string) => (when === 'now' ? 'just now' : when + ' ago');

export function RequestsPage() {
  const gateway = useGateway();
  const admin = useAppState((state) => isInstanceAdmin(state));

  useLoad(() => gateway.load.requests(), 'requests');

  if (!admin) return <ErrorPage code={403} forbidden="admins" />;

  return <RequestsView />;
}

function RequestsView() {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);
  const ask = useUi((s) => s.ask);

  const [tab, setTab] = useState<Tab>('waiting');

  const mode = useAppState((state) => creationMode(state));

  const waiting = useAppState((state) =>
    state.communityRequests.filter((r) => r.status === 'pending'),
  );

  const decided = useAppState((state) =>
    state.communityRequests.filter((r) => r.status !== 'pending'),
  );

  const names = useAppState((state) =>
    Object.fromEntries(state.communityRequests.map((r) => [r.by, shortName(state, r.by)])),
  );

  const modeNote = mode === 'request' ? null : MODE_NOTES[mode];
  const list = tab === 'waiting' ? waiting : decided;

  const approve = async (r: CommunityRequest) => {
    const result = await gateway.communities.decideRequest(r.id, 'approved');

    if (!result.ok) {
      flash(result.error);
      return;
    }

    flash(
      r.name + ' is created. ' + (names[r.by] ?? 'The owner') + ' is its Owner and has been told.',
    );

    if (result.value.community) void navigate(routes.community(result.value.community));
  };

  const decline = (r: CommunityRequest) =>
    ask({
      title: 'Decline ' + r.name + '?',
      body:
        (names[r.by] ?? 'They') + " gets a short note that it wasn't approved. They can ask again.",
      action: 'Decline',
      onConfirm: async () => {
        const result = await gateway.communities.decideRequest(r.id, 'declined');
        flash(result.ok ? 'Declined' : result.error);
      },
    });

  return (
    <>
      <PageHeader label="community requests" eyebrow="Instance" title="Community requests" />

      <main id="main">
        <Measure narrow className="grid gap-4">
          {modeNote ? (
            <p className="mod-note" id="requests-mode-note">
              <Icon name="shield" />
              <span>{modeNote}</span>
              <ButtonLink to={routes.settingsInstance} size="tiny">
                Change
              </ButtonLink>
            </p>
          ) : null}

          <div className="flex justify-center">
            <Segmented<Tab>
              name="rqtab"
              label="Requests"
              value={tab}
              onChange={setTab}
              options={[
                {
                  value: 'waiting',
                  label: (
                    <>
                      Waiting
                      {waiting.length ? <Badge red count={waiting.length} /> : null}
                    </>
                  ),
                },
                { value: 'decided', label: 'Decided' },
              ]}
            />
          </div>

          <section className="grid gap-3" id="requests-list">
            {list.map((r) => (
              <RequestCard key={r.id} request={r} onApprove={approve} onDecline={decline} />
            ))}

            {tab === 'waiting' && !waiting.length ? (
              <EmptyState
                art="queue"
                title="No requests waiting"
                text="When someone asks for a community, it shows up here for you to approve or decline."
              />
            ) : null}

            {tab === 'decided' && !decided.length ? (
              <EmptyState
                art="queue"
                title="Nothing decided yet"
                text="Requests you approve or decline move here."
              />
            ) : null}
          </section>
        </Measure>
      </main>
    </>
  );
}

type RequestCardProps = {
  readonly request: CommunityRequest;
  readonly onApprove: (r: CommunityRequest) => void;
  readonly onDecline: (r: CommunityRequest) => void;
};

function RequestCard({ request: r, onApprove, onDecline }: RequestCardProps) {
  const asker = useAppState((state) => ({
    name: displayName(state, r.by),
    username: state.people[r.by]?.username ?? null,
  }));

  const template = useAppState((state) => templateOf(state, r.template));
  const approved = r.status === 'approved';

  const verdict = approved
    ? { label: 'Approved', tint: 'green' }
    : { label: 'Declined', tint: null };

  return (
    <article className="panel request-card" id={'request-' + r.id}>
      <div className="request-card__head">
        <CommunityMark hue={r.hue} letter={r.name[0] ?? '?'} size="3rem" />

        <div className="grid" style={{ minInlineSize: 0 }}>
          <strong className="request-card__name truncate">{r.name}</strong>
          <span className="small subtle">{r.tagline || 'No tagline yet'}</span>
        </div>

        {r.status !== 'pending' ? <Pill tint={verdict.tint}>{verdict.label}</Pill> : null}
      </div>

      <div className="request-card__facts">
        {template ? (
          <span className="icon-text">
            <Icon name={template.icon as IconName} />
            <span>{template.label}</span>
          </span>
        ) : null}

        <span className="icon-text">
          <Icon name={r.visibility === 'invite' ? 'lock' : 'globe'} />
          <span>{r.visibility === 'invite' ? 'Invite only' : 'Public and indexed'}</span>
        </span>
      </div>

      {r.note ? <blockquote className="request-card__note">{r.note}</blockquote> : null}

      <div className="request-card__foot">
        {asker.username ? (
          <Link
            className="flex items-center gap-2 small"
            to={routes.profile(asker.username)}
            style={{ minInlineSize: 0 }}
          >
            <PersonAvatar id={r.by} size="xs" />
            <span className="truncate">
              <strong>{asker.name}</strong>{' '}
              <span className="subtle">
                asked {age(r.age)}
                {r.decided ? ` · ${verdict.label.toLowerCase()} ${age(r.decided)}` : null}
              </span>
            </span>
          </Link>
        ) : null}

        {r.status === 'pending' ? (
          <div className="flex items-center gap-2">
            <Button size="small" onClick={() => onDecline(r)}>
              Decline
            </Button>

            <Button size="small" variant="reversed" onClick={() => onApprove(r)}>
              <Icon name="check" />
              Approve
            </Button>
          </div>
        ) : null}

        {approved && r.communityId ? (
          <ButtonLink to={routes.community(r.communityId)} size="small">
            Open
            <span style={{ display: 'inline-grid', rotate: '-90deg' }}>
              <Icon name="chevron" />
            </span>
          </ButtonLink>
        ) : null}
      </div>
    </article>
  );
}
