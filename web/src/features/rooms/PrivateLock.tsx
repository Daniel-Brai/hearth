import { Icon } from '@/design-system';
import type { RoomAccess } from '@/domain/types';

export function PrivateLock({
  room,
}: {
  readonly room: { readonly access?: RoomAccess | undefined };
}) {
  if (room.access !== 'roles') return null;

  return <Icon name="lock" className="room-lock" label="Only some roles can see this room" />;
}
