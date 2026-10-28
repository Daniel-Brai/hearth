import { fireEvent, render, screen } from '@testing-library/react';
import { useState } from 'react';
import { describe, expect, it } from 'vitest';
import { Select } from './select';

const OPTIONS = [
  { value: 'ada', label: 'Ada Obi', hint: '@ada' },
  { value: 'lin', label: 'Lin Chen', hint: '@linchen' },
] as const;

function Members() {
  const [value, setValue] = useState<string>('ada');

  return (
    <>
      <Select value={value} options={OPTIONS} onChange={setValue} label="Member" searchable />
      <output>{value}</output>
    </>
  );
}

describe('Select', () => {
  it('says when nothing matches the search', () => {
    render(<Members />);

    fireEvent.click(screen.getByRole('button', { name: 'Member: Ada Obi' }));
    fireEvent.change(screen.getByRole('searchbox', { name: 'Search' }), {
      target: { value: 'zz' },
    });

    expect(screen.queryAllByRole('option')).toHaveLength(0);
    expect(screen.getByText('Nothing matches')).toBeTruthy();
  });

  it('narrows by name or handle and picks the first match on enter', () => {
    render(<Members />);

    fireEvent.click(screen.getByRole('button', { name: 'Member: Ada Obi' }));

    const search = screen.getByRole('searchbox', { name: 'Search' });

    fireEvent.change(search, { target: { value: 'linch' } });

    expect(screen.getAllByRole('option').map((o) => o.textContent)).toEqual(['Lin Chen@linchen']);

    fireEvent.keyDown(search, { key: 'Enter' });

    expect(screen.getByRole('status').textContent).toBe('lin');
  });
});
