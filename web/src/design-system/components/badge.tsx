import type { CSSProperties, HTMLAttributes, ReactNode } from 'react';
import { cn } from './cn';
import { tintStyle } from '@/domain/format';
import { cap } from '@/domain/format';

type Base = Omit<HTMLAttributes<HTMLSpanElement>, 'className'> & { readonly className?: string };

export function Badge({
  count,
  red,
  corner,
  text,
  className,
  children,
  ...rest
}: Base & {
  readonly count?: number | undefined;
  readonly red?: boolean | undefined;
  readonly corner?: boolean | undefined;
  readonly text?: boolean | undefined;
  readonly children?: ReactNode | undefined;
}) {
  if (count === 0) return null;

  return (
    <span
      className={cn(
        'badge',
        red && 'badge--red',
        corner && 'badge--corner',
        text && 'badge--text',
        className,
      )}
      {...rest}
    >
      {count === undefined ? children : cap(count)}
    </span>
  );
}

export function Pill({
  tint,
  solid,
  live,
  className,
  children,
  ...rest
}: Base & {
  readonly tint?: string | null | undefined;
  readonly solid?: boolean | undefined;
  readonly live?: boolean | undefined;
  readonly children?: ReactNode | undefined;
}) {
  const style: CSSProperties | undefined = tint ? (tintStyle(tint) as CSSProperties) : undefined;
  return (
    <span
      className={cn(
        'pill',
        tint && !solid && 'pill--tinted',
        solid && 'pill--solid',
        live && 'pill--live',
        className,
      )}
      style={style}
      {...rest}
    >
      {children}
    </span>
  );
}

export function Label({ className, children, ...rest }: Base & { readonly children?: ReactNode }) {
  return (
    <span className={cn('label', className)} {...rest}>
      {children}
    </span>
  );
}

export function LiveDot({ className }: { readonly className?: string }) {
  return <span className={cn('live-dot', className)} />;
}

export function Dot({
  green,
  className,
}: {
  readonly green?: boolean;
  readonly className?: string;
}) {
  return <span className={cn('dot', green && 'dot--green', className)} />;
}

export function Chip({
  on,
  onClick,
  className,
  children,
  'aria-pressed': pressed,
}: {
  readonly on?: boolean | undefined;
  readonly onClick?: (() => void) | undefined;
  readonly className?: string | undefined;
  readonly children?: ReactNode | undefined;
  readonly 'aria-pressed'?: boolean | undefined;
}) {
  return (
    <button
      type="button"
      className={cn('chip', on && 'is-on', className)}
      onClick={onClick}
      aria-pressed={pressed ?? (onClick ? on : undefined)}
    >
      {children}
    </button>
  );
}
