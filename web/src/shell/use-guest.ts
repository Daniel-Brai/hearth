import { useLocation, useNavigate } from 'react-router';
import { useAppState } from '@/data/store';
import { routes } from '@/runtime/routes';

export function useGuest() {
  const guest = useAppState((state) => state.me === null);
  const navigate = useNavigate();
  const location = useLocation();

  const signIn = () =>
    void navigate(
      routes.signIn + '?next=' + encodeURIComponent(location.pathname + location.search),
    );

  return { guest, signIn };
}

export function useGuestBlocked(cid: string | null | undefined): boolean {
  return useAppState(
    (state) => state.me === null && !!cid && state.communities[cid]?.visibility !== 'public',
  );
}
