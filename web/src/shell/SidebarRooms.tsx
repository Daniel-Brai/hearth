import { useLocation } from 'react-router';

import { Badge, Icon, IconButton, Menu, MenuItem, NavLink } from '@/design-system';
import { roomSections, type LaidOutRoom } from '@/domain/room-layout';
import type { Room, RoomGroup, VoiceRoom } from '@/domain/types';
import { PrivateLock } from '@/features/rooms/PrivateLock';
import { useRoomGroupActions } from '@/features/rooms/use-room-group-actions';
import { toggleFolded, useFolded } from '@/runtime/folded-groups';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';

import { FoldHeader } from './FoldHeader';

export function SidebarRooms({
  cid,
  rooms,
  voice,
  groups,
  canRooms,
}: {
  readonly cid: string;
  readonly rooms: readonly Room[];
  readonly voice: readonly VoiceRoom[];
  readonly groups: readonly RoomGroup[];
  readonly canRooms: boolean;
}) {
  const sections = roomSections(
    { rooms: [...rooms], voice: [...voice], groups: [...groups] },
    true,
  );

  return (
    <>
      {sections.map((section) =>
        section.group ? (
          <GroupedRooms
            key={section.group.id}
            cid={cid}
            group={section.group}
            rooms={section.rooms}
            canRooms={canRooms}
          />
        ) : (
          <RoomLinks key="loose" cid={cid} rooms={section.rooms} />
        ),
      )}
    </>
  );
}

function GroupedRooms({
  cid,
  group,
  rooms,
  canRooms,
}: {
  readonly cid: string;
  readonly group: RoomGroup;
  readonly rooms: readonly LaidOutRoom[];
  readonly canRooms: boolean;
}) {
  const { pathname } = useLocation();
  const folded = useFolded(group.id);

  if (!rooms.length && !canRooms) return null;

  const shown = folded ? rooms.filter((r) => stillShown(cid, r, pathname)) : rooms;

  return (
    <div className="side-group" id={`room-group-${group.id}`}>
      <FoldHeader label={group.name} folded={folded} onToggle={() => toggleFolded(group.id)}>
        {canRooms ? <GroupMenu cid={cid} group={group} /> : null}
      </FoldHeader>

      <RoomLinks cid={cid} rooms={shown} />
    </div>
  );
}

function stillShown(cid: string, r: LaidOutRoom, pathname: string) {
  if (r.kind === 'voice') return r.room.live || pathname === routes.voice(cid, r.room.id);

  return r.room.unread > 0 || pathname === routes.chat(cid, r.room.id);
}

function GroupMenu({ cid, group }: { readonly cid: string; readonly group: RoomGroup }) {
  const openDialog = useUi((s) => s.openDialog);
  const actions = useRoomGroupActions(cid);

  return (
    <Menu
      trigger={({ toggle, open }) => (
        <IconButton
          size="tiny"
          variant="borderless"
          className="side-group__menu"
          onClick={toggle}
          aria-expanded={open}
          aria-label={`${group.name} options`}
        >
          <Icon name="dots" />
        </IconButton>
      )}
    >
      <MenuItem
        icon="plus"
        onSelect={() => openDialog('newRoom', { community: cid, group: group.id })}
      >
        Add a room here
      </MenuItem>
      <MenuItem icon="pencil" onSelect={() => actions.rename(group)}>
        Rename
      </MenuItem>
      <MenuItem icon="trash" danger onSelect={() => actions.remove(group)}>
        Delete group
      </MenuItem>
    </Menu>
  );
}

function RoomLinks({
  cid,
  rooms,
}: {
  readonly cid: string;
  readonly rooms: readonly LaidOutRoom[];
}) {
  return (
    <>
      {rooms.map((r) =>
        r.kind === 'text' ? (
          <NavLink
            key={r.room.id}
            to={routes.chat(cid, r.room.id)}
            className={r.room.unread ? 'side-link unread' : 'side-link'}
          >
            <span className="side-link__icon">
              <Icon name="hash" />
            </span>
            <span className="side-link__name">{r.room.name}</span>
            <PrivateLock room={r.room} />
            {r.room.unread ? <Badge count={r.room.unread} /> : null}
          </NavLink>
        ) : (
          <NavLink key={r.room.id} to={routes.voice(cid, r.room.id)} className="side-link">
            <span className="side-link__icon">
              <Icon name="volume" />
            </span>
            <span className="side-link__name">{r.room.name}</span>
            <PrivateLock room={r.room} />
            {r.room.live ? <Badge red count={r.room.listeners} /> : null}
          </NavLink>
        ),
      )}
    </>
  );
}
