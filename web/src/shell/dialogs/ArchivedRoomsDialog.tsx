import {
  Button,
  Dialog,
  DialogBody,
  DialogClose,
  DialogTitle,
  EmptyState,
  Icon,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import type { ArchivedRoom } from '@/domain/types';
import { useUi } from '@/runtime/ui-store';
import { useRoomActions } from '@/shell/use-room-actions';

const archivedOn = (iso: string) =>
  iso ? new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) : null;

export function ArchivedRoomsDialog() {
  const closeDialog = useUi((s) => s.closeDialog);
  const cid = useUi((s) => s.dialogData.community);
  const close = () => closeDialog('archivedRooms');

  if (typeof cid !== 'string') return null;

  return (
    <Dialog open onClose={close} width="30rem" labelledBy="archived-title">
      <DialogClose onClick={close} />
      <DialogBody>
        <DialogTitle id="archived-title">Archived rooms</DialogTitle>
        <ArchivedList cid={cid} />
      </DialogBody>
    </Dialog>
  );
}

function ArchivedList({ cid }: { readonly cid: string }) {
  const gateway = useGateway();
  const load = useLoad(() => gateway.load.archivedRooms(cid), `archived-rooms:${cid}`);
  const rooms = useAppState((state) => state.archivedRooms[cid] ?? []);

  if (load.status === 'error') return <p className="subtle">{load.error}</p>;

  if (!rooms.length)
    return (
      <EmptyState
        small
        art="chat"
        title="No archived rooms"
        text="Rooms you archive wait here, with their messages, until you restore them."
      />
    );

  return (
    <ul id="archived-rooms" className="grid gap-2 p-0 m-0 list-none">
      {rooms.map((room) => (
        <ArchivedRow key={room.id} cid={cid} room={room} />
      ))}
    </ul>
  );
}

function ArchivedRow({ cid, room }: { readonly cid: string; readonly room: ArchivedRoom }) {
  const label = room.type === 'text' ? `#${room.name}` : room.name;
  const actions = useRoomActions(cid, room.id, label, () => undefined, true);
  const when = archivedOn(room.archivedAt);

  return (
    <li id={`archived-${room.id}`} className="flex items-center gap-2">
      <Icon name={room.type === 'text' ? 'hash' : 'volume'} />
      <span className="grid flex-1 min-w-0">
        <strong className="truncate">{room.name}</strong>
        {when ? <span className="x-small subtle">Archived {when}</span> : null}
      </span>

      {actions.can.destroy ? (
        <Button size="small" variant="danger-text" onClick={actions.destroy}>
          Delete
        </Button>
      ) : null}

      <Button size="small" onClick={actions.restore}>
        Restore
      </Button>
    </li>
  );
}
