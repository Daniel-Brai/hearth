import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { community } from '@/domain/selectors';
import type { RoomAccess } from '@/domain/types';
import { useUi } from '@/runtime/ui-store';
import { RoomAccessField } from './RoomAccessField';

const NONE: readonly string[] = [];

// Saves as soon as it changes, like a room's moderation level
export function RoomAccessSetting({ cid, rid }: { readonly cid: string; readonly rid: string }) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);

  const room = useAppState((state) => {
    const c = community(state, cid);
    const found = c?.rooms.find((r) => r.id === rid) ?? c?.voice.find((v) => v.id === rid);

    return { access: found?.access ?? 'everyone', roleIds: found?.roleIds ?? NONE };
  });

  const save = (access: RoomAccess, roleIds: string[]) =>
    void gateway.rooms.setAccess(cid, rid, access, roleIds).then((r) => {
      if (!r.ok) flash(r.error);
    });

  return <RoomAccessField cid={cid} access={room.access} roleIds={room.roleIds} onChange={save} />;
}
