import { Navigate, useNavigate, useParams, useSearchParams } from 'react-router';
import { Button, ButtonLink, CommunityMark, EmptyState, Icon, Link } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { ok } from '@/data/gateway';
import { useLoad } from '@/data/use-load';
import { fmt } from '@/domain/format';
import { community, displayName, roleName } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PersonAvatar } from '@/shell/people';
import { AuthLogo } from '@/pages/signin/AuthLogo';
import { PageMeta } from '@/shell/PageMeta';
import { useSignedIn } from '@/shell/use-signed-in';

export function JoinPage() {
  const { code } = useParams();
  const signedIn = useSignedIn();

  if (code && !signedIn)
    return <Navigate replace to={routes.signIn + '?invite=' + encodeURIComponent(code)} />;

  return <JoinView code={code ?? null} />;
}

function JoinView({ code }: { readonly code: string | null }) {
  const gateway = useGateway();

  const load = useLoad(
    () => (code ? gateway.load.invite(code) : Promise.resolve(ok(undefined))),
    'invite:' + (code ?? ''),
  );

  if (!code || load.status === 'error') return <JoinInvite code={null} />;

  return <JoinInvite code={code} />;
}

function JoinInvite({ code }: { readonly code: string | null }) {
  const [search] = useSearchParams();
  const preview = search.get('preview') === '1';
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);
  const openDialog = useUi((s) => s.openDialog);

  const link = code ? gateway.session.inviteByCode(code) : null;

  const view = useAppState((state) => {
    const c = link ? community(state, link.c) : null;
    if (!link || !c || !state.me) return null;

    return {
      code: link.code,
      cid: link.c,
      name: c.name,
      tagline: c.tagline,
      hue: c.hue,
      letter: c.letter,
      logo: c.logo,
      members: c.members,
      online: c.online,
      joined: c.joined,
      inviter: displayName(state, link.by),
      role: roleName(state, link.c, link.role),
      me: state.me,
      meName: displayName(state, state.me),
    };
  });

  const faces = useAppState((state) =>
    Object.keys(state.people)
      .filter((id) => id !== state.me)
      .slice(0, 4),
  );

  const accept = async () => {
    if (!view) return;

    const r = await gateway.session.acceptInvite(view.code);

    if (!r.ok) {
      flash(r.error);
      return;
    }

    flash('You joined ' + view.name);
    void navigate(routes.community(r.value.community));
    openDialog('welcome', { community: r.value.community });
  };

  return (
    <main className="signin" id="main">
      <PageMeta title={view ? ['Join', view.name] : ['Join']} />
      <div className="signin__card">
        <AuthLogo size="1.4rem" />

        {!view ? (
          <div className="grid gap-3 justify-items-center">
            <EmptyState
              art="invite"
              title="This invite has expired"
              text="Ask the person who sent it for a new link, or look the community up and ask to join."
            />

            <ButtonLink to={routes.home}>
              <Icon name="back" />
              Go to Catch up
            </ButtonLink>
          </div>
        ) : (
          <div
            className="panel grid gap-4 justify-items-center"
            id="join-card"
            style={{ inlineSize: '100%' }}
          >
            {preview ? (
              <p className="join-preview small" role="status">
                <Icon name="eye" />
                <span>
                  Preview of what people see when they open this link.{' '}
                  <Link to={routes.invite(view.cid)}>Back to invites</Link>
                </span>
              </p>
            ) : null}

            <CommunityMark hue={view.hue} letter={view.letter} logo={view.logo} size="4rem" />

            <div className="grid gap-1">
              <span className="label">{view.inviter} invited you to</span>
              <h1 className="page-title">{view.name}</h1>
              <p className="subtle">{view.tagline}</p>
            </div>

            <div className="flex items-center gap-2 small subtle flex-wrap justify-center">
              <div className="avatar-stack">
                {faces.map((id) => (
                  <PersonAvatar key={id} id={id} size="xs" />
                ))}
              </div>
              <span>
                {fmt(view.members)} members · {view.online} online
              </span>
            </div>

            <JoinActions view={view} preview={preview} onAccept={accept} />
          </div>
        )}
      </div>
    </main>
  );
}

type JoinActionsProps = {
  readonly view: {
    readonly cid: string;
    readonly code: string;
    readonly name: string;
    readonly role: string;
    readonly joined: boolean;
    readonly me: string;
    readonly meName: string;
  };
  readonly preview: boolean;
  readonly onAccept: () => void;
};

function JoinActions({ view, preview, onAccept }: JoinActionsProps) {
  if (preview) {
    return (
      <div className="grid gap-2" style={{ inlineSize: '100%' }}>
        <Button
          id="join-accept"
          variant="reversed"
          block
          aria-disabled="true"
          data-tip="Joining is off in preview"
        >
          Join {view.name}
        </Button>
        <p className="x-small subtle">They will join as a {view.role}.</p>
      </div>
    );
  }

  if (view.joined) {
    return (
      <div className="grid gap-2" style={{ inlineSize: '100%' }}>
        <p className="small subtle">You're already a member.</p>
        <ButtonLink to={routes.community(view.cid)} variant="reversed" block>
          Open {view.name}
        </ButtonLink>
      </div>
    );
  }

  return (
    <div className="grid gap-2" style={{ inlineSize: '100%' }}>
      <Button id="join-accept" variant="reversed" block onClick={onAccept}>
        <PersonAvatar id={view.me} size="xs" />
        Join as {view.meName}
      </Button>

      <Link
        className="btn btn--block"
        to={routes.signIn + '?invite=' + encodeURIComponent(view.code)}
      >
        Use a different account
      </Link>

      <p className="x-small subtle">You will join as a {view.role}.</p>
    </div>
  );
}
