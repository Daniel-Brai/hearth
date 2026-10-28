import { useNavigate } from 'react-router';
import { Button, CommunityMark, EmptyState, Measure, Pill } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { community, displayName, roleName } from '@/domain/selectors';
import type { MyInvite } from '@/domain/types';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PageHeader } from '@/shell/PageHeader';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import '@/pages/requests/RequestsPage.css';

export function MyInvitesPage() {
  const gateway = useGateway();
  const load = useLoad(() => gateway.load.myInvites(), 'my-invites');
  const invites = useAppState((state) => state.invites.mine);

  if (load.status === 'error') return <ErrorPage code="offline" />;

  return (
    <>
      <PageHeader label="Invites" eyebrow="For you" title="Invites" />

      <main id="main">
        <Measure narrow className="grid gap-3" id="my-invites">
          {invites.map((invite) => (
            <InviteCard key={invite.id} invite={invite} />
          ))}

          {!invites.length ? (
            <EmptyState
              art="queue"
              title="No invites waiting"
              text="When someone invites you to a community, it shows up here for you to join or turn down."
            />
          ) : null}
        </Measure>
      </main>
    </>
  );
}

function InviteCard({ invite }: { readonly invite: MyInvite }) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);
  const openDialog = useUi((s) => s.openDialog);

  const view = useAppState((state) => {
    const c = community(state, invite.c);

    return {
      name: c?.name ?? 'A community',
      tagline: c?.tagline || null,
      hue: c?.hue ?? 'ink',
      letter: c?.letter ?? '?',
      inviter: invite.by ? displayName(state, invite.by) : null,
      role: roleName(state, invite.c, invite.role),
    };
  });

  const join = async () => {
    const r = await gateway.session.acceptInvite(invite.code);

    if (!r.ok) return flash(r.error);

    flash('You joined ' + view.name);
    void navigate(routes.community(r.value.community));
    openDialog('welcome', { community: r.value.community });
  };

  const decline = async () => {
    const r = await gateway.invites.decline(invite.id);
    flash(r.ok ? 'Invite turned down' : r.error);
  };

  return (
    <article className="panel request-card" id={'my-invite-' + invite.id}>
      <div className="request-card__head">
        <CommunityMark hue={view.hue} letter={view.letter} size="3rem" />

        <div className="grid" style={{ minInlineSize: 0 }}>
          <strong className="request-card__name truncate">{view.name}</strong>
          <span className="small subtle">{view.tagline ?? 'No tagline yet'}</span>
        </div>

        <Pill>{view.role}</Pill>
      </div>

      <div className="request-card__foot">
        <span className="small subtle">
          {view.inviter ? `${view.inviter} invited you` : 'You were invited'} · {invite.age}
        </span>

        <div className="flex items-center gap-2">
          <Button size="small" variant="borderless" onClick={() => void decline()}>
            Decline
          </Button>
          <Button size="small" variant="reversed" onClick={() => void join()}>
            Join
          </Button>
        </div>
      </div>
    </article>
  );
}
