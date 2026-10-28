import { useEffect, useLayoutEffect, useRef, useState, type KeyboardEvent } from 'react';
import { Icon, orientPopup } from '@/design-system';
import { useUi } from '@/runtime/ui-store';
import { parseTimeText, timeLabel, timeSlots } from './date-time';
import { usePopover } from './use-popover';

export type TimePickerProps = {
  readonly value: string | null;
  readonly onChange: (next: string) => void;
  readonly label: string;
};

export function TimePicker({ value, onChange, label }: TimePickerProps) {
  const { open, setOpen, root, button, close } = usePopover();
  const flash = useUi((s) => s.flash);
  const list = useRef<HTMLDivElement>(null);
  const input = useRef<HTMLInputElement>(null);
  const popup = useRef<HTMLDivElement>(null);

  const [typed, setTyped] = useState('');

  const parsed = typed.trim() ? parseTimeText(typed) : null;

  useLayoutEffect(() => {
    if (open && popup.current) orientPopup(popup.current);
  }, [open]);

  useEffect(() => {
    if (!open) return;

    const target =
      list.current?.querySelector<HTMLElement>('[aria-selected=true]') ??
      list.current?.querySelector<HTMLElement>('[data-t="09:00"]');

    target?.scrollIntoView({ block: 'center' });
    input.current?.focus();
  }, [open]);

  const toggle = () => {
    if (!open) setTyped('');
    setOpen(!open);
  };

  const pick = (t: string) => {
    onChange(t);
    close();
  };

  const onType = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key !== 'Enter') return;
    e.preventDefault();

    if (parsed) pick(parsed);
    else flash('Try a time like 6:30 pm or 18:30');
  };

  const onKey = (e: KeyboardEvent) => {
    if (e.key !== 'Escape') return;
    e.stopPropagation();
    e.preventDefault();
    close();
  };

  return (
    <div ref={root} className="select select--block picker" onKeyDown={onKey}>
      <button
        ref={button}
        type="button"
        className="select__button"
        onClick={toggle}
        aria-expanded={open}
        aria-haspopup="listbox"
        aria-label={label}
      >
        <span className="truncate">{value ? timeLabel(value) : 'Pick a time'}</span>
        <span className="picker__icon">
          <Icon name="clock" />
        </span>
      </button>

      {open ? (
        <div ref={popup} className="popup popup--left select__menu picker__pop picker__pop--time">
          <input
            ref={input}
            className="input input--small time__type"
            value={typed}
            onChange={(e) => setTyped(e.target.value)}
            onKeyDown={onType}
            placeholder="Type a time, like 6:30 pm"
            aria-label="Type a time"
          />

          {typed.trim() ? (
            <span className="x-small subtle time__hint">
              {parsed ? `Press Enter for ${timeLabel(parsed) ?? parsed}` : 'Like 6:30 pm or 18:30'}
            </span>
          ) : null}

          <div ref={list} className="time__list" role="listbox" aria-label={label}>
            {timeSlots().map((t) => (
              <button
                key={t}
                type="button"
                role="option"
                className="popup__item time__slot"
                data-t={t}
                aria-selected={t === value}
                onClick={() => pick(t)}
              >
                <span className="select__check">{t === value ? <Icon name="check" /> : null}</span>
                <span>{timeLabel(t)}</span>
              </button>
            ))}
          </div>
        </div>
      ) : null}
    </div>
  );
}
