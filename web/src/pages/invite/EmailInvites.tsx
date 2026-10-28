import { useRef, useState, type ClipboardEvent, type KeyboardEvent } from 'react';
import { Button, Field, Icon, Panel, Select, Textarea, cn } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { roleName, roleOptions } from '@/domain/selectors';
import { useUi } from '@/runtime/ui-store';
import { isEmail, splitAddresses } from './link-facts';

type Chip = { email: string; role: string | null; valid: boolean; unreachable: boolean };

const DEFAULT_ROLE = 'default';

const SEPARATORS = new Set(['Enter', ',', ' ', 'Tab', ';']);

const problem = (bad: string[], unreachable: string[]) => {
  if (bad.length === 1) return `${bad[0]} doesn't look like an email. Remove it or fix the typo.`;

  if (bad.length > 1)
    return `${bad.length} addresses don't look right. Remove them or fix the typos.`;

  if (unreachable.length === 1)
    return `${unreachable[0]} can't receive email. Check the spelling after the @.`;

  if (unreachable.length > 1)
    return `${unreachable.length} addresses can't receive email. Check the spelling after the @.`;

  return null;
};

const chipProblem = (chip: Chip) => {
  if (!chip.valid) return 'Not a valid email';
  if (chip.unreachable) return "This address can't receive email";
  return undefined;
};

