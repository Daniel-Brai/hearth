import { useEffect, useRef, type CSSProperties, type MouseEvent, type ReactNode } from 'react';
import { cn } from './cn';
import { Icon } from '@/design-system/icons/Icon';
import { IconButton } from './button';

export type DialogProps = {
  readonly open: boolean;
  readonly onClose: () => void;
  readonly width?: string | undefined;
  readonly className?: string | undefined;
  readonly label?: string | undefined;
  readonly labelledBy?: string | undefined;
  readonly closeOnBackdrop?: boolean | undefined;
  readonly children: ReactNode;
};

export function Dialog({
  open,
  onClose,
  width,
  className,
  label,
  labelledBy,
  closeOnBackdrop = true,
  children,
}: DialogProps) {
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    if (open && !el.open) el.showModal();
    else if (!open && el.open) el.close();
  }, [open]);

  const onBackdrop = (e: MouseEvent<HTMLDialogElement>) => {
    if (closeOnBackdrop && e.target === e.currentTarget) onClose();
  };

  const style = width ? ({ '--dialog-width': width } as CSSProperties) : undefined;

  return (
    // react-doctor-disable-next-line react-doctor/no-noninteractive-element-interactions -- backdrop click is a pointer shortcut only; Escape and the close button cover keyboard users
    <dialog
      ref={ref}
      className={cn('dialog', className)}
      style={style}
      aria-label={label}
      aria-labelledby={labelledBy}
      onClose={onClose}
      onClick={onBackdrop}
    >
      {open ? children : null}
    </dialog>
  );
}

export function DialogClose({ onClick }: { readonly onClick: () => void }) {
  return (
    <IconButton variant="borderless" className="dialog__close" onClick={onClick} aria-label="Close">
      <Icon name="x" />
    </IconButton>
  );
}

export function DialogBody({
  className,
  children,
  ...rest
}: {
  readonly className?: string;
  readonly children: ReactNode;
  readonly id?: string;
}) {
  return (
    <div className={cn('dialog__body', className)} {...rest}>
      {children}
    </div>
  );
}

export function DialogTitle({
  id,
  children,
}: {
  readonly id?: string;
  readonly children: ReactNode;
}) {
  return (
    <h2 className="dialog__title" id={id}>
      {children}
    </h2>
  );
}

export function DialogFooter({ children }: { readonly children: ReactNode }) {
  return <div className="dialog__footer">{children}</div>;
}
