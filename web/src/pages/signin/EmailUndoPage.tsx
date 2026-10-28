import { useEffect, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { Button, EmptyState, Icon } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { routes } from '@/runtime/routes';
import { AuthLogo } from '@/pages/signin/AuthLogo';
import { PageMeta } from '@/shell/PageMeta';

type Outcome = { status: 'working' } | { status: 'done' } | { status: 'failed'; error: string };

// The link in the "email changed" note lands here with its token after the hash
export function EmailUndoPage() {
  const gateway = useGateway();
  const navigate = useNavigate();
  const { hash } = useLocation();

  const token = new URLSearchParams(hash.slice(1)).get('token');

  const [outcome, setOutcome] = useState<Outcome>(() =>
    token ? { status: 'working' } : { status: 'failed', error: 'This link is missing its code.' },
  );

  const started = useRef(false);

  useEffect(() => {
    if (started.current || !token) return;

    started.current = true;

    void gateway.session.undoEmailChange(token).then((r) => {
      setOutcome(r.ok ? { status: 'done' } : { status: 'failed', error: r.error });
    });
  }, [gateway, token]);

  // Every device was signed out so this one starts again too
  const signIn = () => {
    gateway.session.signOut();
    void navigate(routes.signIn);
  };

  return (
    <main className="signin" id="main">
      <PageMeta title={['Undo email change']} />

      <div className="signin__card grid gap-3 justify-items-center" id="email-undo">
        <AuthLogo size="1.4rem" />

        {outcome.status === 'working' ? <p className="subtle">Putting your email back…</p> : null}

        {outcome.status === 'done' ? (
          <>
            <EmptyState
              art="caughtup"
              title="Your email is back"
              text="Your account uses your old address again, and every device was signed out. Sign in to carry on."
            />

            <Button variant="reversed" onClick={signIn}>
              Sign in
            </Button>
          </>
        ) : null}

        {outcome.status === 'failed' ? (
          <>
            <EmptyState
              art="lost"
              title="This link doesn't work"
              text={`${outcome.error} Undo links work once, for 7 days.`}
            />

            <Button onClick={() => void navigate(routes.home)}>
              <Icon name="back" />
              Go to Catch up
            </Button>
          </>
        ) : null}
      </div>
    </main>
  );
}
