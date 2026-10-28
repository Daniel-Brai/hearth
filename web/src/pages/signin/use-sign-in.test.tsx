import { act, renderHook } from '@testing-library/react';
import { Suspense, type ReactNode } from 'react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import { createSeedState } from '@/mocks/seed';
import { useSignIn } from './use-sign-in';

function wrapper(gateway: MockGateway, store: Store) {
  const cache = new LoadCache();

  return ({ children }: { readonly children: ReactNode }) => (
    <LoadCacheContext value={cache}>
      <StoreContext value={store}>
        <GatewayContext value={gateway}>
          <MemoryRouter initialEntries={['/signin']}>
            <Suspense fallback={null}>{children}</Suspense>
          </MemoryRouter>
        </GatewayContext>
      </StoreContext>
    </LoadCacheContext>
  );
}

describe('useSignIn', () => {
  it('stops spinning when the browser brings the page back after leaving for GitHub', async () => {
    const store = new Store(createSeedState());
    const gateway = new MockGateway(store);

    // The browser leaves for GitHub before the call settles
    gateway.session.oauth = () => new Promise(() => undefined);

    let hook!: { readonly result: { readonly current: ReturnType<typeof useSignIn> } };

    await act(async () => {
      hook = renderHook(() => useSignIn(), { wrapper: wrapper(gateway, store) });
    });

    const { result } = hook;

    act(() => void result.current.oauth('GitHub'));
    expect(result.current.busy).toBe(true);

    act(() => {
      window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true }));
    });

    expect(result.current.busy).toBe(false);
  });
});
