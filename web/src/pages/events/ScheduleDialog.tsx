import {
  Button,
  Dialog,
  DialogClose,
  DialogFooter,
  DialogTitle,
  Field,
  Icon,
  Input,
  Textarea,
} from '@/design-system';
import type { CommunityEvent } from '@/domain/types';
import { TalkField, WhenFields, WhereFields } from './ScheduleFields';
import { useScheduleForm } from './use-schedule-form';

export type ScheduleDialogProps = {
  readonly cid: string;
  readonly event: CommunityEvent | null;
  readonly onClose: () => void;
};

function dialogTitle(event: CommunityEvent | null, community: string | null): string {
  if (event) return 'Edit event';
  return community ? `Schedule an event in ${community}` : 'Schedule an event';
}

export function ScheduleDialog({ cid, event, onClose }: ScheduleDialogProps) {
  const form = useScheduleForm(cid, event, onClose);
  const { values, set, community, problem, summary } = form;

  return (
    <Dialog open onClose={onClose} width="36rem" labelledBy="ev-edit-title">
      <DialogClose onClick={onClose} />

      <form className="dialog__body text-start" onSubmit={form.submit} noValidate id="event-form">
        <DialogTitle id="ev-edit-title">{dialogTitle(event, community?.name ?? null)}</DialogTitle>

        <Field label="Name">
          <Input
            id="ev-title"
            value={values.title}
            onChange={(e) => set.setTitle(e.target.value)}
            maxLength={80}
            placeholder="Office hours, release Q&A, workshop…"
            shake={problem?.field === 'title'}
            autoFocus
          />
        </Field>

        <WhenFields form={form} />

        <WhereFields form={form} />

        {form.voice ? <TalkField form={form} /> : null}

        <Field
          label={
            <>
              What happens <span className="subtle">(optional)</span>
            </>
          }
        >
          <Textarea
            value={values.desc}
            onChange={(e) => set.setDesc(e.target.value)}
            maxLength={2000}
            style={{ minBlockSize: '5lh' }}
            placeholder="Agenda, what to read first, who it is for. Formatting works."
          />
        </Field>

        {summary ? (
          <p className="summary small">
            <span className="label">
              <Icon name="calendar" />
              When
            </span>
            <span>{summary}</span>
          </p>
        ) : null}

        {!event ? (
          <label className="icon-text small">
            <input
              type="checkbox"
              className="size-[1.05rem] accent-[var(--color-link)]"
              checked={values.notify}
              onChange={(e) => set.setNotify(e.target.checked)}
            />
            Tell members in their notifications
          </label>
        ) : null}

        {problem ? (
          <p className="field__error" role="alert">
            {problem.text}
          </p>
        ) : null}

        <DialogFooter>
          <Button onClick={onClose}>Cancel</Button>
          <Button type="submit" variant="reversed">
            {event ? 'Save changes' : 'Schedule event'}
          </Button>
        </DialogFooter>
      </form>
    </Dialog>
  );
}
