import { MenuItem } from '@/design-system';
import type { CommunityEvent } from '@/domain/types';
import type { useEventActions } from './use-event-actions';

export function EventManageItems({
  event,
  active,
  actions,
  onEdit,
}: {
  readonly event: CommunityEvent;
  readonly active: boolean;
  readonly actions: ReturnType<typeof useEventActions>;
  readonly onEdit: (e: CommunityEvent) => void;
}) {
  return (
    <>
      {!event.cancelled ? (
        <MenuItem icon="pencil" onSelect={() => onEdit(event)}>
          Edit or reschedule
        </MenuItem>
      ) : (
        <MenuItem icon="refresh" onSelect={() => actions.restore(event)}>
          Put it back on
        </MenuItem>
      )}
      {active ? (
        <MenuItem icon="x" danger onSelect={() => actions.cancel(event)}>
          Cancel event
        </MenuItem>
      ) : null}
      <MenuItem icon="trash" danger onSelect={() => actions.remove(event)}>
        Delete event
      </MenuItem>
    </>
  );
}
