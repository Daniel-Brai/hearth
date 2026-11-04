import { useState } from 'react';
import {
  Button,
  Dialog,
  DialogBody,
  DialogClose,
  DialogTitle,
  Icon,
  IconButton,
  Menu,
  MenuItem,
} from '@/design-system';
import type { Result } from '@/data/gateway';
import { plural } from '@/domain/format';
import { sendAtLabel } from '@/domain/schedule';
import { SendLaterDialog } from '@/features/schedule/SendLater';
import { useNow } from '@/features/schedule/use-now';
import { useUi } from '@/runtime/ui-store';
import './Scheduled.css';

export type ScheduledEntry = {
  readonly id: string;
  readonly sendAt: string;
  readonly title: string | null;
  readonly text: string;
  readonly files: number;
  readonly failure: string | null;
};

export type ScheduledWords = {
  /** What one waiting item says, such as "message" or "post" */
  readonly noun: string;
  /** The verb for when it goes out, such as "Sends" or "Posts" */
  readonly goes: string;
  readonly now: string;
  readonly sentNow: string;
  readonly deleted: string;
};

export type ScheduledActions = {
  readonly sendNow: (id: string) => Promise<Result>;
  readonly reschedule: (id: string, at: Date) => Promise<Result>;
  readonly edit: (id: string) => void;
  readonly remove: (id: string) => void;
};

const byTime = (a: ScheduledEntry, b: ScheduledEntry) => a.sendAt.localeCompare(b.sendAt);

export function ScheduledNote({
  id,
  entries,
  words,
  actions,
}: {
  readonly id: string;
  readonly entries: readonly ScheduledEntry[];
  readonly words: ScheduledWords;
  readonly actions: ScheduledActions;
}) {
  const [open, setOpen] = useState(false);
  const now = useNow();

  if (!entries.length) return null;

  const sorted = entries.toSorted(byTime);
  const failed = entries.filter((e) => e.failure).length;
  const label =
    entries.length === 1
      ? words.goes + ' ' + sendAtLabel(new Date(sorted[0]!.sendAt), now)
      : plural(entries.length, 'scheduled ' + words.noun);

  return (
    <>
      <button type="button" id={id} className="scheduled-note" onClick={() => setOpen(true)}>
        <Icon name="clock" />
        <span className="scheduled-note__label">{label}</span>
        {failed ? <span className="scheduled-note__failed">{failed} couldn't go out</span> : null}
        <span className="scheduled-note__view">View</span>
      </button>

      <Dialog open={open} onClose={() => setOpen(false)} width="32rem" labelledBy={id + '-title'}>
        <DialogClose onClick={() => setOpen(false)} />
        <DialogBody>
          <DialogTitle id={id + '-title'}>Scheduled {words.noun}s</DialogTitle>
          <p className="subtle small text-center">Only you can see these until they go out.</p>

          <ul className="scheduled-list">
            {sorted.map((entry) => (
              <ScheduledRow
                key={entry.id}
                entry={entry}
                words={words}
                actions={actions}
                now={now}
                onEdit={() => {
                  setOpen(false);
                  actions.edit(entry.id);
                }}
              />
            ))}
          </ul>
        </DialogBody>
      </Dialog>
    </>
  );
}

function ScheduledRow({
  entry,
  words,
  actions,
  now,
  onEdit,
}: {
  readonly entry: ScheduledEntry;
  readonly words: ScheduledWords;
  readonly actions: ScheduledActions;
  readonly now: Date;
  readonly onEdit: () => void;
}) {
  const flash = useUi((s) => s.flash);
  const [rescheduling, setRescheduling] = useState(false);

  const sendNow = async () => {
    const r = await actions.sendNow(entry.id);
    flash(r.ok ? words.sentNow : r.error);
  };

  const reschedule = async (at: Date) => {
    const r = await actions.reschedule(entry.id, at);

    flash(r.ok ? 'Rescheduled for ' + sendAtLabel(at, new Date()) : r.error);
    if (r.ok) setRescheduling(false);
  };

  return (
    <li className="scheduled-row" id={'scheduled-' + entry.id}>
      <div className="scheduled-row__main">
        <span className="scheduled-row__when first-letter:uppercase">
          {sendAtLabel(new Date(entry.sendAt), now)}
        </span>
        {entry.title ? <strong className="scheduled-row__title">{entry.title}</strong> : null}
        {entry.text ? <p className="scheduled-row__text">{entry.text}</p> : null}
        {entry.files ? (
          <span className="scheduled-row__files">
            <Icon name="clip" />
            {plural(entry.files, 'file')}
          </span>
        ) : null}
        {entry.failure ? <p className="field__error">{entry.failure}</p> : null}
      </div>

      <div className="scheduled-row__actions">
        <Button size="small" onClick={() => void sendNow()}>
          <Icon name="send" />
          {words.now}
        </Button>

        <Menu
          left
          trigger={({ toggle, open }) => (
            <IconButton
              variant="borderless"
              size="small"
              onClick={toggle}
              aria-expanded={open}
              aria-label="More"
            >
              <Icon name="dots" />
            </IconButton>
          )}
        >
          <MenuItem icon="clock" onSelect={() => setRescheduling(true)}>
            Reschedule
          </MenuItem>
          <MenuItem icon="pencil" onSelect={onEdit}>
            Edit
          </MenuItem>
          <MenuItem
            icon="trash"
            danger
            onSelect={() => {
              actions.remove(entry.id);
              flash(words.deleted);
            }}
          >
            Delete
          </MenuItem>
        </Menu>
      </div>

      <SendLaterDialog
        open={rescheduling}
        title="Reschedule"
        goes={words.goes}
        onClose={() => setRescheduling(false)}
        onPick={reschedule}
      />
    </li>
  );
}
