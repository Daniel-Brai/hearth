import { act, fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it, vi } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { EmailDialog } from './EmailDialog';

function show() {
  const store = new Store(createSeedState());
  const close = vi.fn();

  render(
    <MemoryRouter>
      <StoreContext value={store}>
        <GatewayContext value={new MockGateway(store)}>
          <EmailDialog onClose={close} />
        </GatewayContext>
      </StoreContext>
    </MemoryRouter>,
  );

  return { close };
}

describe('EmailDialog', () => {
  it('says why an address is refused', async () => {
    show();

    fireEvent.change(screen.getByLabelText('New email'), { target: { value: 'nope' } });
    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Send code' })));

    expect(screen.getByText('Enter an email address')).toBeTruthy();
  });

  it('moves to the code and closes once it is typed', async () => {
    const { close } = show();

    fireEvent.change(screen.getByLabelText('New email'), { target: { value: 'ada@new.example' } });
    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Send code' })));

    expect(screen.getByRole('group', { name: 'Email change code, 6 digits' })).toBeTruthy();

    await act(async () =>
      fireEvent.change(screen.getByRole('textbox', { name: 'Digit 1' }), {
        target: { value: '042917' },
      }),
    );

    expect(close).toHaveBeenCalled();
  });
});
