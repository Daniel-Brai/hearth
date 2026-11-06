import { addHours, addMinutes } from 'date-fns';
import { useRef, useState } from 'react';

import { useGateway } from '@/app/gateway-context';
import {
  Button,
  Dialog,
  DialogBody,
  DialogClose,
  DialogFooter,
  DialogTitle,
  Field,
  Icon,
  IconButton,
  Input,
  Select,
  SettingsRow,
  Switch,
  Textarea,
} from '@/design-system';
import {
  CHOICE_MAX,
  CLOSE_AFTER,
  closesAtProblem,
  LEAST_CHOICES,
  MOST_CHOICES,
  pollProblem,
  QUESTION_MAX,
} from '@/domain/polls';
import { combine, dayKey, timeKey } from '@/features/date-time/date-time';
import { DatePicker } from '@/features/date-time/DatePicker';
import { TimePicker } from '@/features/date-time/TimePicker';
import { useNow } from '@/features/schedule/use-now';
import { useUi } from '@/runtime/ui-store';

import './PollCard.css';

type Choice = { readonly id: number; readonly label: string };

const CLOSES = [
  { value: 'never', label: 'When I close it' },
  ...CLOSE_AFTER.map((c) => ({ value: c.id, label: c.label })),
  { value: 'at', label: 'At a set time' },
];

export function PollButton({
  chatKey,
  disabled,
}: {
  readonly chatKey: string;
  readonly disabled?: boolean | undefined;
}) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <IconButton
        id="composer-poll"
        variant="borderless"
        disabled={disabled}
        onClick={() => setOpen(true)}
        aria-label="Start a poll"
        data-tip="Start a poll"
      >
        <Icon name="poll" />
      </IconButton>

      <Dialog open={open} onClose={() => setOpen(false)} width="30rem" labelledBy="new-poll-title">
        <DialogClose onClick={() => setOpen(false)} />
        {open ? <NewPollForm chatKey={chatKey} onDone={() => setOpen(false)} /> : null}
      </Dialog>
    </>
  );
}

function NewPollForm({
  chatKey,
  onDone,
}: {
  readonly chatKey: string;
  readonly onDone: () => void;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);

  const [question, setQuestion] = useState('');
  const [options, setOptions] = useState<Choice[]>([
    { id: 0, label: '' },
    { id: 1, label: '' },
  ]);
  const nextId = useRef(2);
  const now = useNow();
  const [multiple, setMultiple] = useState(false);
  const [closes, setCloses] = useState('never');
  const [day, setDay] = useState<string | null>(() => dayKey(addHours(new Date(), 1)));
  const [time, setTime] = useState<string | null>(() => timeKey(addHours(new Date(), 1)));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const minutes = CLOSE_AFTER.find((c) => c.id === closes)?.minutes ?? null;
  const setAt = closes === 'at' && day && time ? combine(day, time) : null;
  const timeProblem =
    closes === 'at' ? (setAt ? closesAtProblem(setAt, now) : 'Pick a date and a time.') : null;
  /** A choice box left empty is dropped rather than holding the poll back */
  const filled = options.map((o) => o.label.trim()).filter(Boolean);
  const poll = { question, options: filled, multiple, closesAt: null };
  const ready = pollProblem(poll) === null && timeProblem === null;

  const setOption = (id: number, label: string) =>
    setOptions((all) => all.map((o) => (o.id === id ? { id, label } : o)));

  const addOption = () => {
    const id = nextId.current++;
    setOptions((all) => [...all, { id, label: '' }]);
  };

  const start = async () => {
    const closesAt = minutes
      ? addMinutes(new Date(), minutes).toISOString()
      : (setAt?.toISOString() ?? null);
    const problem = pollProblem(poll) ?? timeProblem;

    if (problem) {
      setError(problem);
      return;
    }

    setBusy(true);

    let r;

    try {
      r = await gateway.chat.startPoll(chatKey, { ...poll, closesAt });
    } finally {
      setBusy(false);
    }

    if (!r.ok) {
      setError(r.error);
      return;
    }

    flash('Poll started');
    onDone();
  };

  return (
    <DialogBody className="new-poll">
      <DialogTitle id="new-poll-title">New poll</DialogTitle>

      <Field label="Question">
        <Textarea
          id="new-poll-question"
          rows={2}
          value={question}
          maxLength={QUESTION_MAX}
          countFrom={QUESTION_MAX - 40}
          placeholder="What should we ask?"
          onChange={(e) => setQuestion(e.target.value)}
          autoFocus
        />
      </Field>

      <Field label="Choices" as="div">
        <ol className="new-poll__choices">
          {options.map((option, i) => (
            <li key={option.id} className="new-poll__choice">
              <Input
                id={'new-poll-choice-' + i}
                value={option.label}
                maxLength={CHOICE_MAX}
                placeholder={'Choice ' + (i + 1)}
                aria-label={'Choice ' + (i + 1)}
                onChange={(e) => setOption(option.id, e.target.value)}
              />
              {options.length > LEAST_CHOICES ? (
                <IconButton
                  variant="borderless"
                  aria-label={'Remove choice ' + (i + 1)}
                  data-tip="Remove"
                  onClick={() => setOptions((all) => all.filter((o) => o.id !== option.id))}
                >
                  <Icon name="x" />
                </IconButton>
              ) : null}
            </li>
          ))}
        </ol>

        {options.length < MOST_CHOICES ? (
          <Button id="new-poll-add" size="small" variant="borderless" onClick={addOption}>
            <Icon name="plus" />
            Add a choice
          </Button>
        ) : null}
      </Field>

      <SettingsRow title="More than one choice" sub="Let people pick several answers.">
        <Switch checked={multiple} onChange={setMultiple} label="More than one choice" />
      </SettingsRow>

      <Field label="Closes" as="div">
        <Select
          id="new-poll-close"
          block
          value={closes}
          options={CLOSES}
          onChange={setCloses}
          label="Closes"
        />
      </Field>

      {closes === 'at' ? (
        <div className="form-grid">
          <Field label="Date" as="div">
            <DatePicker value={day} onChange={setDay} label="Date" futureOnly />
          </Field>
          <Field label="Time" as="div">
            <TimePicker value={time} onChange={setTime} label="Time" />
          </Field>
          {setAt && timeProblem ? (
            <p className="field__error new-poll__when" role="alert">
              {timeProblem}
            </p>
          ) : null}
        </div>
      ) : null}

      {error ? (
        <p className="field__error" role="alert">
          {error}
        </p>
      ) : null}

      <DialogFooter>
        <Button onClick={onDone}>Cancel</Button>
        <Button
          id="new-poll-start"
          variant="reversed"
          busy={busy}
          disabled={!ready}
          onClick={() => void start()}
        >
          Start poll
        </Button>
      </DialogFooter>
    </DialogBody>
  );
}
