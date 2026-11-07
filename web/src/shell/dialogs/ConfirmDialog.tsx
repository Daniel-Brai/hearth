import { useState } from 'react';

import {
  Button,
  Dialog,
  DialogBody,
  DialogFooter,
  DialogTitle,
  Field,
  Input,
  Select,
  Textarea,
} from '@/design-system';
import { useUi, type ConfirmNote } from '@/runtime/ui-store';

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
  const [note, setNote] = useState(confirm.note?.initial ?? '');

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
        <NoteField note={confirm.note} value={note} onChange={setNote} onEnter={run} />
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

function NoteField({
  note,
  value,
  onChange,
  onEnter,
}: {
  readonly note: ConfirmNote;
  readonly value: string;
  readonly onChange: (value: string) => void;
  readonly onEnter: () => void;
}) {
  const max = note.max ?? NOTE_MAX;

  return (
    <Field label={note.label}>
      {note.oneLine ? (
        <Input
          id="confirm-note"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key !== 'Enter') return;
            e.preventDefault();
            onEnter();
          }}
          placeholder={note.placeholder}
          maxLength={max}
          required={note.required}
          autoComplete="off"
        />
      ) : (
        <Textarea
          id="confirm-note"
          rows={3}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={note.placeholder}
          maxLength={max}
          countFrom={max - 60}
          required={note.required}
        />
      )}
    </Field>
  );
}
