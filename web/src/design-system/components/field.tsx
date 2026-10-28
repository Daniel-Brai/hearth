import {
  forwardRef,
  type ChangeEvent,
  type CSSProperties,
  type InputHTMLAttributes,
  type ReactNode,
  type TextareaHTMLAttributes,
} from 'react';
import { cn } from './cn';
import { countText, tintStyle } from '@/domain/format';
import { Icon, type IconName } from '@/design-system/icons/Icon';

export function Field({
  label,
  hint,
  error,
  className,
  children,
  as: Tag = 'label',
}: {
  readonly label?: ReactNode | undefined;
  readonly hint?: ReactNode | undefined;
  readonly error?: string | null | undefined;
  readonly className?: string | undefined;
  readonly children: ReactNode;
  readonly as?: 'label' | 'div' | undefined;
}) {
  return (
    <Tag className={cn('field', className)}>
      {label ? <span className="field__label">{label}</span> : null}
      {hint ? <span className="field__hint">{hint}</span> : null}
      {children}
      {error ? (
        <span className="field__error" role="alert">
          {error}
        </span>
      ) : null}
    </Tag>
  );
}

type InputProps = Omit<InputHTMLAttributes<HTMLInputElement>, 'className'> & {
  readonly className?: string | undefined;
  readonly bare?: boolean | undefined;
  readonly shake?: boolean | undefined;
};

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { className, bare, shake, ...rest },
  ref,
) {
  return (
    <input
      ref={ref}
      className={cn('input', bare && 'input--bare', shake && 'shake', className)}
      {...rest}
    />
  );
});

type TextareaProps = Omit<TextareaHTMLAttributes<HTMLTextAreaElement>, 'className' | 'value'> & {
  readonly className?: string | undefined;
  readonly value: string;
  readonly bare?: boolean | undefined;
  readonly shake?: boolean | undefined;
  readonly countFrom?: number | undefined;
};

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(function Textarea(
  { className, bare, shake, maxLength, countFrom, value, ...rest },
  ref,
) {
  const field = (
    <textarea
      ref={ref}
      className={cn('input', bare && 'input--bare', shake && 'shake', className)}
      maxLength={maxLength}
      value={value}
      {...rest}
    />
  );

  if (!maxLength) return field;

  const show = countFrom === undefined || value.length >= countFrom;

  return (
    <span className="count-wrap">
      {field}
      {show ? (
        <span
          className={cn(
            'char-count char-count--inset',
            value.length >= maxLength * 0.9 && 'is-near',
          )}
          aria-hidden="true"
        >
          {countText(value, maxLength)}
        </span>
      ) : null}
    </span>
  );
});

export function InputWithPrefix({
  prefix,
  icon,
  className,
  ...rest
}: InputProps & { readonly prefix?: ReactNode; readonly icon?: IconName }) {
  return (
    <span className={cn('input-with-prefix', className)}>
      <span>{icon ? <Icon name={icon} /> : prefix}</span>
      <input className="input" {...rest} />
    </span>
  );
}

export function Switch({
  checked,
  onChange,
  disabled,
  label,
}: {
  readonly checked: boolean;
  readonly onChange: (next: boolean) => void;
  readonly disabled?: boolean | undefined;
  readonly label: string;
}) {
  return (
    <label className="switch">
      <input
        type="checkbox"
        checked={checked}
        disabled={disabled}
        aria-label={label}
        onChange={(e: ChangeEvent<HTMLInputElement>) => onChange(e.target.checked)}
      />
      <span className="switch__track" />
    </label>
  );
}

export type Option<T extends string> = {
  readonly value: T;
  readonly label: ReactNode;
  readonly disabled?: boolean | undefined;
  readonly tip?: string | undefined;
};

export function Segmented<T extends string>({
  name,
  value,
  options,
  onChange,
  label,
  tiny,
  className,
}: {
  readonly name: string;
  readonly value: T;
  readonly options: readonly Option<T>[];
  readonly onChange: (next: T) => void;
  readonly label: string;
  readonly tiny?: boolean | undefined;
  readonly className?: string | undefined;
}) {
  return (
    <div
      className={cn('segmented', tiny && 'segmented--tiny', className)}
      role="radiogroup"
      aria-label={label}
    >
      {options.map((o) => (
        <label key={o.value} className={cn(o.disabled && 'is-disabled')} data-tip={o.tip}>
          <input
            type="radio"
            name={name}
            value={o.value}
            checked={value === o.value}
            disabled={o.disabled}
            onChange={() => onChange(o.value)}
          />
          {o.label}
        </label>
      ))}
    </div>
  );
}

export type Tile<T extends string> = {
  readonly value: T;
  readonly icon?: IconName | undefined;
  readonly label: ReactNode;
  readonly sub?: ReactNode | undefined;
};

export function ChoiceTiles<T extends string>({
  name,
  value,
  tiles,
  onChange,
  label,
}: {
  readonly name: string;
  readonly value: T;
  readonly tiles: readonly Tile<T>[];
  readonly onChange: (next: T) => void;
  readonly label: string;
}) {
  return (
    <div className="choice-tiles" role="radiogroup" aria-label={label}>
      {tiles.map((t) => (
        <label key={t.value} className="choice-tile">
          <input
            type="radio"
            name={name}
            value={t.value}
            checked={value === t.value}
            onChange={() => onChange(t.value)}
          />
          {t.icon ? <Icon name={t.icon} /> : null}
          <span>{t.label}</span>
          {t.sub ? <small>{t.sub}</small> : null}
        </label>
      ))}
    </div>
  );
}

export function Swatches<T extends string>({
  name,
  value,
  hues,
  onChange,
}: {
  readonly name: string;
  readonly value: T;
  readonly hues: readonly T[];
  readonly onChange: (next: T) => void;
}) {
  return (
    <div className="swatches" role="radiogroup" aria-label="Color">
      {hues.map((h) => (
        <label key={h} className="swatch" style={tintStyle(h) as CSSProperties} aria-label={h}>
          <input
            type="radio"
            className="sr-only"
            name={name}
            value={h}
            checked={value === h}
            onChange={() => onChange(h)}
          />
          {value === h ? <Icon name="check" /> : null}
        </label>
      ))}
    </div>
  );
}

export function CharCount({
  value,
  max,
  className,
}: {
  readonly value: string;
  readonly max: number;
  readonly className?: string;
}) {
  return (
    <span
      className={cn(
        'char-count',
        value.length >= max * 0.9 && 'is-near',
        value.length > max && 'is-over',
        className,
      )}
    >
      {countText(value, max)}
    </span>
  );
}
