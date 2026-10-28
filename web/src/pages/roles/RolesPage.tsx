import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import {
  Button,
  ButtonLink,
  Icon,
  IconButton,
  Input,
  Label,
  Measure,
  Select,
  Switch,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import {
  canDo,
  community,
  joinedCids,
  peopleOptions,
  rolesOf,
  shortName,
} from '@/domain/selectors';
import type { Permission } from '@/domain/types';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { PERMS } from '@/domain/catalog';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PageHeader } from '@/shell/PageHeader';
import { PersonAvatar, PersonName } from '@/shell/people';
import './RolesPage.css';

const MEMBER_ROLE = 'member';

const NO_PERSON = 'none';

export function RolesPage() {
  const { community: cid } = useParams();

  if (!cid) return <ErrorPage code={404} />;

  return <RolesScreen cid={cid} />;
}

function RolesScreen({ cid }: { readonly cid: string }) {
  const gateway = useGateway();
  const load = useLoad(() => gateway.load.roles(cid), 'roles:' + cid);
  const name = useAppState((state) => community(state, cid)?.name ?? null);
  const allowed = useAppState((state) => canDo(state, cid, 'role.update'));

  if (load.status === 'error') return <ErrorPage code={500} />;
  if (!name) return <ErrorPage code={404} />;
  if (!allowed) return <ErrorPage code={403} forbidden="roles" />;

  return <RolesView key={cid} cid={cid} name={name} />;
}

