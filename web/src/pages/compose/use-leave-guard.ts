import { useRef } from 'react';
import { useBeforeUnload, useBlocker } from 'react-router';

export function useLeaveGuard(dirty: boolean) {
  const leaving = useRef(false);
  const blocker = useBlocker(() => dirty && !leaving.current);

  useBeforeUnload((e) => {
    if (dirty && !leaving.current) e.preventDefault();
  });

  return {
    blocker,
    allowLeave: () => {
      leaving.current = true;
    },
  };
}