export function EmailInvites({ cid }: { readonly cid: string }) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const input = useRef<HTMLInputElement>(null);

  const [chips, setChips] = useState<Chip[]>([]);
  const [draft, setDraft] = useState('');
  const [role, setRole] = useState('member');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [empty, setEmpty] = useState(false);
  const [shake, setShake] = useState(false);

  const roles = useAppState((state) => roleOptions(state, cid));
  const defaultName = useAppState((state) => roleName(state, cid, role));

  const chipRoles = [
    { value: DEFAULT_ROLE, label: defaultName, hint: 'Default' },
    ...roles.filter((o) => o.value !== role),
  ];

  const bad = chips.filter((c) => !c.valid).map((c) => c.email);
  const unreachable = chips.filter((c) => c.unreachable).map((c) => c.email);
  const error = problem(bad, unreachable) ?? (empty ? 'Add at least one email address.' : null);

  const check = async (added: Chip[]) => {
    const emails = added.filter((c) => c.valid).map((c) => c.email);

    if (!emails.length) return;

    const found = new Set(await gateway.invites.unreachable(emails));

    if (!found.size) return;

    setChips((all) => all.map((c) => (found.has(c.email) ? { ...c, unreachable: true } : c)));
  };

  const withAddresses = (current: Chip[], text: string): Chip[] => {
    const seen = new Set(current.map((c) => c.email));
    const added = splitAddresses(text)
      .filter((email) => {
        if (seen.has(email)) return false;

        seen.add(email);
        return true;
      })
      .map((email) => ({ email, role: null, valid: isEmail(email), unreachable: false }));

    return [...current, ...added];
  };

  const add = (text: string) => {
    const next = withAddresses(chips, text);

    setChips(next);
    setDraft('');
    setEmpty(false);
    void check(next.slice(chips.length));
  };

  const commit = () => {
    if (draft.trim()) add(draft);
  };

  const onKey = (e: KeyboardEvent<HTMLInputElement>) => {
    if (SEPARATORS.has(e.key) && draft.trim()) {
      e.preventDefault();
      commit();
    } else if (e.key === 'Backspace' && !draft && chips.length) {
      setChips((c) => c.slice(0, -1));
    }
  };

  const onPaste = (e: ClipboardEvent<HTMLInputElement>) => {
    const text = e.clipboardData.getData('text');

    if (splitAddresses(text).length < 2) return;

    e.preventDefault();
    add(draft + ' ' + text);
  };

  const setChipRole = (email: string, next: string) =>
    setChips((all) =>
      all.map((c) => (c.email === email ? { ...c, role: next === DEFAULT_ROLE ? null : next } : c)),
    );

  const complain = () => {
    setShake(true);
    window.setTimeout(() => setShake(false), 450);
  };

  const send = async () => {
    const all = withAddresses(chips, draft);

    setChips(all);
    setDraft('');

    if (!all.length) {
      setEmpty(true);
      complain();
      return;
    }

    if (all.some((c) => !c.valid || c.unreachable)) {
      complain();
      return;
    }

    setBusy(true);

    let r;

    try {
      r = await gateway.invites.sendEmails(
        cid,
        all.map((c) => ({ email: c.email, role: c.role ?? role })),
        note.trim() || null,
      );
    } finally {
      setBusy(false);
    }

    if (!r.ok) {
      flash(r.error);
      return;
    }

    setChips([]);
    setNote('');
    setEmpty(false);
    flash(r.value.count === 1 ? 'Invite sent' : `${r.value.count} invites sent`);
  };

  const count = chips.length + (draft.trim() ? splitAddresses(draft).length : 0);

  return (
    <Panel className="grid gap-3" id="invite-email">
      <div className="grid gap-1">
        <h2 className="section-title">Invite by email</h2>
        <p className="small subtle">
          We send each person a link that only works for their address. Pick a role on any pill to
          override the default.
        </p>
      </div>

      {/* react-doctor-disable-next-line react-doctor/no-static-element-interactions -- click only forwards focus to the input, which keyboard users reach by tabbing */}
      <div
        id="invite-emails"
        className={cn('email-chips', shake && 'shake')}
        onClick={(e) => {
          if (e.target === e.currentTarget) input.current?.focus();
        }}
      >
        {chips.map((c) => (
          <span
            key={c.email}
            className={cn('email-chip', (!c.valid || c.unreachable) && 'is-bad')}
            title={chipProblem(c)}
          >
            <span className="email-chip__text">{c.email}</span>

            {c.valid ? (
              <Select
                chip
                value={c.role ?? DEFAULT_ROLE}
                options={chipRoles}
                onChange={(next) => setChipRole(c.email, next)}
                label="Role for this person"
              />
            ) : null}

            <button
              type="button"
              className="email-chip__remove"
              aria-label={`Remove ${c.email}`}
              onClick={(e) => {
                e.stopPropagation();
                setChips((all) => all.filter((x) => x.email !== c.email));
              }}
            >
              <Icon name="x" />
            </button>
          </span>
        ))}

        <input
          ref={input}
          type="text"
          inputMode="email"
          autoComplete="off"
          spellCheck={false}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={onKey}
          onBlur={commit}
          onPaste={onPaste}
          placeholder={chips.length ? 'Add another' : 'Type an email, then press Enter or comma'}
          aria-label="Email addresses"
        />
      </div>

      {error ? (
        <p className="field__error" role="alert">
          {error}
        </p>
      ) : null}

      <Field
        label={
          <>
            Add a note <span className="subtle">(optional)</span>
          </>
        }
      >
        <Textarea
          value={note}
          onChange={(e) => setNote(e.target.value)}
          maxLength={280}
          placeholder="Come help us figure out the roadmap."
        />
      </Field>

      <div className="flex items-center justify-between gap-2 one-line-row">
        <div className="icon-text small">
          <span className="subtle">
            <span className="hide-narrow">New people join as</span>
            <span className="show-narrow">Join as</span>
          </span>
          <Select
            value={role}
            options={roles}
            onChange={setRole}
            label="Default role for email invites"
          />
        </div>

        <Button variant="reversed" busy={busy} onClick={() => void send()}>
          <Icon name="mail" />
          <span className="hide-narrow">{count > 1 ? `Send ${count} invites` : 'Send invite'}</span>
          <span className="show-narrow">{count > 1 ? `Send ${count}` : 'Send'}</span>
        </Button>
      </div>
    </Panel>
  );
}
