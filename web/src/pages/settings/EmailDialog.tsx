import { useState } from 'react';
import { useNavigate } from 'react-router';
import {
  Button,
  Dialog,
  DialogClose,
  DialogFooter,
  DialogTitle,
  Field,
  Icon,
  Input,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { SIGN_IN_AGAIN } from '@/data/gateway';
import { CodeBoxes } from '@/features/code-boxes/CodeBoxes';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';

export function EmailDialog({ onClose }: { readonly onClose: () => void }) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);

  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const send = async () => {
    setBusy(true);
    setError(null);

    const r = await gateway.session.changeEmail(email).finally(() => setBusy(false));

    if (!r.ok) return setError(r.error);

    setCode('');
    setSent(true);
  };

  const confirm = async (typed: string) => {
    setBusy(true);

    const r = await gateway.session.confirmEmail(typed).finally(() => setBusy(false));

    if (!r.ok) {
      setCode('');
      setError(r.error);
      return;
    }

    onClose();
    flash(`Your email is now ${email.trim()}`);
  };

  const type = (next: string) => {
    setCode(next);
    setError(null);

    if (next.length === 6) void confirm(next);
  };

  const signInAgain = () => {
    gateway.session.signOut();
    void navigate(routes.signIn);
  };

  return (
    <Dialog open onClose={onClose} width="30rem" labelledBy="email-title">
      <DialogClose onClick={onClose} />

      {sent ? (
        <div className="dialog__body grid gap-3 justify-items-center" id="email-code-step">
          <DialogTitle id="email-title">Check your new inbox</DialogTitle>

          <p className="subtle small text-center">
            We sent a 6 digit code to <strong>{email.trim()}</strong>. It works for 15 minutes.
          </p>

          <CodeBoxes
            id="email-code"
            label="Email change code"
            code={code}
            busy={busy}
            shake={error !== null}
            onChange={type}
          />

          {error ? <p className="field__error">{error}</p> : null}

          <div className="flex items-center gap-2 flex-wrap justify-center">
            <Button
              size="small"
              variant="borderless"
              disabled={busy}
              onClick={() => setSent(false)}
            >
              <Icon name="back" />
              Different email
            </Button>

            <Button size="small" disabled={busy} onClick={() => void send()}>
              <Icon name="refresh" />
              Send a new code
            </Button>
          </div>
        </div>
      ) : (
        <form
          className="dialog__body"
          id="email-form"
          noValidate
          onSubmit={(e) => {
            e.preventDefault();
            void send();
          }}
        >
          <DialogTitle id="email-title">Change your email</DialogTitle>

          <p className="subtle small text-center">
            We'll send a code to the new address. Your old address gets a note with a way to undo
            it.
          </p>

          <Field label="New email" error={error}>
            <Input
              id="email-new"
              type="email"
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoFocus
            />
          </Field>

          <DialogFooter>
            {error === SIGN_IN_AGAIN ? (
              <Button onClick={signInAgain}>Sign in again</Button>
            ) : (
              <Button onClick={onClose}>Cancel</Button>
            )}

            <Button type="submit" variant="reversed" disabled={busy || !email.trim()}>
              Send code
            </Button>
          </DialogFooter>
        </form>
      )}
    </Dialog>
  );
}
