import { useLocation, useNavigate } from 'react-router';

import { useSignedInHint } from '@/app/request-context';
import { useAppState } from '@/data/store';
import type { AppState } from '@/domain/app-state';
import { routes } from '@/runtime/routes';

/**
 * Unknown covers a reload while the session or what the person joined still loads so the guest
 * version never flashes. Without the signed in hint crawlers always get the public screen
 */
export type Viewer = 'guest' | 'member' | 'unknown';

export function viewerOf(state: Pick<AppState, 'me' | 'session'>, hint: boolean): Viewer {
  // A member waits for what they joined to load
  if (state.me !== null) return state.session === 'loading' ? 'unknown' : 'member';

  const settling = state.session === 'pending' || state.session === 'loading';

  return hint && settling ? 'unknown' : 'guest';
}

export function useViewer(): Viewer {
  const hint = useSignedInHint();

  return useAppState((state) => viewerOf(state, hint));
}

export function useGuest() {
  const viewer = useViewer();
  const navigate = useNavigate();
  const location = useLocation();

  const signIn = () =>
    void navigate(
      routes.signIn + '?next=' + encodeURIComponent(location.pathname + location.search),
    );

  return { viewer, guest: viewer === 'guest', signIn };
}

export type Gate = 'open' | 'wall' | 'pending';

export function useGate(cid: string | null | undefined): Gate {
  const hint = useSignedInHint();

  return useAppState((state) => {
    if (!cid || state.communities[cid]?.visibility === 'public') return 'open';

    const viewer = viewerOf(state, hint);

    if (viewer === 'guest') return 'wall';

    return viewer === 'unknown' ? 'pending' : 'open';
  });
}
