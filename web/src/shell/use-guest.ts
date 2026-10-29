import { useLocation, useNavigate } from 'react-router';
import { useSignedInHint } from '@/app/request-context';
import { useAppState } from '@/data/store';
import type { AppState } from '@/domain/app-state';
import { routes } from '@/runtime/routes';

/**
 * Who is looking. `unknown` covers a reload while the session restores and while what the person
 * joined still loads, so it never flashes the guest version. Without the signed in hint crawlers
 * and link previews always get the full public screen
 */
export type Viewer = 'guest' | 'member' | 'unknown';

export function viewerOf(state: Pick<AppState, 'me' | 'session'>, hint: boolean): Viewer {
  // Who you are arrives before what you joined so a member waits for both
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

/** Whether a screen of this community may show, wait for the viewer, or stop at the wall */
export function useGate(cid: string | null | undefined): Gate {
  const hint = useSignedInHint();

  return useAppState((state) => {
    if (!cid || state.communities[cid]?.visibility === 'public') return 'open';

    const viewer = viewerOf(state, hint);

    if (viewer === 'guest') return 'wall';

    return viewer === 'unknown' ? 'pending' : 'open';
  });
}
