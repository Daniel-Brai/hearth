import {
  useEffect,
  useId,
  useLayoutEffect,
  useRef,
  useState,
  type KeyboardEvent,
  type ReactNode,
} from 'react';
import { cn } from './cn';
import { Icon } from '@/design-system/icons/Icon';
import { orientPopup } from './orient';

export type SelectOption<T extends string> = {
  readonly value: T;
  readonly label: ReactNode;
  readonly hint?: ReactNode | undefined;
  readonly count?: boolean | undefined;
  readonly disabled?: boolean | undefined;
};

export type SelectProps<T extends string> = {
  readonly value: T;
  readonly options: readonly SelectOption<T>[];
  readonly onChange: (next: T) => void;
  readonly label: string;
  readonly block?: boolean | undefined;
  readonly chip?: boolean | undefined;
  readonly inline?: boolean | undefined;
  readonly className?: string | undefined;
  readonly id?: string | undefined;
  // A box at the top of the menu narrows the options by their label and hint
  readonly searchable?: boolean | undefined;
  readonly searchLabel?: string | undefined;
};

const plain = (label: ReactNode): string | undefined =>
  typeof label === 'string' ? label : undefined;

const matches = <T extends string>(o: SelectOption<T>, query: string) =>
  `${plain(o.label) ?? ''} ${plain(o.hint) ?? ''}`.toLowerCase().includes(query);

export function Select<T extends string>({
  value,
  options,
  onChange,
  label,
  block,
  chip,
  inline,
  className,
  id,
  searchable,
  searchLabel = 'Search',
}: SelectProps<T>) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const search = useRef<HTMLInputElement>(null);
  const root = useRef<HTMLDivElement>(null);
  const button = useRef<HTMLButtonElement>(null);
  const list = useRef<HTMLDivElement>(null);
  const listId = useId();
  const current = options.find((o) => o.value === value) ?? options[0];

  const typed = query.trim().toLowerCase();
  const shown = typed ? options.filter((o) => matches(o, typed)) : options;

  useEffect(() => {
    if (!open) return;

    const onDown = (e: PointerEvent) => {
      if (root.current && !root.current.contains(e.target as Node)) setOpen(false);
    };

    document.addEventListener('pointerdown', onDown, true);

    return () => document.removeEventListener('pointerdown', onDown, true);
  }, [open]);

  useLayoutEffect(() => {
    if (!open || !list.current) return;
    orientPopup(list.current);

    if (search.current) return search.current.focus();

    const selected =
      list.current.querySelector<HTMLElement>('[aria-selected="true"]') ??
      list.current.querySelector<HTMLElement>('[role=option]');

    selected?.focus();
  }, [open]);

  const toggle = () => {
    setQuery('');
    setOpen((o) => !o);
  };

  const pick = (v: T) => {
    onChange(v);
    setOpen(false);
    button.current?.focus();
  };

  const onKey = (e: KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.stopPropagation();
      e.preventDefault();
      setOpen(false);
      button.current?.focus();

      return;
    }

    if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
    e.preventDefault();

    if (!open) {
      toggle();
      return;
    }

    const items = Array.from(list.current?.querySelectorAll<HTMLElement>('[role=option]') ?? []);
    const i = items.indexOf(document.activeElement as HTMLElement);

    items[Math.max(0, Math.min(items.length - 1, i + (e.key === 'ArrowDown' ? 1 : -1)))]?.focus();
  };

  return (
    <div
      ref={root}
      className={cn(
        'select',
        block && 'select--block',
        chip && 'select--chip',
        searchable && 'select--search',
        inline && 'select-inline',
        className,
      )}
      onKeyDown={onKey}
    >
      <button
        ref={button}
        id={id}
        type="button"
        className="select__button"
        onClick={toggle}
        aria-expanded={open}
        aria-haspopup="listbox"
        aria-controls={listId}
        aria-label={typeof current?.label === 'string' ? `${label}: ${current.label}` : label}
      >
        <span className="truncate" title={plain(current?.label)}>
          {current?.label}
        </span>
        <Icon name="chevron" />
      </button>
      {open ? (
        <div ref={list} className="popup popup--left select__menu">
          {searchable ? (
            <div className="select__search">
              <Icon name="search" />
              <input
                ref={search}
                type="search"
                value={query}
                placeholder={searchLabel}
                aria-label={searchLabel}
                aria-controls={listId}
                autoComplete="off"
                spellCheck={false}
                onChange={(e) => setQuery(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key !== 'Enter') return;

                  e.preventDefault();

                  const first = shown.find((o) => !o.disabled);
                  if (first) pick(first.value);
                }}
              />
            </div>
          ) : null}

          <div id={listId} className="select__options" role="listbox" aria-label={label}>
            {shown.map((o) => (
              <button
                key={o.value}
                type="button"
                role="option"
                className="popup__item"
                aria-selected={o.value === value}
                disabled={o.disabled}
                onClick={() => pick(o.value)}
              >
                <span className="select__check">
                  {o.value === value ? <Icon name="check" /> : null}
                </span>
                <span className="truncate" title={plain(o.label)}>
                  {o.label}
                </span>
                {o.hint !== undefined && o.hint !== null ? (
                  <span className={cn('hint', o.count && 'hint--count')}>{o.hint}</span>
                ) : null}
              </button>
            ))}

            {shown.length ? null : <p className="select__empty">Nothing matches</p>}
          </div>
        </div>
      ) : null}
    </div>
  );
}
