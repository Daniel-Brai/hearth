import { useState } from 'react';
import {
  Button,
  CommunityMark,
  EmptyState,
  Icon,
  Label,
  LinkPreview,
  Select,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { ageText, plural, tintStyle } from '@/domain/format';
import { canDo, community, displayName, handle, isHeld, person } from '@/domain/selectors';
import { REPORT_REASONS } from '@/domain/catalog';
import type { QueueItem, QueueReport } from '@/domain/types';
import { InlineMarkdown, Markdown } from '@/features/markdown/Markdown';
import { firstUrl, previewFor } from '@/features/previews';
import { useUi } from '@/runtime/ui-store';
import { PersonAvatar, PersonLink } from '@/shell/people';
import { modOffNote } from './mod-notes';
import { DEFAULT_REASON, REASONS } from './queue-reasons';

function confidenceHue(score: number) {
  if (score > 0.8) return 'red';
  if (score > 0.55) return 'orange';

  return 'green';
}

export function QueueTab({ cid, name }: { readonly cid: string; readonly name: string }) {
  const gateway = useGateway();
  const ask = useUi((s) => s.ask);
  const flash = useUi((s) => s.flash);
  const [reasons, setReasons] = useState<Record<string, string>>({});

  const items = useAppState((state) =>
    state.queue.filter((x) => x.status === 'pending' && x.c === cid && isHeld(state, x)),
  );

  const handled = useAppState((state) =>
    state.queue.filter((x) => x.c === cid && x.status !== 'pending').slice(0, 5),
  );

  const note = useAppState((state) => modOffNote(state, cid));
  const canBan = useAppState((state) => canDo(state, cid, 'member.ban'));

  const reasonFor = (x: QueueItem) => reasons[x.id] ?? DEFAULT_REASON;

  const keep = (x: QueueItem) =>
    void gateway.moderation
      .keep(x.id)
      .then((r) => flash(r.ok ? 'Kept. Nothing was removed.' : r.error));

  const remove = (x: QueueItem) =>
    void gateway.moderation
      .remove(x.id, reasonFor(x))
      .then((r) => flash(r.ok ? 'Removed and logged' : r.error));

  const undo = (x: QueueItem) =>
    void gateway.moderation.undo(x.id).then((r) => flash(r.ok ? 'Back in the queue' : r.error));

  const ban = (x: QueueItem, author: string) =>
    ask({
      title: `Ban ${author}?`,
      body: `They can't post, chat or join rooms in ${name} until someone unbans them. This shows in the public log.`,
      action: 'Ban and remove',
      onConfirm: () =>
        void gateway.moderation
          .banFromQueue(x.id, reasonFor(x))
          .then((r) => flash(r.ok ? 'Banned and logged' : r.error)),
    });

  return (
    <section className="grid gap-3" id="mod-queue">
      <div className="mod-toolbar">
        <strong>
          {items.length ? `${plural(items.length, 'item')} waiting` : 'Nothing waiting'}
        </strong>
      </div>

      <p className="mod-note">
        <Icon name="shield" />
        <span>
          Reports from people land here, and so does anything automatic screening isn't sure about.
          Nothing is removed until a person decides, and every decision goes in the public log.
        </span>
      </p>

      {note ? (
        <p className="mod-note">
          <Icon name="eye" />
          <span>{note}</span>
        </p>
      ) : null}

      {items.map((x) => (
        <QueueCard
          key={x.id}
          item={x}
          reason={reasonFor(x)}
          onReason={(r) => setReasons((all) => ({ ...all, [x.id]: r }))}
          onKeep={() => keep(x)}
          onRemove={() => remove(x)}
          onBan={canBan ? (author) => ban(x, author) : undefined}
        />
      ))}

      {!items.length ? (
        <EmptyState
          art="queue"
          title={`Nothing waiting in ${name}`}
          text="When someone reports something, or screening holds it, it lands here for a person to decide."
        />
      ) : null}

      {handled.length ? <HandledList items={handled} onUndo={undo} /> : null}
    </section>
  );
}

const OUTCOMES = {
  removed: { icon: 'trash', text: 'Removed' },
  kept: { icon: 'check', text: 'Kept up' },
  dismissed: { icon: 'x', text: 'Dismissed' },
  pending: { icon: 'refresh', text: 'Waiting' },
} as const;

function HandledList({
  items,
  onUndo,
}: {
  readonly items: readonly QueueItem[];
  readonly onUndo: (item: QueueItem) => void;
}) {
  return (
    <section className="handled" id="queue-handled" aria-labelledby="queue-handled-title">
      <Label id="queue-handled-title">Just handled</Label>

      <ul className="handled__list">
        {items.map((x) => (
          <HandledRow key={x.id} item={x} onUndo={() => onUndo(x)} />
        ))}
      </ul>
    </section>
  );
}

function HandledRow({
  item: x,
  onUndo,
}: {
  readonly item: QueueItem;
  readonly onUndo: () => void;
}) {
  const author = useAppState((state) => displayName(state, x.who));
  const outcome = OUTCOMES[x.status];

  return (
    <li className="handled__row" id={'handled-' + x.id} data-status={x.status}>
      <span className="handled__mark" aria-hidden="true">
        <Icon name={outcome.icon} />
      </span>

      <span className="handled__body">
        <InlineMarkdown text={x.text} community={x.c} className="handled__text truncate" />
        <span className="x-small subtle truncate">
          {outcome.text} · {x.kind.toLowerCase()} by {author}
        </span>
      </span>

      <Button
        size="tiny"
        variant="borderless"
        id={'handled-undo-' + x.id}
        onClick={onUndo}
        aria-label={`Undo, ${outcome.text.toLowerCase()} ${x.kind.toLowerCase()} by ${author}`}
      >
        <Icon name="refresh" />
        Undo
      </Button>
    </li>
  );
}

type QueueCardProps = {
  readonly item: QueueItem;
  readonly reason: string;
  readonly onReason: (reason: string) => void;
  readonly onKeep: () => void;
  readonly onRemove: () => void;
  readonly onBan?: ((author: string) => void) | undefined;
};

export function QueueCard({ item: x, reason, onReason, onKeep, onRemove, onBan }: QueueCardProps) {
  const view = useAppState((state) => {
    const c = community(state, x.c);
    const p = person(state, x.who);
    return {
      hue: c?.hue ?? 'ink',
      letter: c?.letter ?? '?',
      logo: c?.logo ?? null,
      author: displayName(state, x.who),
      handle: handle(state, x.who),
      joined: p.joined,
      posts: p.posts,
    };
  });

  const url = firstUrl(x.text);
  const preview = url ? previewFor(url) : null;
  const pct = Math.round(x.score * 100);

  return (
    <article className="queue-item" id={`queue-${x.id}`}>
      <div className="queue-item__head">
        <CommunityMark hue={view.hue} letter={view.letter} logo={view.logo} />
        <strong>{x.kind}</strong>
        <span className="subtle">{x.where}</span>
        <span className="subtle" style={{ marginInlineStart: 'auto' }}>
          {ageText(x.age)}
        </span>
      </div>

      <div className="flex items-center gap-2 small">
        <PersonAvatar id={x.who} size="xs" />
        <PersonLink id={x.who} className="font-bold" />
        <span className="subtle">
          {view.handle}
          {view.joined ? <> · joined {view.joined}</> : null} · {plural(view.posts, 'post')}
        </span>
      </div>

      <Markdown text={x.text} community={x.c} className="queue-item__content" />

      {preview ? (
        <div className="og-wrap">
          <LinkPreview preview={preview} />
        </div>
      ) : null}

      {x.source === 'automatic' || !x.reports?.length ? (
        <div className="queue-item__ai">
          <Icon name="sparkles" style={{ marginBlockStart: '0.15rem' }} />
          <div className="grid gap-1">
            <span>{x.reason}</span>
            <span className="flex items-center gap-2 x-small subtle">
              <span className="confidence" style={tintStyle(confidenceHue(x.score))}>
                <span style={{ inlineSize: `${pct}%` }} />
              </span>
              <span className="tabular">{pct}% sure it breaks the rules</span>
            </span>
          </div>
        </div>
      ) : (
        <ReportList reports={x.reports} />
      )}

      <div className="queue-item__actions">
        <Button size="small" onClick={onKeep}>
          <Icon name="check" />
          Keep it
        </Button>

        <Select value={reason} options={REASONS} onChange={onReason} label="Reason for removing" />

        <Button size="small" variant="reversed" onClick={onRemove} aria-label="Remove">
          <Icon name="trash" />
          <span className="hide-narrow">Remove</span>
        </Button>

        {onBan ? (
          <Button
            size="small"
            variant="negative"
            style={{ marginInlineStart: 'auto' }}
            onClick={() => onBan(view.author)}
          >
            <span className="hide-narrow">Ban author</span>
            <span className="show-narrow">Ban</span>
          </Button>
        ) : null}
      </div>
    </article>
  );
}

const REASON_LABELS = new Map<string, string>(REPORT_REASONS.map((r) => [r.value, r.label]));

function ReportList({ reports }: { readonly reports: readonly QueueReport[] }) {
  return (
    <div className="queue-item__ai">
      <Icon name="flag" style={{ marginBlockStart: '0.15rem' }} />
      <div className="grid gap-1">
        <span>Reported {reports.length === 1 ? 'once' : `${reports.length} times`}</span>
        {reports.map((r, i) => (
          // Reports have no id and only grow at the end
          // react-doctor-disable-next-line react-doctor/no-array-index-as-key
          <span key={i} className="x-small subtle">
            {REASON_LABELS.get(r.reason) ?? r.reason}
            {r.note ? ` · “${r.note}”` : null} · {ageText(r.age)}
          </span>
        ))}
      </div>
    </div>
  );
}
