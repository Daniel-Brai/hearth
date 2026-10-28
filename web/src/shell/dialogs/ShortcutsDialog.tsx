import { useEffect, useState } from 'react';
import {
  Button,
  Dialog,
  DialogBody,
  DialogClose,
  DialogTitle,
  Icon,
  IconButton,
  Keys,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import {
  assignKey,
  bindingFor,
  comboFromEvent,
  comboText,
  isCustomKey,
  keyGroups,
  keyOf,
} from '@/runtime/keys';
import { useUi } from '@/runtime/ui-store';
import './ShortcutsDialog.css';

type Recording = { id: string; combo: string | null; error: string | null };

export function ShortcutsDialog() {
  const gateway = useGateway();
  const closeDialog = useUi((s) => s.closeDialog);
  const ask = useUi((s) => s.ask);
  const flash = useUi((s) => s.flash);
  const custom = useAppState((state) => state.settings.keys);

  const [rec, setRec] = useState<Recording | null>(null);
  const groups = keyGroups();

  useRecorder(rec, setRec, custom, (keys, message) => {
    gateway.settings.setKeys(keys);
    flash(message);
  });

  const close = () => closeDialog('shortcuts');

  const reset = (id: string) => {
    const next = { ...custom };

    delete next[id];
    gateway.settings.setKeys(next);
    flash(`${bindingFor(id)!.label} is back to ${comboText(bindingFor(id)!.key)}`);
  };

  const resetAll = () =>
    ask({
      title: 'Reset every shortcut?',
      body: 'All shortcuts go back to their defaults.',
      action: 'Reset shortcuts',
      danger: false,
      onConfirm: () => {
        gateway.settings.setKeys({});
        flash('Shortcuts reset');
      },
    });

  return (
    <Dialog open onClose={close} width="64rem" className="dialog--shortcuts" labelledBy="sc-title">
      <DialogClose onClick={close} />

      <DialogBody>
        <DialogTitle id="sc-title">Keyboard shortcuts</DialogTitle>

        <p className="subtle small text-center">
          {rec
            ? 'Press the new keys. A second key within a moment makes a sequence like G then H. Esc cancels.'
            : 'Click a shortcut to change it. Single keys work when you are not typing. Sequences are one key then another.'}
        </p>

        <div className="shortcut-groups">
          {groups.map((g) => (
            <section key={g.name} className="shortcut-group">
              <h3 className="label">{g.name}</h3>

              {g.rows.map((row) => (
                <div
                  key={row.id ?? row.label}
                  className={[
                    'shortcut-row',
                    rec?.id === row.id && 'is-recording',
                    row.id && isCustomKey(row.id, custom) && 'is-custom',
                  ]
                    .filter(Boolean)
                    .join(' ')}
                >
                  <span>{row.label}</span>

                  {row.id === undefined ? (
                    <span className="shortcut-fixed" data-tip="Fixed, text boxes need it">
                      <Keys combo={row.key!} />
                    </span>
                  ) : (
                    <span className="shortcut-edit">
                      <button
                        type="button"
                        className="shortcut-key"
                        onClick={() => setRec({ id: row.id!, combo: null, error: null })}
                        aria-label={'Change shortcut for ' + row.label}
                      >
                        {rec?.id === row.id ? (
                          rec.combo ? (
                            <Keys combo={rec.combo} />
                          ) : (
                            <span className="shortcut-key__wait">Press keys…</span>
                          )
                        ) : (
                          <Keys combo={keyOf(row.id, custom)} />
                        )}
                      </button>

                      {isCustomKey(row.id, custom) && rec?.id !== row.id ? (
                        <IconButton
                          size="tiny"
                          variant="borderless"
                          onClick={() => reset(row.id!)}
                          data-tip="Back to default"
                          aria-label="Reset to default"
                        >
                          <Icon name="refresh" />
                        </IconButton>
                      ) : null}
                    </span>
                  )}
                </div>
              ))}

              {rec?.error && g.rows.some((r) => r.id === rec.id) ? (
                <p className="field__error x-small">{rec.error}</p>
              ) : null}
            </section>
          ))}
        </div>

        {Object.keys(custom).length ? (
          <div className="flex items-center justify-end gap-2 small subtle">
            <Button size="small" variant="borderless" onClick={resetAll}>
              <Icon name="refresh" />
              Reset all
            </Button>
          </div>
        ) : null}
      </DialogBody>
    </Dialog>
  );
}

function useRecorder(
  rec: Recording | null,
  setRec: (r: Recording | null) => void,
  custom: Record<string, string>,
  commit: (keys: Record<string, string>, message: string) => void,
) {
  useEffect(() => {
    if (!rec) return;

    let timer: number | null = null;
    let combo = rec.combo;

    const finish = () => {
      if (!combo) return;

      const result = assignKey(rec.id, combo, custom);

      if ('error' in result) {
        setRec({ id: rec.id, combo: null, error: result.error });
        return;
      }

      commit(result.keys, result.message);
      setRec(null);
    };

    const onKey = (e: KeyboardEvent) => {
      e.preventDefault();
      e.stopPropagation();

      if (e.key === 'Escape') {
        if (timer !== null) window.clearTimeout(timer);
        setRec(null);
        return;
      }

      const next = comboFromEvent(e);

      if (!next) return;

      if (timer !== null) window.clearTimeout(timer);

      const sequence = combo && !combo.includes(' ') && !next.includes('+') && !combo.includes('+');

      combo = sequence ? combo + ' ' + next : next;
      setRec({ id: rec.id, combo, error: null });

      if (combo.includes(' ')) finish();
      else timer = window.setTimeout(finish, 750);
    };

    window.addEventListener('keydown', onKey, true);

    return () => {
      window.removeEventListener('keydown', onKey, true);
      if (timer !== null) window.clearTimeout(timer);
    };
  }, [rec, custom, commit, setRec]);
}
