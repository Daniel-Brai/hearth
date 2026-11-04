import type { ReactNode } from 'react';

import { useViewer } from './use-guest';
import { useSignedInNow } from './use-signed-in';

export function SessionSwitch({
  signedIn,
  guest,
  unknown = guest,
}: {
  readonly signedIn: ReactNode;
  readonly guest: ReactNode;
  readonly unknown?: ReactNode;
}) {
  useSignedInNow();

  const viewer = useViewer();

  if (viewer === 'member') return signedIn;

  return viewer === 'unknown' ? unknown : guest;
}
