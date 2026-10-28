import { Select, type Option } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { creationMode } from '@/domain/selectors';
import type { CommunityCreation } from '@/domain/types';
import { useUi } from '@/runtime/ui-store';

const OPTIONS: readonly Option<CommunityCreation>[] = [
  { value: 'admins', label: 'Admins only' },
  { value: 'request', label: 'By request' },
  { value: 'anyone', label: 'Anyone' },
];

export function CreationSelect({ id }: { readonly id?: string | undefined }) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const mode = useAppState((state) => creationMode(state));

  const change = async (next: CommunityCreation) => {
    const r = await gateway.settings.setInstanceCreation(next);

    if (!r.ok) flash(r.error);
  };

  return (
    <Select
      id={id}
      label="Who can start communities"
      value={mode}
      options={OPTIONS}
      onChange={change}
    />
  );
}
