import { useAppState } from '@/data/store';
import { Field, Select } from '@/design-system';
import type { RoomGroup } from '@/domain/types';

const NONE = 'none';
const NO_GROUPS: RoomGroup[] = [];

export function RoomGroupField({
  id,
  cid,
  value,
  onChange,
}: {
  readonly id: string;
  readonly cid: string;
  readonly value: string | null;
  readonly onChange: (group: string | null) => void;
}) {
  const groups = useAppState((state) => state.communities[cid]?.groups ?? NO_GROUPS);

  if (!groups.length) return null;

  const options = [
    { value: NONE, label: 'No group' },
    ...groups.map((g) => ({ value: g.id, label: g.name })),
  ];

  return (
    <Field as="div" label="Group" hint="Rooms in a group show together under its name.">
      <Select
        id={id}
        block
        value={value ?? NONE}
        options={options}
        onChange={(next) => onChange(next === NONE ? null : next)}
        label="Group"
      />
    </Field>
  );
}
