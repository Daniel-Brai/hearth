import type { CSSProperties, ReactNode } from 'react';
import { cn } from './cn';
import { tintStyle } from '@/domain/format';
import { fadeIn } from './fade';

export type AvatarSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

const SIZE_CLASS: Record<AvatarSize, string | null> = {
  xs: 'avatar--xs',
  sm: 'avatar--sm',
  md: null,
  lg: 'avatar--lg',
  xl: 'avatar--xl',
};

export type AvatarProps = {
  readonly hue: string;
  readonly initials: string;
  readonly photo?: string | null | undefined;
  readonly size?: AvatarSize | undefined;
  readonly online?: boolean | undefined;
  readonly unread?: boolean | undefined;
  readonly className?: string | undefined;
  readonly children?: ReactNode | undefined;
};

const hueStyle = (hue: string): CSSProperties => ({ '--av': `var(--hue-${hue})` }) as CSSProperties;

export function Avatar({
  hue,
  initials,
  photo,
  size = 'md',
  online,
  unread,
  className,
  children,
}: AvatarProps) {
  return (
    <span
      className={cn('avatar', SIZE_CLASS[size], className)}
      style={hueStyle(hue)}
      data-initials={initials}
    >
      {photo ? <img src={photo} alt="" decoding="async" {...fadeIn} /> : null}
      {online ? <span className="presence-dot" aria-label="Online" /> : null}
      {unread ? <span className="unread-dot" aria-hidden="true" /> : null}
      {children}
    </span>
  );
}

export type CommunityMarkProps = {
  readonly hue: string;
  readonly letter: string;
  readonly logo?: string | null | undefined;
  readonly size?: string | undefined;
  readonly className?: string | undefined;
};

export function CommunityMark({ hue, letter, logo, size, className }: CommunityMarkProps) {
  const style: CSSProperties = {
    ...tintStyle(hue),
    ...(size ? { '--mark-size': size } : {}),
  } as CSSProperties;
  return (
    <span className={cn('community-mark', className)} style={style} data-initials={letter}>
      {logo ? <img src={logo} alt="" decoding="async" {...fadeIn} /> : null}
    </span>
  );
}
