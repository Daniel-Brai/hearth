import { useState, type DragEvent } from 'react';
import { useParams } from 'react-router';

import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { Button, cn, Icon, IconButton, Measure, Panel } from '@/design-system';
import {
  layoutOf,
  moveRoom,
  roomSections,
  shiftGroup,
  shiftRoom,
  type LaidOutRoom,
  type RoomLayout,
  type RoomSection,
} from '@/domain/room-layout';
import { canDo, community } from '@/domain/selectors';
import type { Community } from '@/domain/types';
import { useRoomGroupActions } from '@/features/rooms/use-room-group-actions';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { useUi } from '@/runtime/ui-store';
import { PageHeader } from '@/shell/PageHeader';

import './ArrangeRoomsPage.css';

export function ArrangeRoomsPage() {
  const { community: cid } = useParams();

  if (!cid) return <ErrorPage code={404} />;

  return <ArrangeRoomsScreen cid={cid} />;
}

function ArrangeRoomsScreen({ cid }: { readonly cid: string }) {
  const gateway = useGateway();
  const load = useLoad(() => gateway.load.community(cid), 'community:' + cid);
  const found = useAppState((state) => community(state, cid) ?? null);
  const allowed = useAppState((state) => canDo(state, cid, 'room.update'));

  if (load.status === 'error') return <ErrorPage code={500} />;
  if (!found) return <ErrorPage code={404} />;
  if (!allowed) return <ErrorPage code={403} forbidden="rooms" />;

  return <ArrangeRooms cid={cid} found={found} />;
}

function ArrangeRooms({ cid, found }: { readonly cid: string; readonly found: Community }) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const actions = useRoomGroupActions(cid);
  const [dragging, setDragging] = useState<string | null>(null);

  // Voice rooms are arranged even while voice is off since the server keeps every room's place
  const sections = roomSections(found, true);
  const layout = layoutOf(sections);

  const save = (next: RoomLayout) => {
    if (next === layout) return;

    void gateway.rooms.arrange(cid, next).then((r) => {
      if (!r.ok) flash(r.error);
    });
  };

  const drop = (group: string | null, before: string | null) => {
    if (dragging && dragging !== before) save(moveRoom(layout, dragging, { group, before }));
    setDragging(null);
  };

  return (
    <>
      <PageHeader label="Arrange rooms" eyebrow={found.name} title="Arrange rooms" />

      <main id="main">
        <Measure narrow className="grid gap-4" id="arrange-rooms">
          <div className="arrange__intro">
            <p className="subtle">Drag or use the arrows to order rooms.</p>
            <Button id="arrange-new-group" onClick={actions.create}>
              <Icon name="plus" />
              New group
            </Button>
          </div>

          {sections.map((section, i) => (
            <SectionPanel
              key={section.group?.id ?? 'loose'}
              section={section}
              first={i <= 1}
              last={i === sections.length - 1}
              dragging={dragging}
              onDrag={setDragging}
              onDrop={drop}
              onShiftRoom={(id, by) => save(shiftRoom(layout, id, by))}
              onShiftGroup={(id, by) => save(shiftGroup(layout, id, by))}
              onRename={actions.rename}
              onDelete={actions.remove}
            />
          ))}
        </Measure>
      </main>
    </>
  );
}

type SectionProps = {
  readonly section: RoomSection;
  readonly first: boolean;
  readonly last: boolean;
  readonly dragging: string | null;
  readonly onDrag: (id: string | null) => void;
  readonly onDrop: (group: string | null, before: string | null) => void;
  readonly onShiftRoom: (id: string, by: -1 | 1) => void;
  readonly onShiftGroup: (id: string, by: -1 | 1) => void;
  readonly onRename: (group: NonNullable<RoomSection['group']>) => void;
  readonly onDelete: (group: NonNullable<RoomSection['group']>) => void;
};

