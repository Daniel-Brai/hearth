import { useNavigate } from 'react-router';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { canDo } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';

export function useRoomActions(
  cid: string,
  id: string,
  label: string,
  onDone: () => void,
  inList = false,
) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);
  const ask = useUi((s) => s.ask);

  const can = useAppState((state) => ({
    archive: canDo(state, cid, 'room.update'),
    destroy: canDo(state, cid, 'room.delete'),
  }));

  const leave = (message: string) => {
    onDone();
    flash(message);
    if (!inList) void navigate(routes.community(cid));
  };

  const restore = () =>
    void gateway.rooms.restore(cid, id).then((r) => {
      if (r.ok) leave(`${label} is back`);
      else flash(r.error);
    });

  const archive = () =>
    ask({
      title: `Archive ${label}?`,
      body: 'It leaves the sidebar for everyone. Its messages are kept, and you can restore it any time.',
      action: 'Archive room',
      danger: false,
      onConfirm: () =>
        void gateway.rooms.archive(cid, id).then((r) => {
          if (r.ok) leave(`${label} was archived`);
          else flash(r.error);
        }),
    });

  const destroy = () =>
    ask({
      title: `Delete ${label} permanently?`,
      body: 'Its messages and events are deleted for everyone. Posts that mention it keep their text.',
      action: 'Continue',
      onConfirm: () =>
        ask({
          title: "This can't be undone",
          body: `${label} and everything in it will be gone for good. Archive it instead to keep its history.`,
          action: 'Delete permanently',
          onConfirm: () =>
            void gateway.rooms.destroy(cid, id).then((r) => {
              if (r.ok) leave(`${label} was deleted`);
              else flash(r.error);
            }),
        }),
    });

  return { can, archive, restore, destroy };
}
