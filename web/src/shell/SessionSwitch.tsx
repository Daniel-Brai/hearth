import type { ReactNode } from 'react';
import { useSignedInNow } from './use-signed-in';

export function SessionSwitch({
  signedIn,
  guest,
}: {
  readonly signedIn: ReactNode;
  readonly guest: ReactNode;
}) {
  const isSignedIn = useSignedInNow();

  return isSignedIn ? signedIn : guest;
}
