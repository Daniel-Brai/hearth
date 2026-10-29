import { Chip, Field, Icon, Segmented } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { roleRef, rolesOf } from '@/domain/selectors';
import type { RoomAccess } from '@/domain/types';

type RoomAccessFieldProps = {
  readonly cid: string;
  readonly access: RoomAccess;
  readonly roleIds: readonly string[];
  readonly onChange: (access: RoomAccess, roleIds: string[]) => void;
};

const OPTIONS = [
  { value: 'everyone', label: 'Everyone in the community' },
  { value: 'roles', label: 'Only some roles' },
] satisfies { value: RoomAccess; label: string }[];

export function RoomAccessField({ cid, access, roleIds, onChange }: RoomAccessFieldProps) {
  const gateway = useGateway();

  useLoad(() => gateway.load.roles(cid), 'roles:' + cid);

  const roles = useAppState((state) => rolesOf(state, cid).filter((r) => !r.locked));
  const chosen = new Set(roleIds);

  const toggle = (ref: string) =>
    onChange(access, chosen.has(ref) ? roleIds.filter((id) => id !== ref) : [...roleIds, ref]);

  return (
    <Field
      as="div"
      label="Who can see it?"
      hint={
        access === 'roles'
          ? 'Only people with these roles see the room. The owner and people who manage rooms always do.'
          : 'Every member can see and open the room.'
      }
    >
      <Segmented
        name={`room-access-${cid}`}
        label="Who can see it?"
        className="justify-self-start"
        value={access}
        options={OPTIONS}
        onChange={(next) => onChange(next, next === 'roles' ? [...roleIds] : [])}
      />

      {access === 'roles' ? (
        <div className="chips" role="group" aria-label="Roles that can see the room">
          {roles.map((r) => {
            const on = chosen.has(roleRef(r));

            return (
              <Chip key={r.id} on={on} onClick={() => toggle(roleRef(r))}>
                {on ? <Icon name="check" /> : null}
                <span>{r.name}</span>
              </Chip>
            );
          })}
        </div>
      ) : null}
    </Field>
  );
}
