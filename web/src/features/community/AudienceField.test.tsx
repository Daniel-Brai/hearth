import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { AudienceField } from './AudienceField';

describe('AudienceField', () => {
  it('offers all four and says which is picked', () => {
    const onChange = vi.fn();

    render(<AudienceField name="audience" value="invite" onChange={onChange} />);

    expect(screen.getAllByRole('radio')).toHaveLength(4);
    expect(screen.getByRole('radio', { name: /Invite only/ })).toBeChecked();

    fireEvent.click(screen.getByRole('radio', { name: /Private/ }));

    expect(onChange).toHaveBeenCalledWith('private');
  });
});
