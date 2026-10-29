import { Suspense } from 'react';
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
  return (
    <Field
      as="div"
      label="Who can see it?"
      hint={
        access === 'roles' ? 'Only these roles and room managers see it.' : 'Every member sees it.'
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
        <Suspense fallback={<RoleChipsLoading />}>
          <RoleChips cid={cid} roleIds={roleIds} onChange={(ids) => onChange(access, ids)} />
        </Suspense>
      ) : null}
    </Field>
  );
}

/** The roles load here, under their own fallback, so opening a dialog never suspends the screen behind it */
function RoleChips({
  cid,
  roleIds,
  onChange,
}: {
  readonly cid: string;
  readonly roleIds: readonly string[];
  readonly onChange: (roleIds: string[]) => void;
}) {
  const gateway = useGateway();

  useLoad(() => gateway.load.roles(cid), 'roles:' + cid);

  const roles = useAppState((state) => rolesOf(state, cid).filter((r) => !r.locked));
  const chosen = new Set(roleIds);

  const toggle = (ref: string) =>
    onChange(chosen.has(ref) ? roleIds.filter((id) => id !== ref) : [...roleIds, ref]);

  return (
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
  );
}

function RoleChipsLoading() {
  return (
    <div className="chips" aria-busy="true" aria-label="Loading roles">
      <span className="skel skel--pill" />
      <span className="skel skel--pill" />
      <span className="skel skel--pill" />
    </div>
  );
}
