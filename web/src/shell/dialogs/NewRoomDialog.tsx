import { useState } from 'react';
import { useNavigate } from 'react-router';
import {
  Button,
  ChoiceTiles,
  Dialog,
  DialogClose,
  DialogFooter,
  DialogTitle,
  Field,
  Input,
  InputWithPrefix,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { voiceOn } from '@/domain/selectors';
import { routes, slugify } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';

type RoomType = 'text' | 'voice';

export function NewRoomDialog() {
  const gateway = useGateway();
  const navigate = useNavigate();
  const closeDialog = useUi((s) => s.closeDialog);
  const flash = useUi((s) => s.flash);
  const cid = useUi((s) => s.dialogData.community);

  const communityName = useAppState((state) =>
    typeof cid === 'string' ? (state.communities[cid]?.name ?? null) : null,
  );

  const voice = useAppState(voiceOn);
  const [type, setType] = useState<RoomType>('text');
  const [name, setName] = useState('');
  const [topic, setTopic] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const close = () => closeDialog('newRoom');

  if (typeof cid !== 'string' || !communityName) return null;

  const submit = async () => {
    setBusy(true);

    const r = await gateway.rooms.create(cid, { type, name, topic }).finally(() => setBusy(false));

    if (!r.ok) {
      setError(r.error);
      return;
    }

    close();
    flash(type === 'text' ? `#${r.value.id} is ready` : `${name.trim()} is ready`);
    void navigate(type === 'text' ? routes.chat(cid, r.value.id) : routes.voice(cid, r.value.id));
  };

  const slug = slugify(name);

  return (
    <Dialog open onClose={close} width="30rem" labelledBy="nr-title">
      <DialogClose onClick={close} />

      <form
        className="dialog__body"
        style={{ textAlign: 'start' }}
        noValidate
        onSubmit={(e) => {
          e.preventDefault();
          void submit();
        }}
      >
        <DialogTitle id="nr-title">Add a room to {communityName}</DialogTitle>

        {voice ? (
          <ChoiceTiles
            name="nr-type"
            value={type}
            onChange={setType}
            label="Kind of room"
            tiles={[
              {
                value: 'text',
                icon: 'hash',
                label: 'Text room',
                sub: 'Messages, files and threads',
              },
              {
                value: 'voice',
                icon: 'volume',
                label: 'Voice room',
                sub: 'Talk live, share a screen, record',
              },
            ]}
          />
        ) : null}

        <Field
          label="Name"
          hint={type === 'text' && slug ? `People will see #${slug}` : undefined}
          error={error}
        >
          {type === 'text' ? (
            <InputWithPrefix
              prefix="#"
              id="new-room-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={30}
              spellCheck={false}
              placeholder="release-planning"
              autoFocus
            />
          ) : (
            <Input
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={30}
              placeholder="Pairing room"
              autoFocus
            />
          )}
        </Field>

        <Field
          label={
            <>
              Topic <span className="subtle">(optional)</span>
            </>
          }
        >
          <Input
            value={topic}
            onChange={(e) => setTopic(e.target.value)}
            maxLength={100}
            placeholder={type === 'text' ? 'What this room is for' : 'What people talk about here'}
          />
        </Field>

        <DialogFooter>
          <Button onClick={close}>Cancel</Button>
          <Button type="submit" variant="reversed" busy={busy}>
            Add room
          </Button>
        </DialogFooter>
      </form>
    </Dialog>
  );
}

export type { RoomType };
