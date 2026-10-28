import { act, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { EmailUndoPage } from './EmailUndoPage';

async function show(path: string) {
  const store = new Store(createSeedState());

  await act(async () =>
    render(
      <MemoryRouter initialEntries={[path]}>
        <StoreContext value={store}>
          <GatewayContext value={new MockGateway(store)}>
            <EmailUndoPage />
          </GatewayContext>
        </StoreContext>
      </MemoryRouter>,
    ),
  );
}

describe('EmailUndoPage', () => {
  it('fails a link with no token', async () => {
    await show('/settings/email/undo');

    expect(screen.getByText("This link doesn't work")).toBeTruthy();
  });

  it('puts the old address back', async () => {
    await show('/settings/email/undo#token=abc');

    expect(screen.getByText('Your email is back')).toBeTruthy();
  });
});
