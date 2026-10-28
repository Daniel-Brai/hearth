import type { Result } from '@/data/gateway';
import { useUi } from './ui-store';

/** For a change already on the screen, says why if the server turned it down */
export function useFlashFailure() {
  const flash = useUi((s) => s.flash);

  return (pending: Promise<Result<unknown>>) => {
    void pending.then((r) => {
      if (!r.ok) flash(r.error);
    });
  };
}