function SectionPanel({ section, first, last, dragging, onDrag, onDrop, ...moves }: SectionProps) {
  const { group } = section;
  const [over, setOver] = useState(false);

  const allow = (e: DragEvent) => {
    if (!dragging) return;
    e.preventDefault();
    if (!over) setOver(true);
  };

  // A drop on a room row never reaches the panel so the highlight also goes when the drag ends
  if (over && !dragging) setOver(false);

  return (
    <Panel
      className={cn('arrange__section', over && dragging && 'is-over')}
      id={group ? `arrange-group-${group.id}` : 'arrange-loose'}
      onDragOver={allow}
      onDragLeave={(e) => {
        if (!e.currentTarget.contains(e.relatedTarget as Node | null)) setOver(false);
      }}
      onDrop={(e) => {
        e.preventDefault();
        setOver(false);
        onDrop(group?.id ?? null, null);
      }}
    >
      <div className="arrange__head">
        <strong className="truncate">{group ? group.name : 'No group'}</strong>

        {group ? (
          <div className="arrange__tools">
            <IconButton
              variant="borderless"
              aria-label={`Rename ${group.name}`}
              data-tip="Rename"
              onClick={() => moves.onRename(group)}
            >
              <Icon name="pencil" />
            </IconButton>
            <IconButton
              variant="borderless"
              aria-label={`Delete ${group.name}`}
              data-tip="Delete group"
              onClick={() => moves.onDelete(group)}
            >
              <Icon name="trash" />
            </IconButton>
            <IconButton
              variant="borderless"
              disabled={first}
              aria-label={`Move ${group.name} up`}
              data-tip="Move up"
              onClick={() => moves.onShiftGroup(group.id, -1)}
            >
              <Icon name="arrowup" />
            </IconButton>
            <IconButton
              variant="borderless"
              disabled={last}
              aria-label={`Move ${group.name} down`}
              data-tip="Move down"
              onClick={() => moves.onShiftGroup(group.id, 1)}
            >
              <Icon name="arrowdown" />
            </IconButton>
          </div>
        ) : null}
      </div>

      <ul className="arrange__rooms">
        {section.rooms.map((r) => (
          <RoomRow
            key={r.room.id}
            room={r}
            dragged={dragging === r.room.id}
            onDrag={onDrag}
            onDrop={() => onDrop(group?.id ?? null, r.room.id)}
            onShift={(by) => moves.onShiftRoom(r.room.id, by)}
          />
        ))}
      </ul>

      {section.rooms.length ? null : (
        <p className="arrange__empty small subtle">
          {group ? 'No rooms yet. Drag one here.' : 'Every room is in a group.'}
        </p>
      )}
    </Panel>
  );
}

function RoomRow({
  room,
  dragged,
  onDrag,
  onDrop,
  onShift,
}: {
  readonly room: LaidOutRoom;
  readonly dragged: boolean;
  readonly onDrag: (id: string | null) => void;
  readonly onDrop: () => void;
  readonly onShift: (by: -1 | 1) => void;
}) {
  const name = room.kind === 'text' ? `#${room.room.id}` : room.room.name;

  return (
    <li
      className={cn('arrange__room', dragged && 'is-dragged')}
      id={`arrange-room-${room.room.id}`}
      draggable
      onDragStart={(e) => {
        e.dataTransfer.effectAllowed = 'move';
        onDrag(room.room.id);
      }}
      onDragEnd={() => onDrag(null)}
      onDrop={(e) => {
        e.preventDefault();
        e.stopPropagation();
        onDrop();
      }}
    >
      <span className="arrange__grip" aria-hidden="true">
        <Icon name="grip" />
      </span>
      <Icon name={room.kind === 'text' ? 'hash' : 'volume'} />
      <span className="truncate">{room.kind === 'text' ? room.room.id : name}</span>

      <span className="arrange__tools">
        <IconButton
          variant="borderless"
          aria-label={`Move ${name} up`}
          data-tip="Move up"
          onClick={() => onShift(-1)}
        >
          <Icon name="arrowup" />
        </IconButton>
        <IconButton
          variant="borderless"
          aria-label={`Move ${name} down`}
          data-tip="Move down"
          onClick={() => onShift(1)}
        >
          <Icon name="arrowdown" />
        </IconButton>
      </span>
    </li>
  );
}
