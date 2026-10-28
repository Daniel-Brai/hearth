import { useState } from 'react';
import { Button, Field, Icon, Select, type SelectOption } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { displayName, handle, isOwner, rolesOf } from '@/domain/selectors';
import { CodeBoxes } from '@/features/code-boxes/CodeBoxes';
import { useUi } from '@/runtime/ui-store';

const NO_OWNER = 'none';

export function OwnershipField({
  cid,
  name,
  close,
}: {
  readonly cid: string;
  readonly name: string;
  readonly close: () => void;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);

  const owner = useAppState((state) => isOwner(state, cid));

  const members = useAppState((state) => {
    const ids = new Set<string>();

    state.posts
      .filter((p) => p.c === cid)
      .forEach((p) => {
        ids.add(p.author);
        p.replies.forEach((r) => ids.add(r.who));
      });

    rolesOf(state, cid).forEach((r) => r.members.forEach((id) => ids.add(id)));

    return [...ids].filter((id) => id !== state.me && !!state.people[id]);
  });

  const memberOptions = useAppState(
    (state): SelectOption<string>[] =>
      members.map((id) => ({
        value: id,
        label: displayName(state, id),
        hint: displayName(state, id) === handle(state, id) ? null : handle(state, id),
      })),
    (a, b) =>
      a.length === b.length &&
      a.every((o, i) => o.value === b[i]?.value && o.label === b[i]?.label),
  );

  const successor = useAppState((state) => {
    const roles = rolesOf(state, cid);
    return (
      (roles.find((r) => r.id === 'maintainer') ?? roles.find((r) => r.id === 'moderator'))?.name ??
      null
    );
  });

  const [newOwner, setNewOwner] = useState<string | null>(null);
  const [step, setStep] = useState<'pick' | 'confirm' | 'code'>('pick');
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!owner) return null;

  const who = memberOptions.find((o) => o.value === newOwner)?.label ?? 'They';

  const ownershipHint = successor
    ? `Hand it to someone you trust. You stay on as a ${successor}.`
    : 'Hand it to someone you trust.';

  const sendCode = async () => {
    setBusy(true);

    const r = await gateway.communities.requestTransferCode(cid).finally(() => setBusy(false));

    if (!r.ok) return flash(r.error);

    setCode('');
    setError(null);
    setStep('code');
  };

  const finish = async (typed: string) => {
    if (!newOwner) return;

    setBusy(true);

    const r = await gateway.communities
      .transferOwnership(cid, newOwner, typed)
      .finally(() => setBusy(false));

    if (!r.ok) {
      setCode('');
      setError(r.error);
      return;
    }

    close();
    flash(`${who} now owns ${name}`);
  };

  const type = (next: string) => {
    setCode(next);
    setError(null);

    if (next.length === 6) void finish(next);
  };

  if (step === 'confirm') {
    return (
      <Field className="transfer" label="Ownership" as="div">
        <div className="grid gap-3" id="transfer-confirm-step">
          <p className="small">
            <strong>{who}</strong> gets full control of {name}, including deleting it and changing
            anyone's role. You become {successor ? `a ${successor}` : 'a member'}. Only {who} can
            give ownership back.
          </p>

          <p className="subtle small">We'll email you a code to confirm it's you.</p>

          <div className="flex items-center gap-2 flex-wrap">
            <Button
              size="small"
              variant="borderless"
              disabled={busy}
              onClick={() => setStep('pick')}
            >
              <Icon name="back" />
              Back
            </Button>

            <Button
              size="small"
              className="btn--danger-text"
              disabled={busy}
              onClick={() => void sendCode()}
            >
              <Icon name="key" />
              Email me a code
            </Button>
          </div>
        </div>
      </Field>
    );
  }

  if (step === 'code') {
    return (
      <Field className="transfer" label="Ownership" as="div">
        <div className="grid gap-3 justify-items-center" id="transfer-code-step">
          <p className="subtle small text-center">
            We emailed you a 6 digit code. Type it to make <strong>{who}</strong> the owner. It
            works for 15 minutes.
          </p>

          <CodeBoxes
            id="transfer-code"
            label="Transfer code"
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
              onClick={() => setStep('pick')}
            >
              <Icon name="back" />
              Back
            </Button>

            <Button size="small" disabled={busy} onClick={() => void sendCode()}>
              <Icon name="refresh" />
              Send a new code
            </Button>
          </div>
        </div>
      </Field>
    );
  }

  return (
    <Field className="transfer" label="Ownership" as="div" hint={ownershipHint}>
      <div className="flex items-center gap-2 flex-wrap">
        <div style={{ flex: '1 1 14rem' }}>
          <Select
            value={newOwner ?? NO_OWNER}
            options={[{ value: NO_OWNER, label: 'Pick a member…' }, ...memberOptions]}
            onChange={(next) => setNewOwner(next === NO_OWNER ? null : next)}
            label="New owner"
            searchable
            searchLabel="Search members"
            block
          />
        </div>

        <Button
          size="small"
          className="btn--danger-text"
          disabled={!newOwner}
          onClick={() => setStep('confirm')}
        >
          <Icon name="key" />
          Transfer ownership
        </Button>
      </div>
    </Field>
  );
}
