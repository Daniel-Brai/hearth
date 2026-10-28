import type { AnchorHTMLAttributes, ButtonHTMLAttributes, ReactNode } from 'react';
import { type LinkProps } from 'react-router';
import { Link } from './link';
import { buttonClass, type Look } from './button-class';

type NativeButton = Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'className'>;

export type ButtonProps = NativeButton &
  Look & {
    readonly children?: ReactNode | undefined;
  };

export function Button({
  variant,
  size,
  circle,
  block,
  busy,
  on,
  className,
  type = 'button',
  ...rest
}: ButtonProps) {
  return (
    <button
      type={type}
      className={buttonClass({ variant, size, circle, block, busy, on, className })}
      aria-busy={busy || undefined}
      {...rest}
    />
  );
}

export type IconButtonProps = ButtonProps & { readonly 'aria-label': string };

export function IconButton({ size = 'small', ...rest }: IconButtonProps) {
  return <Button circle size={size} {...rest} />;
}

export type ButtonLinkProps = Omit<LinkProps, 'className'> & Look;

export function ButtonLink({
  variant,
  size,
  circle,
  block,
  busy,
  on,
  className,
  ...rest
}: ButtonLinkProps) {
  return (
    <Link
      className={buttonClass({ variant, size, circle, block, busy, on, className })}
      {...rest}
    />
  );
}

export type ExternalButtonLinkProps = Omit<AnchorHTMLAttributes<HTMLAnchorElement>, 'className'> &
  Look;

export function ExternalButtonLink({
  variant,
  size,
  circle,
  block,
  busy,
  on,
  className,
  ...rest
}: ExternalButtonLinkProps) {
  return (
    <a
      className={buttonClass({ variant, size, circle, block, busy, on, className })}
      rel="noopener"
      {...rest}
    />
  );
}
