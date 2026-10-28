import type { CSSProperties } from 'react';
import { ICONS, type IconName } from './icons';
import { ILLOS, type IlloName } from './illos';

export type IconProps = {
  readonly name: IconName;
  readonly className?: string | undefined;
  readonly style?: CSSProperties | undefined;
  readonly label?: string | undefined;
};

export function Icon({ name, className, style, label }: IconProps) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden={label ? undefined : 'true'}
      role={label ? 'img' : undefined}
      aria-label={label}
      className={className}
      style={style}
      dangerouslySetInnerHTML={{ __html: ICONS[name] }}
    />
  );
}

export function Illo({ name }: { readonly name: IlloName }) {
  return <span className="contents" dangerouslySetInnerHTML={{ __html: ILLOS[name] }} />;
}

export { ICONS };

export type { IconName, IlloName };
