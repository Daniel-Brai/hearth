import { useAppState } from '@/data/store';
import { community } from '@/domain/selectors';

export function useShareable(cid: string | null | undefined): boolean {
  return useAppState((state) => !cid || community(state, cid)?.visibility === 'public');
}
