import { useEffect, useRef, type ClipboardEvent, type KeyboardEvent } from 'react';
import { Input } from '@/design-system';
import './CodeBoxes.css';

const LENGTH = 6;

const digitsOf = (text: string) =>
  [...text]
    .filter((ch) => ch >= '0' && ch <= '9')
    .join('')
    .slice(0, LENGTH);

const digitAt = (code: string, i: number): string => code.charAt(i);

export type CodeBoxesProps = {
  readonly id: string;
  readonly label: string;
  readonly code: string;
  readonly busy: boolean;
  readonly shake: boolean;
  readonly onChange: (code: string) => void;
};

export function CodeBoxes({ id, label, code, busy, shake, onChange }: CodeBoxesProps) {
  const boxes = useRef<(HTMLInputElement | null)[]>([]);

  useEffect(() => {
    if (!busy && code === '') boxes.current[0]?.focus();
  }, [busy, code]);

  const update = (next: string, focusAt: number) => {
    onChange(digitsOf(next));
    boxes.current[Math.min(focusAt, LENGTH - 1)]?.focus();
  };

  const type = (value: string, i: number) => {
    const digits = digitsOf(value);

    if (!digits) return;

    update(code.slice(0, i) + digits + code.slice(i + 1), i + digits.length);
  };

  const press = (e: KeyboardEvent<HTMLInputElement>, i: number) => {
    if (e.key === 'Backspace') {
      e.preventDefault();

      if (e.currentTarget.value) update(code.slice(0, i) + code.slice(i + 1), i);
      else if (i > 0) update(code.slice(0, i - 1) + code.slice(i), i - 1);

      return;
    }

    if (e.key === 'ArrowLeft' && i > 0) {
      e.preventDefault();
      boxes.current[i - 1]?.focus();
      return;
    }

    if (e.key === 'ArrowRight' && i < LENGTH - 1) {
      e.preventDefault();
      boxes.current[i + 1]?.focus();
    }
  };

  const paste = (e: ClipboardEvent<HTMLDivElement>) => {
    e.preventDefault();

    const digits = digitsOf(e.clipboardData.getData('text'));
    update(digits, digits.length);
  };

  return (
    <div
      className="code-boxes"
      id={id}
      role="group"
      aria-label={`${label}, 6 digits`}
      onPaste={paste}
    >
      {Array.from({ length: LENGTH }, (_, i) => (
        <Input
          key={i}
          ref={(el) => {
            boxes.current[i] = el;
          }}
          className="code-box"
          shake={shake}
          type="text"
          inputMode="numeric"
          pattern="[0-9]*"
          // Autofill puts the whole code in the first box so a cap of 1 would cut it
          maxLength={LENGTH}
          autoComplete={i === 0 ? 'one-time-code' : 'off'}
          value={digitAt(code, i)}
          aria-label={'Digit ' + (i + 1)}
          disabled={busy}
          onChange={(e) => type(e.target.value, i)}
          onKeyDown={(e) => press(e, i)}
          onFocus={(e) => e.target.select()}
        />
      ))}
    </div>
  );
}
