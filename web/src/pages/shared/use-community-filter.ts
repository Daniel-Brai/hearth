import { useAppState } from '@/data/store';
import type { SelectOption } from '@/design-system';
import { joinedCids } from '@/domain/selectors';

export function useCommunityFilter(): SelectOption<string>[] {
  const cids = useAppState(joinedCids);
  const names = useAppState((state) => cids.map((c) => state.communities[c]?.name ?? c));

  return [
    { value: 'all', label: 'All communities' },
    ...cids.map((c, i) => ({ value: c, label: names[i] ?? c })),
  ];
}
