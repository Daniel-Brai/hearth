import { renderHook } from '@testing-library/react';
import type { ReactNode } from 'react';
import { describe, expect, it } from 'vitest';
import { RequestContext } from '@/app/request-context';
import { emptyState } from '@/data/empty-state';
import { Store, StoreContext } from '@/data/store';
import type { SessionPhase } from '@/domain/app-state';
import { useGate, useViewer, viewerOf } from './use-guest';

describe('viewerOf', () => {
  it('is a guest without the hint whatever the session', () => {
    expect(viewerOf({ me: null, session: 'pending' }, false)).toBe('guest');
    expect(viewerOf({ me: null, session: 'loading' }, false)).toBe('guest');
  });

  it('is unknown while what they joined still loads', () => {
    expect(viewerOf({ me: 'u1', session: 'loading' }, true)).toBe('unknown');
  });

  it('is unknown with the hint until the session settles', () => {
    expect(viewerOf({ me: null, session: 'pending' }, true)).toBe('unknown');
    expect(viewerOf({ me: null, session: 'loading' }, true)).toBe('unknown');
  });

  it('is a guest once the restore finds nobody', () => {
    expect(viewerOf({ me: null, session: 'out' }, true)).toBe('guest');
  });

  it('is a member once there is a person', () => {
    expect(viewerOf({ me: 'u1', session: 'ready' }, true)).toBe('member');
    expect(viewerOf({ me: 'u1', session: 'ready' }, false)).toBe('member');
  });
});

function render<T>(hook: () => T, signedIn: boolean, session: SessionPhase, me: string | null) {
  const store = new Store({ ...emptyState(), session, me });
  const request = { origin: 'https://hearth.example', zone: 'UTC', signedIn, setStatus: () => {} };

  const Wrapper = ({ children }: { readonly children: ReactNode }) => (
    <RequestContext value={request}>
      <StoreContext value={store}>{children}</StoreContext>
    </RequestContext>
  );

  return renderHook(hook, { wrapper: Wrapper }).result.current;
}

describe('useViewer', () => {
  it('reads the hint from the request context', () => {
    expect(render(useViewer, true, 'pending', null)).toBe('unknown');
    expect(render(useViewer, false, 'pending', null)).toBe('guest');
  });
});

describe('useGate', () => {
  it('waits for the viewer of a community that is not public', () => {
    expect(render(() => useGate('secret'), true, 'pending', null)).toBe('pending');
  });

  it('stops a guest at the wall', () => {
    expect(render(() => useGate('secret'), false, 'out', null)).toBe('wall');
  });

  it('lets a member in', () => {
    expect(render(() => useGate('secret'), true, 'ready', 'u1')).toBe('open');
  });
});
