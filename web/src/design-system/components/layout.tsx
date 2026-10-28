import type { HTMLAttributes, ReactNode } from 'react';
import { cn } from './cn';

type Div = Omit<HTMLAttributes<HTMLDivElement>, 'className'> & { readonly className?: string };

export function Panel({ className, children, ...rest }: Div & { readonly children: ReactNode }) {
  return (
    <section className={cn('panel', className)} {...rest}>
      {children}
    </section>
  );
}

export function Separator({
  children,
  className,
  heading,
}: {
  readonly children?: ReactNode;
  readonly className?: string;
  readonly heading?: boolean | undefined;
}) {
  const Tag = heading ? 'h2' : 'div';

  return (
    <Tag className={cn('separator', className)}>
      <span>{children}</span>
    </Tag>
  );
}

export function OriginNote({
  live,
  oneLine,
  className,
  children,
  ...rest
}: Div & { readonly live?: boolean; readonly oneLine?: boolean; readonly children: ReactNode }) {
  return (
    <div
      className={cn(
        'origin-note',
        live && 'origin-note--live',
        oneLine && 'origin-note--oneline',
        className,
      )}
      {...rest}
    >
      {children}
    </div>
  );
}

export function SettingsRow({
  title,
  sub,
  children,
  className,
}: {
  readonly title: ReactNode;
  readonly sub?: ReactNode | undefined;
  readonly children?: ReactNode | undefined;
  readonly className?: string | undefined;
}) {
  return (
    <div className={cn('settings-row', className)}>
      <div>
        <strong className="small">{title}</strong>
        {sub ? <span className="x-small subtle">{sub}</span> : null}
      </div>
      {children}
    </div>
  );
}

export function Measure({
  narrow,
  read,
  className,
  children,
  ...rest
}: Div & { readonly narrow?: boolean; readonly read?: boolean; readonly children: ReactNode }) {
  return (
    <div
      className={cn('measure', narrow && 'measure--narrow', read && 'measure--read', className)}
      {...rest}
    >
      {children}
    </div>
  );
}
