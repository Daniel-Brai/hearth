import { useState } from 'react';
import {
  Button,
  Chip,
  cn,
  Dialog,
  DialogBody,
  DialogClose,
  DialogFooter,
  DialogTitle,
  Field,
  Icon,
  IconButton,
} from '@/design-system';
import { sendAtLabel, sendAtProblem, sendChoices } from '@/domain/schedule';
import { DatePicker } from '@/features/date-time/DatePicker';
import { TimePicker } from '@/features/date-time/TimePicker';
import { combine, dayKey, timeKey } from '@/features/date-time/date-time';
import './SendLater.css';

export function SendLaterButton({
  id = 'composer-send-later',
  label = 'Send later',
  goes = 'Sends',
  size = 'small',
  disabled,
  onPick,
}: {
  readonly id?: string | undefined;
  readonly label?: string | undefined;
  readonly goes?: string | undefined;
  readonly size?: 'small' | undefined;
  readonly disabled: boolean;
  readonly onPick: (at: Date) => boolean | Promise<boolean>;
}) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <IconButton
        id={id}
        size={size}
        variant="borderless"
        disabled={disabled}
        onClick={() => setOpen(true)}
        aria-label={label}
        data-tip={label}
      >
        <Icon name="clock" />
      </IconButton>

      <SendLaterDialog
        open={open}
        title={label}
        goes={goes}
        onClose={() => setOpen(false)}
        onPick={async (at) => {
          if (await onPick(at)) setOpen(false);
        }}
      />
    </>
  );
}

export function SendLaterDialog({
  open,
  title,
  goes = 'Sends',
  onClose,
  onPick,
}: {
  readonly open: boolean;
  readonly title: string;
  readonly goes?: string | undefined;
  readonly onClose: () => void;
  readonly onPick: (at: Date) => void | Promise<void>;
}) {
  return (
    <Dialog open={open} onClose={onClose} width="30rem" labelledBy="send-later-title">
      <DialogClose onClick={onClose} />
      <SendLaterForm title={title} goes={goes} onClose={onClose} onPick={onPick} />
    </Dialog>
  );
}

// Mounted only while open so the times are worked out when it opens
function SendLaterForm({
  title,
  goes,
  onClose,
  onPick,
}: {
  readonly title: string;
  readonly goes: string;
  readonly onClose: () => void;
  readonly onPick: (at: Date) => void | Promise<void>;
}) {
  const [now] = useState(() => new Date());
  const choices = sendChoices(now);
  const start = choices.find((c) => c.id === 'tomorrow')?.at;
  const [day, setDay] = useState<string | null>(() => (start ? dayKey(start) : null));
  const [time, setTime] = useState<string | null>(() => (start ? timeKey(start) : null));
  const at = day && time ? combine(day, time) : null;
  const problem = at ? sendAtProblem(at, now) : null;
  const chosen = choices.find((c) => c.at.getTime() === at?.getTime())?.id ?? null;

  const choose = (when: Date) => {
    setDay(dayKey(when));
    setTime(timeKey(when));
  };

  return (
    <DialogBody className="send-later">
      <DialogTitle id="send-later-title">{title}</DialogTitle>

      <div
        className="chips send-later__chips"
        id="send-later-choices"
        role="group"
        aria-label="Quick times"
      >
        {choices.map((choice) => (
          <Chip key={choice.id} on={chosen === choice.id} onClick={() => choose(choice.at)}>
            {choice.label}
          </Chip>
        ))}
      </div>

      <div className="form-grid">
        <Field label="Date" as="div">
          <DatePicker value={day} onChange={setDay} label="Date" futureOnly />
        </Field>
        <Field label="Time" as="div">
          <TimePicker value={time} onChange={setTime} label="Time" />
        </Field>
      </div>

      {at ? (
        <p
          id="send-later-summary"
          className={cn('send-later__summary first-letter:uppercase', problem && 'is-problem')}
          aria-live="polite"
        >
          {problem ?? goes + ' ' + sendAtLabel(at, now)}
        </p>
      ) : null}

      <DialogFooter>
        <Button onClick={onClose}>Cancel</Button>
        <Button
          id="send-later-confirm"
          variant="reversed"
          disabled={!at || problem !== null}
          onClick={() => at && void onPick(at)}
        >
          Schedule
        </Button>
      </DialogFooter>
    </DialogBody>
  );
}
