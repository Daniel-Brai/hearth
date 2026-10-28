import { useEffect, useLayoutEffect, useRef, useState, type KeyboardEvent } from 'react';
import { addDays, addMonths, isBefore, startOfDay } from 'date-fns';
import { Button, Icon, cn, orientPopup } from '@/design-system';
import {
  calendarDays,
  dayKey,
  dayLabel,
  isPastDay,
  monthLabel,
  parseDay,
  shiftMonth,
  weekdayLabels,
} from './date-time';
import { usePopover } from './use-popover';

const STEPS: Record<string, number> = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 };

export type DatePickerProps = {
  readonly value: string | null;
  readonly onChange: (next: string) => void;
  readonly label: string;
  readonly futureOnly?: boolean | undefined;
};

export function DatePicker({ value, onChange, label, futureOnly }: DatePickerProps) {
  const { open, setOpen, root, button, close } = usePopover();
  const popup = useRef<HTMLDivElement>(null);

  const [month, setMonth] = useState(() => parseDay(value) ?? new Date());
  const [focus, setFocus] = useState(() => parseDay(value) ?? new Date());

  const [today] = useState(() => new Date());
  const focusKey = dayKey(focus);

  useLayoutEffect(() => {
    if (open && popup.current) orientPopup(popup.current);
  }, [open]);

  useEffect(() => {
    if (!open) return;
    popup.current?.querySelector<HTMLElement>(`[data-day="${focusKey}"]`)?.focus();
  }, [open, focusKey]);

  const toggle = () => {
    if (!open) {
      const start = parseDay(value) ?? new Date();
      setMonth(start);
      setFocus(start);
    }
    setOpen(!open);
  };

  const pick = (key: string) => {
    onChange(key);
    close();
  };

  const canPrev = !futureOnly || isBefore(startOfDay(today), shiftMonth(month, 0));

  const onKey = (e: KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.stopPropagation();
      e.preventDefault();
      close();

      return;
    }

    const step = STEPS[e.key];
    let next: Date | null = null;

    if (step !== undefined) next = addDays(focus, step);
    else if (e.key === 'PageUp') next = addMonths(focus, -1);
    else if (e.key === 'PageDown') next = addMonths(focus, 1);

    if (!next) return;

    e.preventDefault();
    if (futureOnly && isPastDay(next)) return;

    setFocus(next);
    setMonth(next);
  };

  return (
    <div ref={root} className="select select--block picker">
      <button
        ref={button}
        type="button"
        className="select__button"
        onClick={toggle}
        aria-expanded={open}
        aria-haspopup="dialog"
        aria-label={label}
      >
        <span className="truncate">{value ? dayLabel(value) : 'Pick a date'}</span>
        <span className="picker__icon">
          <Icon name="calendar" />
        </span>
      </button>

      {open ? (
        // react-doctor-disable-next-line react-doctor/prefer-html-dialog -- a non-modal popover anchored to its button; a <dialog> would bring modal positioning and styles
        <div
          ref={popup}
          className="popup popup--left select__menu picker__pop"
          role="dialog"
          aria-label={label}
          onKeyDown={onKey}
        >
          <div className="cal__head">
            <Button
              size="tiny"
              circle
              variant="borderless"
              onClick={() => setMonth(shiftMonth(month, -1))}
              disabled={!canPrev}
              aria-label="Previous month"
            >
              <Icon name="back" />
            </Button>
            <strong className="small">{monthLabel(month)}</strong>
            <Button
              size="tiny"
              circle
              variant="borderless"
              onClick={() => setMonth(shiftMonth(month, 1))}
              aria-label="Next month"
            >
              <Icon name="back" style={{ rotate: '180deg' }} />
            </Button>
          </div>

          <div className="cal__grid" role="grid">
            {weekdayLabels().map((w) => (
              <span key={w.key} className="cal__dow">
                {w.label}
              </span>
            ))}

            {calendarDays(month).map((c) => {
              const date = parseDay(c.key);

              return (
                <button
                  key={c.key}
                  type="button"
                  role="gridcell"
                  className={cn(
                    'cal__day',
                    !c.inMonth && 'is-out',
                    c.key === dayKey(today) && 'is-today',
                    c.key === value && 'is-on',
                  )}
                  disabled={!!futureOnly && !!date && isPastDay(date)}
                  tabIndex={c.key === focusKey ? 0 : -1}
                  data-day={c.key}
                  aria-label={dayLabel(c.key) ?? undefined}
                  aria-selected={c.key === value}
                  onClick={() => pick(c.key)}
                >
                  {c.day}
                </button>
              );
            })}
          </div>

          <div className="cal__foot">
            <Button size="tiny" variant="borderless" onClick={() => pick(dayKey(today))}>
              Today
            </Button>
            <Button
              size="tiny"
              variant="borderless"
              onClick={() => pick(dayKey(addDays(today, 1)))}
            >
              Tomorrow
            </Button>
            <Button
              size="tiny"
              variant="borderless"
              onClick={() => pick(dayKey(addDays(today, 7)))}
            >
              In a week
            </Button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
