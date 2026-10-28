import { fireEvent, render, screen } from '@testing-library/react';
import { useState } from 'react';
import { describe, expect, it } from 'vitest';
import { CodeBoxes } from './CodeBoxes';

function Boxes() {
  const [code, setCode] = useState('');

  return (
    <>
      <CodeBoxes
        id="test-code"
        label="Test code"
        code={code}
        busy={false}
        shake={false}
        onChange={setCode}
      />
      <output>{code}</output>
    </>
  );
}

const box = (n: number) => screen.getByRole('textbox', { name: `Digit ${n}` });

describe('CodeBoxes', () => {
  it('ignores what is not a digit', () => {
    render(<Boxes />);

    fireEvent.change(box(1), { target: { value: 'x' } });

    expect(screen.getByRole('status').textContent).toBe('');
  });

  it('spreads a whole code put into the first box across all six', () => {
    render(<Boxes />);

    fireEvent.change(box(1), { target: { value: '940030' } });

    expect(screen.getByRole('status').textContent).toBe('940030');
    expect(box(6)).toHaveProperty('value', '0');
  });

  // The browser cuts typed text to maxLength before the app sees it
  it('lets a box take a whole code, as autofill and password managers send it', () => {
    render(<Boxes />);

    expect(Number(box(1).getAttribute('maxlength'))).toBeGreaterThanOrEqual(6);
  });
});