function RolesView({ cid, name }: { readonly cid: string; readonly name: string }) {
  const navigate = useNavigate();
  const gateway = useGateway();
  const ask = useUi((s) => s.ask);
  const flash = useUi((s) => s.flash);

  const [picked, setPicked] = useState<string | null>(null);
  const [newRole, setNewRole] = useState('');
  const [addMember, setAddMember] = useState<string | null>(null);

  const cids = useAppState((state) =>
    joinedCids(state).filter((k) => canDo(state, k, 'role.update')),
  );

  const cidNames = useAppState((state) => cids.map((k) => community(state, k)?.name ?? k));

  const list = useAppState((state) =>
    rolesOf(state, cid).map((r) => ({
      id: r.id,
      name: r.name,
      hue: r.hue,
      count: r.members.length,
    })),
  );

  const roleId = list.find((r) => r.id === picked)?.id ?? list[0]?.id ?? null;

  const role = useAppState((state) => {
    const r = rolesOf(state, cid).find((x) => x.id === roleId);
    if (!r) return null;
    return {
      id: r.id,
      name: r.name,
      locked: !!r.locked,
      members: [...r.members],
      permissions: [...r.permissions],
    };
  });

  const peopleToAdd = useAppState((state) => peopleOptions(state, role?.members ?? []));

  const communities = cids.map((value, i) => ({ value, label: cidNames[i] ?? value }));
  const addOptions = [{ value: NO_PERSON, label: 'Add someone…' }, ...peopleToAdd];

  const create = async () => {
    const label = newRole.trim();

    if (!label) return;

    const r = await gateway.roles.create(cid, label);

    if (!r.ok) return flash(r.error);

    setPicked(r.value.id);
    setNewRole('');
    flash('Role created');
  };

  const remove = () => {
    if (!role) return;

    ask({
      title: `Delete the ${role.name} role?`,
      body: 'Members keep their other roles. Anyone with only this role becomes a Member.',
      action: 'Delete role',
      onConfirm: () =>
        void gateway.roles.remove(cid, role.id).then((r) => {
          if (!r.ok) return flash(r.error);

          setPicked(MEMBER_ROLE);
          flash('Role deleted');
        }),
    });
  };

  const add = async () => {
    if (!role || !addMember) return;

    const r = await gateway.roles.addMember(cid, role.id, addMember);

    if (!r.ok) return flash(r.error);

    flash(`${shortNameOf(addMember)} is now a ${role.name}`);
    setAddMember(null);
  };

  const setPerm = async (perm: Permission, on: boolean) => {
    if (!role) return;

    const r = await gateway.roles.setPermission(cid, role.id, perm, on);
    flash(r.ok ? 'Saved' : r.error);
  };

  const removeMember = async (id: string) => {
    if (!role) return;

    const r = await gateway.roles.removeMember(cid, role.id, id);
    if (!r.ok) flash(r.error);
  };

  const shortNameOf = (id: string) =>
    peopleToAdd.find((p) => p.value === id)?.label.split(' ')[0] ?? 'They';

  return (
    <>
      <PageHeader
        label="Roles"
        eyebrow={name}
        title="Roles"
        actions={
          <ButtonLink
            to={routes.moderation(cid)}
            circle
            size="small"
            aria-label="Moderation"
            data-tip="Moderation"
          >
            <Icon name="shield" />
          </ButtonLink>
        }
      />

      <main id="main">
        <Measure className="roles-layout" style={{ maxInlineSize: '64rem' }}>
          <aside className="grid gap-1 content-start">
            {communities.length > 1 ? (
              <div style={{ marginBlockEnd: '0.4rem' }}>
                <Select
                  value={cid}
                  options={communities}
                  onChange={(next) => void navigate(routes.roles(next))}
                  label="Community"
                  block
                />
              </div>
            ) : null}

            <Label className="px-3">Roles</Label>

            {list.map((r) => (
              <button
                key={r.id}
                type="button"
                id={`role-${r.id}`}
                className={r.id === roleId ? 'role-link is-on' : 'role-link'}
                onClick={() => setPicked(r.id)}
              >
                <span className="dot" style={{ background: `var(--hue-${r.hue})` }} />
                <span className="truncate" style={{ flex: 1 }}>
                  {r.name}
                </span>
                <span className="x-small subtle tabular">{r.count}</span>
              </button>
            ))}

            <form
              id="new-role-form"
              className="flex items-center gap-1"
              style={{ marginBlockStart: '0.6rem' }}
              onSubmit={(e) => {
                e.preventDefault();
                void create();
              }}
            >
              <Input
                value={newRole}
                onChange={(e) => setNewRole(e.target.value)}
                placeholder="New role"
                aria-label="New role name"
                maxLength={24}
              />
              <IconButton type="submit" variant="reversed" aria-label="Create role">
                <Icon name="plus" />
              </IconButton>
            </form>
          </aside>

          {role ? (
            <section className="panel grid gap-4" id="role-panel">
              <div className="flex items-center justify-between gap-2 flex-wrap">
                <h2 className="page-title" style={{ fontSize: 'var(--text-x-large)' }}>
                  {role.name}
                </h2>

                {!role.locked && role.id !== MEMBER_ROLE ? (
                  <Button
                    size="small"
                    variant="borderless"
                    className="btn--danger-text"
                    onClick={remove}
                  >
                    <Icon name="trash" />
                    Delete role
                  </Button>
                ) : null}
              </div>

              <div className="grid gap-2">
                <Label>People</Label>

                <div className="flex flex-wrap gap-2">
                  {role.members.map((id) => (
                    <span key={id} className="chip chip--static">
                      <PersonAvatar id={id} size="xs" />
                      <PersonName id={id} />
                      {!role.locked ? (
                        <MemberRemove id={id} onRemove={() => void removeMember(id)} />
                      ) : null}
                    </span>
                  ))}

                  {!role.members.length ? (
                    <span className="small subtle">Nobody has this role yet.</span>
                  ) : null}
                </div>

                {!role.locked ? (
                  <form
                    id="add-member-form"
                    className="flex items-center gap-2"
                    onSubmit={(e) => {
                      e.preventDefault();
                      void add();
                    }}
                  >
                    <Select
                      value={addMember ?? NO_PERSON}
                      options={addOptions}
                      onChange={(next) => setAddMember(next === NO_PERSON ? null : next)}
                      label="Person to add"
                    />
                    <Button type="submit" size="small" disabled={!addMember}>
                      <Icon name="plus" />
                      Add
                    </Button>
                  </form>
                ) : null}
              </div>

              <div className="grid">
                <Label className="mb-1">What they can do</Label>

                {role.locked ? (
                  <p className="small subtle" style={{ paddingBlock: '0.4rem' }}>
                    Owners can do everything. Transfer ownership from community settings.
                  </p>
                ) : null}

                {PERMS.map(([key, label, desc]) => (
                  <div key={key} className="settings-row">
                    <div>
                      <strong className="small">{label}</strong>
                      <div className="x-small subtle">{desc}</div>
                    </div>
                    <Switch
                      label={label}
                      checked={role.locked || role.permissions.includes(key)}
                      disabled={role.locked}
                      onChange={(on) => void setPerm(key, on)}
                    />
                  </div>
                ))}
              </div>
            </section>
          ) : null}
        </Measure>
      </main>
    </>
  );
}

function MemberRemove({ id, onRemove }: { readonly id: string; readonly onRemove: () => void }) {
  const label = useAppState((state) => shortName(state, id));

  return (
    <Button
      circle
      size="tiny"
      variant="borderless"
      onClick={onRemove}
      aria-label={`Remove ${label}`}
    >
      <Icon name="x" />
    </Button>
  );
}
