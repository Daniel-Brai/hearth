import { useGateway } from '@/app/gateway-context';
import type { RoomGroup } from '@/domain/types';
import { useUi } from '@/runtime/ui-store';

const NAME_MAX = 40;

export function useRoomGroupActions(cid: string) {
  const gateway = useGateway();
  const ask = useUi((s) => s.ask);
  const flash = useUi((s) => s.flash);

  const create = () =>
    ask({
      title: 'New room group',
      body: 'Its rooms show together in the sidebar.',
      action: 'Create group',
      note: {
        label: 'Name',
        placeholder: 'Getting started',
        required: true,
        max: NAME_MAX,
        oneLine: true,
      },
      onConfirm: ({ note }) =>
        void gateway.rooms
          .createGroup(cid, note)
          .then((r) => flash(r.ok ? 'Group added' : r.error)),
    });

  const rename = (group: RoomGroup) =>
    ask({
      title: `Rename ${group.name}`,
      body: 'The new name shows for everyone right away.',
      action: 'Rename',
      note: { label: 'Name', initial: group.name, required: true, max: NAME_MAX, oneLine: true },
      onConfirm: ({ note }) =>
        void gateway.rooms
          .renameGroup(cid, group.id, note)
          .then((r) => flash(r.ok ? 'Group renamed' : r.error)),
    });

  const remove = (group: RoomGroup) =>
    ask({
      title: `Delete ${group.name}?`,
      body: 'Its rooms stay and move below the rooms in no group.',
      action: 'Delete group',
      danger: true,
      onConfirm: () =>
        void gateway.rooms
          .deleteGroup(cid, group.id)
          .then((r) => flash(r.ok ? 'Group deleted' : r.error)),
    });

  return { create, rename, remove };
}
