import { cn } from './cn';

type ButtonVariant =
  | 'default'
  | 'reversed'
  | 'link'
  | 'negative'
  | 'positive'
  | 'borderless'
  | 'plain'
  | 'quiet'
  | 'danger-text';

type ButtonSize = 'normal' | 'small' | 'tiny';

export type Look = {
  variant?: ButtonVariant | undefined;
  size?: ButtonSize | undefined;
  circle?: boolean | undefined;
  block?: boolean | undefined;
  busy?: boolean | undefined;
  on?: boolean | undefined;
  className?: string | undefined;
};

const VARIANT_CLASS: Record<ButtonVariant, string | null> = {
  default: null,
  reversed: 'btn--reversed',
  link: 'btn--link',
  negative: 'btn--negative',
  positive: 'btn--positive',
  borderless: 'btn--borderless',
  plain: 'btn--plain',
  quiet: 'btn--quiet',
  'danger-text': 'btn--danger-text',
};

const SIZE_CLASS: Record<ButtonSize, string | null> = {
  normal: null,
  small: 'btn--small',
  tiny: 'btn--tiny',
};

export const buttonClass = ({
  variant = 'default',
  size = 'normal',
  circle = false,
  block = false,
  busy = false,
  on = false,
  className,
}: Look) =>
  cn(
    'btn',
    VARIANT_CLASS[variant],
    SIZE_CLASS[size],
    circle && 'btn--circle',
    block && 'btn--block',
    busy && 'is-busy',
    on && 'is-on',
    className,
  );
