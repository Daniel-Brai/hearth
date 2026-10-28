import { useAppState } from '@/data/store';
import { AppShell } from './AppShell';
import { PublicShell } from './PublicShell';

export function SessionShell() {
  const signedIn = useAppState((state) => state.me !== null);

  return signedIn ? <AppShell /> : <PublicShell />;
}
