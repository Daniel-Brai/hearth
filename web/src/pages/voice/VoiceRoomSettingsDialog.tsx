import { useState } from 'react';
import { useNavigate } from 'react-router';
import {
  Button,
  Dialog,
  DialogClose,
  DialogFooter,
  DialogTitle,
  Field,
  Input,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { RoomDangerActions } from '@/shell/RoomDangerActions';
import { useRoomActions } from '@/shell/use-room-actions';
import { RoomAccessSetting } from '@/features/rooms/RoomAccessSetting';

type VoiceRoomSettingsDialogProps = {
  readonly cid: string;
  readonly rid: string;
  readonly name: string;
  readonly onClose: () => void;
};

export function VoiceRoomSettingsDialog({ cid, rid, name, onClose }: VoiceRoomSettingsDialogProps) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);
  const actions = useRoomActions(cid, rid, name, onClose);

  const [next, setNext] = useState(name);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const save = async () => {
    if (!next.trim() || next.trim() === name) {
      onClose();
      return;
    }

    setBusy(true);

    const r = await gateway.rooms.rename(cid, rid, next).finally(() => setBusy(false));

    if (!r.ok) {
      setError(r.error);
      return;
    }

    onClose();
    flash(`Renamed to ${next.trim()}`);
    if (r.value.id !== rid) void navigate(routes.voice(cid, r.value.id), { replace: true });
  };

  return (
    <Dialog open onClose={onClose} width="30rem" labelledBy="voice-room-title">
      <DialogClose onClick={onClose} />

      <form
        id="voice-room-settings"
        className="dialog__body"
        style={{ textAlign: 'start' }}
        noValidate
        onSubmit={(e) => {
          e.preventDefault();
          void save();
        }}
      >
        <DialogTitle id="voice-room-title">Voice room settings</DialogTitle>

        <Field label="Name" error={error}>
          <Input
            id="voice-room-name"
            value={next}
            onChange={(e) => setNext(e.target.value)}
            maxLength={30}
          />
        </Field>

        <RoomAccessSetting cid={cid} rid={rid} />

        <DialogFooter>
          <RoomDangerActions actions={actions} />

          <Button type="submit" variant="reversed" busy={busy}>
            Done
          </Button>
        </DialogFooter>
      </form>
    </Dialog>
  );
}
