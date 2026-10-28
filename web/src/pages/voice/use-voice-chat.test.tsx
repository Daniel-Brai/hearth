import { act, renderHook } from '@testing-library/react';
import { Suspense, type ReactNode } from 'react';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { useVoiceChat } from './use-voice-chat';

const KEY = 'elixir/office-hours';

async function setup(open: boolean) {
  const store = new Store(createSeedState());

  const wrapper = ({ children }: { readonly children: ReactNode }) => (
    <LoadCacheContext value={new LoadCache()}>
      <StoreContext value={store}>
        <GatewayContext value={new MockGateway(store)}>
          <Suspense fallback={null}>{children}</Suspense>
        </GatewayContext>
      </StoreContext>
    </LoadCacheContext>
  );

  const hook = await act(async () =>
    renderHook(({ open }) => useVoiceChat(KEY, open), {
      wrapper,
      initialProps: { open },
    }),
  );

  const write = (who: string) =>
    act(() =>
      store.set((state) => {
        (state.chats[KEY] ??= []).push({
          id: 'new-' + who,
          who,
          text: 'Hi',
          time: 'now',
          boosts: [],
        });
      }),
    );

  return { hook, store, write };
}

describe('useVoiceChat', async () => {
  it('counts what was there on arrival as seen', async () => {
    const { hook } = await setup(false);

    expect(hook.result.current.unread).toBe(false);
  });

  it('ignores the person writing while the chat is closed', async () => {
    const { hook, store, write } = await setup(false);

    write(store.get().me!);

    expect(hook.result.current.unread).toBe(false);
  });

  it('flags a message from someone else while the chat is closed', async () => {
    const { hook, write } = await setup(false);

    write('lin');

    expect(hook.result.current.unread).toBe(true);
  });

  it('clears once the chat opens', async () => {
    const { hook, write } = await setup(false);

    write('lin');

    await act(async () => hook.rerender({ open: true }));

    expect(hook.result.current.unread).toBe(false);
  });
});
