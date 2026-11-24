import type { Result } from '@/data/gateway';

import { useUi } from './ui-store';

export function useFlashFailure() {
  const flash = useUi((s) => s.flash);

  return (pending: Promise<Result<unknown>>) => {
    void pending.then((r) => {
      if (!r.ok) flash(r.error);
    });
  };
}
