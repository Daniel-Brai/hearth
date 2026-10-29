import { useSignedInHint } from '@/app/request-context';
import { useAppState } from '@/data/store';
import { AppShell } from './AppShell';
import { PublicShell } from './PublicShell';

export function SessionShell() {
  const hint = useSignedInHint();

  // The server can't tell who is signed in so the hint keeps the app frame in place
  // while the browser restores the session
  const framed = useAppState((state) => state.me !== null || (hint && state.session === 'pending'));

  return framed ? <AppShell /> : <PublicShell />;
}
