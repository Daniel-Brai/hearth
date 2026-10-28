import {
  useCallback,
  useEffect,
  useEffectEvent,
  useId,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type KeyboardEvent,
  type ReactNode,
} from 'react';
import { cn } from './cn';
import { MenuContext, useMenu } from './menu-context';
import { orientPopup } from './orient';
import { Icon, type IconName } from '@/design-system/icons/Icon';
import { Keys } from './keys';

export type MenuProps = {
  readonly trigger: (props: { open: boolean; toggle: () => void; id: string }) => ReactNode;
  readonly children: ReactNode;
  readonly up?: boolean | undefined;
  readonly left?: boolean | undefined;
  readonly className?: string | undefined;
  readonly popupClassName?: string | undefined;
  readonly onOpenChange?: ((open: boolean) => void) | undefined;
};

export function Menu({
  trigger,
  children,
  up,
  left,
  className,
  popupClassName,
  onOpenChange,
}: MenuProps) {
  const [open, setOpen] = useState(false);
  const anchor = useRef<HTMLDivElement>(null);
  const popup = useRef<HTMLDivElement>(null);
  const id = useId();

  const set = useCallback(
    (next: boolean) => {
      setOpen(next);
      onOpenChange?.(next);
    },
    [onOpenChange],
  );

  const close = useCallback(() => set(false), [set]);
  const context = useMemo(() => ({ close }), [close]);

  const onPointerDown = useEffectEvent((e: PointerEvent) => {
    if (anchor.current && !anchor.current.contains(e.target as Node)) close();
  });

  useEffect(() => {
    if (!open) return;

    const onDown = (e: PointerEvent) => onPointerDown(e);

    document.addEventListener('pointerdown', onDown, true);

    return () => document.removeEventListener('pointerdown', onDown, true);
  }, [open]);

  useLayoutEffect(() => {
    if (open && popup.current) orientPopup(popup.current);
  }, [open]);

  const onKey = (e: KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.stopPropagation();
      close();
      return;
    }

    if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;

    const items = Array.from(
      popup.current?.querySelectorAll<HTMLElement>('.popup__item:not([disabled])') ?? [],
    ).filter((el) => el.checkVisibility?.() ?? true);

    if (!items.length) return;
    e.preventDefault();

    const i = items.indexOf(document.activeElement as HTMLElement);
    const next = items[(i + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length];

    next?.focus();
  };

  return (
    <div ref={anchor} className={cn('menu-anchor', className)} onKeyDown={onKey}>
      {trigger({ open, toggle: () => set(!open), id })}
      {open ? (
        <MenuContext.Provider value={context}>
          <div
            ref={popup}
            id={id}
            role="menu"
            className={cn('popup', up && 'popup--up', left && 'popup--left', popupClassName)}
          >
            {children}
          </div>
        </MenuContext.Provider>
      ) : null}
    </div>
  );
}

export function MenuItem({
  icon,
  danger,
  keys,
  hint,
  onSelect,
  disabled,
  className,
  children,
}: {
  readonly icon?: IconName | undefined;
  readonly danger?: boolean | undefined;
  readonly keys?: string | undefined;
  readonly hint?: ReactNode | undefined;
  readonly onSelect?: (() => void) | undefined;
  readonly disabled?: boolean | undefined;
  readonly className?: string | undefined;
  readonly children: ReactNode;
}) {
  const ctx = useMenu();
  return (
    <button
      type="button"
      role="menuitem"
      className={cn('popup__item', danger && 'danger', className)}
      disabled={disabled}
      onClick={() => {
        ctx?.close();
        onSelect?.();
      }}
    >
      {icon ? <Icon name={icon} /> : null}
      {children}
      {keys ? <Keys combo={keys} /> : null}
      {hint ? <span className="hint">{hint}</span> : null}
    </button>
  );
}

export function MenuTitle({ children }: { readonly children: ReactNode }) {
  return <div className="popup__title">{children}</div>;
}
