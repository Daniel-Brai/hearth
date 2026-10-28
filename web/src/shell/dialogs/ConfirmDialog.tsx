import { useState } from 'react';
import {
  Button,
  Dialog,
  DialogBody,
  DialogFooter,
  DialogTitle,
  Field,
  Select,
  Textarea,
} from '@/design-system';
import { useUi } from '@/runtime/ui-store';

const NOTE_MAX = 500;

export function ConfirmDialog() {
  const open = useUi((s) => s.dialog === 'confirm');
  const confirm = useUi((s) => s.confirm);
  const closeDialog = useUi((s) => s.closeDialog);

  const close = () => closeDialog('confirm');

  return (
    <Dialog open={open && !!confirm} onClose={close} width="30rem" labelledBy="confirm-title">
      {/* Keyed so each question starts fresh */}
      {confirm ? <ConfirmBody key={confirm.title + confirm.action} onClose={close} /> : null}
    </Dialog>
  );
}

function ConfirmBody({ onClose }: { readonly onClose: () => void }) {
  const confirm = useUi((s) => s.confirm)!;
  const [choice, setChoice] = useState<string | null>(confirm.choices?.[0]?.value ?? null);
  const [note, setNote] = useState('');

  const asks = !!confirm.choices || !!confirm.note;
  const waiting = !!confirm.note?.required && !note.trim();

  const run = () => {
    if (waiting) return;

    const fn = confirm.onConfirm;

    onClose();
    fn({ choice, note: note.trim() });
  };

  return (
    <DialogBody className={asks ? 'grid gap-3' : 'text-center'}>
      <DialogTitle id="confirm-title">{confirm.title}</DialogTitle>
      <p className="subtle">{confirm.body}</p>

      {confirm.choices && choice !== null ? (
        <Select
          id="confirm-choice"
          value={choice}
          options={confirm.choices}
          onChange={setChoice}
          label={confirm.choiceLabel ?? 'Pick one'}
          block
        />
      ) : null}

      {confirm.note ? (
        <Field label={confirm.note.label}>
          <Textarea
            id="confirm-note"
            rows={3}
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder={confirm.note.placeholder}
            maxLength={confirm.note.max ?? NOTE_MAX}
            countFrom={(confirm.note.max ?? NOTE_MAX) - 60}
            required={confirm.note.required}
          />
        </Field>
      ) : null}

      <DialogFooter>
        <Button onClick={onClose}>Cancel</Button>
        <Button
          id="confirm-action"
          variant={confirm.danger ? 'negative' : 'reversed'}
          onClick={run}
          disabled={waiting}
        >
          {confirm.action}
        </Button>
      </DialogFooter>
    </DialogBody>
  );
}
