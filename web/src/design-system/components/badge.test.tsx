import { render } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { Badge } from './badge';

describe('Badge', () => {
  it('never shows a count of nothing', () => {
    const { container } = render(<Badge red count={0} />);

    expect(container.querySelector('.badge')).toBeNull();
  });

  it('shows a real count', () => {
    const { container } = render(<Badge red count={3} />);

    expect(container.querySelector('.badge')?.textContent).toBe('3');
  });
});
