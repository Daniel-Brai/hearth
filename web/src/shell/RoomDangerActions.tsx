import { Button, Icon } from '@/design-system';
import type { useRoomActions } from './use-room-actions';

export function RoomDangerActions({
  actions,
}: {
  readonly actions: ReturnType<typeof useRoomActions>;
}) {
  return (
    <span className="me-auto flex flex-wrap gap-1">
      {actions.can.archive ? (
        <Button id="room-archive" variant="danger-text" onClick={actions.archive}>
          <Icon name="archive" />
          Archive room
        </Button>
      ) : null}

      {actions.can.destroy ? (
        <Button id="room-delete" variant="danger-text" onClick={actions.destroy}>
          <Icon name="trash" />
          Delete permanently
        </Button>
      ) : null}
    </span>
  );
}
