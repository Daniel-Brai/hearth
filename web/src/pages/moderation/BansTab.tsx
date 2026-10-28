import { useState, type KeyboardEvent } from 'react';
import {
  Avatar,
  Button,
  EmptyState,
  cn,
  Field,
  Icon,
  Input,
  InputWithPrefix,
  Pill,
  Select,
  type SelectOption,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { ageText, plural } from '@/domain/format';
import {
  canSeeName,
  community,
  displayName,
  person,
  personIdByHandle,
  shortName,
} from '@/domain/selectors';
import { stripPrefix } from '@/domain/links';
import type { Ban } from '@/domain/types';
import { useUi } from '@/runtime/ui-store';
import { PersonAvatar } from '@/shell/people';

const LENGTHS: SelectOption<string>[] = [
  { value: '1 day', label: '1 day' },
  { value: '7 days', label: '7 days' },
  { value: '30 days', label: '30 days' },
  { value: 'permanent', label: 'Permanently' },
];

const MAX_MATCHES = 6;

export function BansTab({
  cid,
  name,
  canBan,
}: {
  readonly cid: string;
  readonly name: string;
  readonly canBan: boolean;
}) {
  const bans = useAppState((state) => state.bans.filter((b) => b.c === cid));

  return (
    <section className="grid gap-3" id="mod-bans">
      {canBan ? <BanForm cid={cid} name={name} /> : null}

      <div className="panel grid">
        <h2 className="section-title" style={{ marginBlockEnd: '0.4rem' }}>
          {plural(bans.length, 'person banned', 'people banned')}
        </h2>

        {bans.map((b) => (
          <BanRow key={b.id} ban={b} cid={cid} />
        ))}

        {!bans.length ? (
          <EmptyState
            art="queue"
            title="Nobody is banned"
            text="People you ban show up here, with the reason, so anyone on the team can review or lift it."
          />
        ) : null}
      </div>
    </section>
  );
}

function BanRow({ ban, cid }: { readonly ban: Ban; readonly cid: string }) {
  const gateway = useGateway();
  const ask = useUi((s) => s.ask);
  const flash = useUi((s) => s.flash);

  const view = useAppState((state) => ({
    community: community(state, cid)?.name ?? null,
    by: shortName(state, ban.by),
  }));

  const unban = () =>
    ask({
      title: `Unban @${ban.name}?`,
      body: `They can post and chat in ${view.community ?? 'this community'} again. This shows in the public log.`,
      action: 'Unban',
      danger: false,
      onConfirm: () =>
        void gateway.moderation
          .unban(ban.id)
          .then((r) => flash(r.ok ? `@${ban.name} can take part again` : r.error)),
    });

  const permanent = ban.until === 'permanent';

  return (
    <div className="invite-row">
      <Avatar hue="red" initials={ban.name.slice(0, 2).toUpperCase()} size="sm" />

      <div className="invite-row__main">
        <strong className="truncate small">@{ban.name}</strong>
        <span className="x-small subtle">
          {ban.reason} · banned by {view.by} {ageText(ban.age)}
        </span>
      </div>

      <div className="invite-row__tags">
        {view.community ? <Pill>{view.community}</Pill> : null}
        <Pill tint={permanent ? 'red' : 'orange'}>{permanent ? 'Permanent' : ban.until}</Pill>
      </div>

      <Button size="small" onClick={unban}>
        Unban
      </Button>
    </div>
  );
}

function BanForm({ cid, name }: { readonly cid: string; readonly name: string }) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);

  const [username, setUsername] = useState('');
  const [until, setUntil] = useState('permanent');
  const [reason, setReason] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);

  const matches = useAppState((state) => {
    const q = stripPrefix(username.trim(), ['@']).toLowerCase();

    return Object.keys(state.people)
      .filter((id) => id !== state.me)
      .filter((id) => {
        const p = person(state, id);
        return (
          !q ||
          p.username.includes(q) ||
          (canSeeName(state, id) && p.name.toLowerCase().includes(q))
        );
      })
      .map((id) => person(state, id).username)
      .filter((u) => !state.bans.some((b) => b.name === u && b.c === cid))
      .slice(0, MAX_MATCHES);
  });

  const listed = open && matches.length > 0;

  const pick = (handle: string) => {
    setUsername(handle);
    setOpen(false);
  };

  const onKey = (e: KeyboardEvent<HTMLInputElement>) => {
    const chosen = matches[active];

    if (e.key === 'Enter' && listed && chosen) {
      e.preventDefault();
      pick(chosen);
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive((i) => Math.min(matches.length - 1, i + 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActive((i) => Math.max(0, i - 1));
    } else if (e.key === 'Escape' && open) {
      e.stopPropagation();
      setOpen(false);
    }
  };

  const submit = async () => {
    setError(null);

    const handle = stripPrefix(username.trim(), ['@']).toLowerCase();

    if (!handle) {
      setError('Add the username to ban');
      return;
    }

    if (!reason.trim()) {
      setError('Say why. It goes in the public log.');
      return;
    }

    const r = await gateway.moderation.ban({ c: cid, username: handle, reason, until });

    if (!r.ok) {
      setError(r.error);
      return;
    }

    setUsername('');
    setReason('');
    flash(`@${handle} is banned from ${name}`);
  };

  return (
    <form
      className="panel grid gap-3"
      id="ban-form"
      onSubmit={(e) => {
        e.preventDefault();
        void submit();
      }}
    >
      <h2 className="section-title">Ban someone</h2>

      <div className="form-grid">
        <div
          className="field combo"
          onBlur={(e) => {
            if (!e.currentTarget.contains(e.relatedTarget)) setOpen(false);
          }}
        >
          <label className="field__label" htmlFor="ban-name">
            Username
          </label>

          <InputWithPrefix
            prefix="@"
            id="ban-name"
            value={username}
            spellCheck={false}
            autoComplete="off"
            placeholder="Search people"
            role="combobox"
            aria-autocomplete="list"
            aria-expanded={listed}
            aria-controls="ban-ac"
            onChange={(e) => {
              setUsername(e.target.value);
              setOpen(true);
              setActive(0);
            }}
            onFocus={() => {
              setOpen(true);
              setActive(0);
            }}
            onKeyDown={onKey}
          />

          {listed ? (
            <div className="popup popup--left combo__list" id="ban-ac" role="listbox">
              {matches.map((u, i) => (
                <BanMatch
                  key={u}
                  username={u}
                  active={i === active}
                  onHover={() => setActive(i)}
                  onPick={pick}
                />
              ))}
            </div>
          ) : null}
        </div>

        <Field label="For" as="div">
          <Select value={until} options={LENGTHS} onChange={setUntil} label="How long" block />
        </Field>
      </div>

      <Field label="Reason">
        <Input
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          maxLength={120}
          placeholder="Shown in the public log"
        />
      </Field>

      {error ? (
        <p className="field__error" role="alert">
          {error}
        </p>
      ) : null}

      <div>
        <Button type="submit" size="small" variant="reversed">
          <Icon name="shield" />
          Ban
        </Button>
      </div>
    </form>
  );
}

type BanMatchProps = {
  readonly username: string;
  readonly active: boolean;
  readonly onHover: () => void;
  readonly onPick: (username: string) => void;
};

function BanMatch({ username, active, onHover, onPick }: BanMatchProps) {
  const id = useAppState((state) => personIdByHandle(state, username));
  const label = useAppState((state) => (id ? displayName(state, id) : username));

  return (
    <button
      type="button"
      role="option"
      className={cn('popup__item', active && 'is-active')}
      aria-selected={active}
      onMouseEnter={onHover}
      onClick={() => onPick(username)}
    >
      {id ? <PersonAvatar id={id} size="xs" /> : null}
      <span className="truncate">{label}</span>
      <span className="hint">@{username}</span>
    </button>
  );
}
