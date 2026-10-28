import { useAppState } from '@/data/store';
import { Button, Icon, Input, Separator } from '@/design-system';
import { CodeBoxes } from '@/features/code-boxes/CodeBoxes';
import type { SignIn } from './use-sign-in';

export function EmailStep({ flow }: { readonly flow: SignIn }) {
  const { busy, via, error } = flow;
  const signIn = useAppState((state) => state.instance.signIn);
  const google = signIn.includes('google');
  const github = signIn.includes('github');

  return (
    <form id="signin-email-form" className="grid gap-3" onSubmit={(e) => void flow.sendCode(e)}>
      <h1 className="page-title">Sign in or join</h1>
      <p className="subtle">First time? Signing in creates your account.</p>

      {google || github ? (
        <>
          <div className="grid gap-2">
            {google ? (
              <Button
                block
                busy={busy && via === 'Google'}
                disabled={busy}
                onClick={() => void flow.oauth('Google')}
              >
                <Icon name="google" />
                Continue with Google
              </Button>
            ) : null}

            {github ? (
              <Button
                block
                busy={busy && via === 'GitHub'}
                disabled={busy}
                onClick={() => void flow.oauth('GitHub')}
              >
                <Icon name="github" />
                Continue with GitHub
              </Button>
            ) : null}
          </div>

          <Separator className="my-1">or use email</Separator>
        </>
      ) : null}

      <Input
        id="signin-email"
        type="email"
        autoComplete="email"
        value={flow.email}
        onChange={(e) => flow.setEmail(e.target.value)}
        placeholder="you@example.com"
        aria-label="Email address"
        style={{ textAlign: 'center' }}
        shake={flow.shaking === 'email'}
      />

      {error ? <p className="field__error">{error}</p> : null}

      <Button type="submit" variant="reversed" block busy={busy && via === 'email'} disabled={busy}>
        <Icon name="mail" />
        Email me a code
      </Button>
    </form>
  );
}

export function CodeStep({ flow }: { readonly flow: SignIn }) {
  return (
    <div className="grid gap-3 justify-items-center">
      <h1 className="page-title">Check your email</h1>
      <p className="subtle">
        We sent a 6 digit code to <strong>{flow.email}</strong>. It works for 15 minutes.
      </p>

      <CodeBoxes
        id="signin-code"
        label="Sign in code"
        code={flow.code}
        busy={flow.busy}
        shake={flow.shaking === 'code'}
        onChange={flow.changeCode}
      />

      {flow.error ? <p className="field__error">{flow.error}</p> : null}

      <div className="flex items-center gap-2 flex-wrap justify-center">
        <Button size="small" variant="borderless" onClick={flow.back}>
          <Icon name="back" />
          Different email
        </Button>

        <Button size="small" onClick={flow.resend}>
          <Icon name="refresh" />
          Send a new code
        </Button>
      </div>
    </div>
  );
}
