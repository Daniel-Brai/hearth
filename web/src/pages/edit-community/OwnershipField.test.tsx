import { act, fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { OwnershipField } from './OwnershipField';

function show(cid: string) {
  const store = new Store(createSeedState());
  const close = vi.fn();

  render(
    <StoreContext value={store}>
      <GatewayContext value={new MockGateway(store)}>
        <OwnershipField cid={cid} name="Programming Language Design" close={close} />
      </GatewayContext>
    </StoreContext>,
  );

  return { store, close };
}

describe('OwnershipField', () => {
  it('shows nothing to someone who does not own the community', () => {
    show('elixir');

    expect(screen.queryByRole('button', { name: 'Transfer ownership' })).toBeNull();
  });

  it('hands the community over once the emailed code is typed', async () => {
    const { store, close } = show('plang');

    fireEvent.click(screen.getByRole('button', { name: /New owner/ }));
    fireEvent.click(screen.getByText('Jonas Berg'));
    fireEvent.click(screen.getByRole('button', { name: 'Transfer ownership' }));

    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Email me a code' })));

    expect(screen.getByRole('group', { name: 'Transfer code, 6 digits' })).toBeTruthy();

    await act(async () =>
      fireEvent.change(screen.getByRole('textbox', { name: 'Digit 1' }), {
        target: { value: '042917' },
      }),
    );

    expect(close).toHaveBeenCalled();
    expect(store.get().communities.plang?.maintainer).not.toBe(store.get().me);
  });
});
