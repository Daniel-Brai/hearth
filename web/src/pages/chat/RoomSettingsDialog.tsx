import { useState } from 'react';
import { useNavigate } from 'react-router';
import {
  Button,
  Chip,
  Dialog,
  DialogClose,
  DialogFooter,
  DialogTitle,
  Field,
  Icon,
  Input,
  InputWithPrefix,
  Segmented,
  SettingsRow,
  Switch,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import {
  canDo,
  community,
  modLevel,
  modLevelText,
  rolesOf,
  roomSettings,
  soundAccess,
} from '@/domain/selectors';
import type { ModerationLevel, RoomSettings, RoomSoundMode } from '@/domain/types';
import { routes, slugify } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PersonAvatar, PersonName } from '@/shell/people';
import { RoomDangerActions } from '@/shell/RoomDangerActions';
import { useRoomActions } from '@/shell/use-room-actions';
import { communityPeople, LEVELS } from './chat-select';

type RoomSettingsDialogProps = {
  readonly cid: string;
  readonly room: string;
  readonly title: string;
  readonly onClose: () => void;
};

const LEVEL_OPTIONS = [
  { value: 'full', label: 'Full' },
  { value: 'reports', label: 'Reports only' },
  { value: 'none', label: 'None' },
] satisfies { value: ModerationLevel; label: string }[];

const MODE_OPTIONS = [
  { value: 'everyone', label: 'Everyone' },
  { value: 'roles', label: 'Some roles' },
  { value: 'people', label: 'Some people' },
] satisfies { value: RoomSoundMode; label: string }[];

const toggled = (list: readonly string[], id: string) =>
  list.includes(id) ? list.filter((x) => x !== id) : [...list, id];

function levelHint(level: ModerationLevel) {
  switch (level) {
    case 'full':
      return 'Automatic checks hold messages that might break the rules, and people can report messages.';
    case 'reports':
      return 'No automatic checks. Only what people report goes to the moderation queue.';
    case 'none':
      return "No automatic checks and no reporting. People see that this room isn't moderated.";
  }
}

export function RoomSettingsDialog({ cid, room, title, onClose }: RoomSettingsDialogProps) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);

  const key = `${cid}/${room}`;
  const actions = useRoomActions(cid, room, `#${room}`, onClose);

  const view = useAppState((state) => {
    const s = roomSettings(state, key);
    const access = soundAccess(state, key);

    return {
      communityName: community(state, cid)?.name ?? null,
      communityLevel: modLevel(state, cid),
      level: modLevel(state, cid, room),
      topic: s.topic,
      previews: s.previews,
      sounds: s.sounds,
      accessText: access.ok ? 'You can play sounds here.' : access.reason + '.',
      canRooms: canDo(state, cid, 'room.update'),
      roomCount: community(state, cid)?.rooms.length ?? 0,
    };
  });

  const roles = useAppState((state) => rolesOf(state, cid).filter((r) => !r.locked));
  const people = useAppState((state) => communityPeople(state, cid));

  const soundRoles = new Set(view.sounds.roles);
  const soundPeople = new Set(view.sounds.people);

  const [name, setName] = useState(room);
  const [topic, setTopic] = useState(view.topic ?? '');

  const patch = (next: Partial<RoomSettings>) => gateway.rooms.updateSettings(key, next);

  const patchSounds = (next: Partial<RoomSettings['sounds']>) =>
    patch({ sounds: { ...view.sounds, ...next } });

  const saveTopic = () => patch({ topic: topic.trim() || null });

  const changeName = (value: string) => {
    const base = slugify(value.replaceAll('#', ''));
    setName(base && (value.endsWith('-') || value.endsWith(' ')) ? base + '-' : base);
  };

  const done = async () => {
    saveTopic();

    const next = slugify(name);

    if (next && next !== room) {
      const r = await gateway.rooms.rename(cid, room, next);

      if (!r.ok) {
        flash(r.error);
        return;
      }

      onClose();
      flash(`Renamed to #${r.value.id}`);
      void navigate(routes.chat(cid, r.value.id));

      return;
    }

    onClose();
    flash('Room settings saved');
  };

  const ceiling = LEVELS.indexOf(view.communityLevel);

  return (
    <Dialog open onClose={onClose} width="36rem" labelledBy="room-title">
      <DialogClose onClick={onClose} />

      <div className="dialog__body">
        <DialogTitle id="room-title">{title} settings</DialogTitle>

        <fieldset className="grid gap-4 border-0 p-0 m-0" disabled={!view.canRooms}>
          <Field label="Name">
            <InputWithPrefix
              prefix="#"
              id="room-rename"
              value={name}
              onChange={(e) => changeName(e.target.value)}
              maxLength={30}
              spellCheck={false}
            />
          </Field>

          <Field label="Topic">
            <Input
              id="room-topic"
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
              onBlur={saveTopic}
              maxLength={100}
              placeholder="What this room is for"
            />
          </Field>

          <SettingsRow
            className="border-0 p-0"
            title="Link previews"
            sub="Fetch the title, description and image of links people share, from the page's Open Graph tags."
          >
            <Switch
              label="Link previews"
              checked={view.previews}
              onChange={(on) => patch({ previews: on })}
            />
          </SettingsRow>

          <Field
            as="div"
            label="Moderation"
            hint={
              <>
                {levelHint(view.level)}
                {view.communityLevel !== 'full' ? (
                  <>
                    {' '}
                    {view.communityName ?? 'This community'} is set to{' '}
                    {modLevelText(view.communityLevel)}, so this room can&apos;t be stricter. Change
                    it in the community settings.
                  </>
                ) : null}
              </>
            }
          >
            <Segmented
              name="room-moderation"
              label="Moderation"
              className="justify-self-start"
              value={view.level}
              options={LEVEL_OPTIONS.map((o) => ({
                ...o,
                disabled: LEVELS.indexOf(o.value) > ceiling,
              }))}
              onChange={(level) =>
                void gateway.rooms.setModeration(cid, room, level).then((r) => {
                  if (!r.ok) flash(r.error);
                })
              }
            />
          </Field>

          <div className="grid gap-3">
            <SettingsRow
              className="border-0 p-0"
              title="Sounds"
              sub={
                <>
                  Let people use <code>/play</code> to play a sound for everyone in the room.
                </>
              }
            >
              <Switch
                label="Sounds"
                checked={view.sounds.enabled}
                onChange={(on) => patchSounds({ enabled: on })}
              />
            </SettingsRow>

            {view.sounds.enabled ? (
              <div className="grid gap-3">
                <Segmented
                  name="sound-mode"
                  label="Who can play sounds"
                  value={view.sounds.mode}
                  options={MODE_OPTIONS}
                  onChange={(mode) => patchSounds({ mode })}
                />

                {view.sounds.mode === 'roles' ? (
                  <div className="chips">
                    {roles.map((r) => {
                      const on = soundRoles.has(r.id);

                      return (
                        <Chip
                          key={r.id}
                          on={on}
                          onClick={() => patchSounds({ roles: toggled(view.sounds.roles, r.id) })}
                        >
                          {on ? <Icon name="check" /> : null}
                          <span>{r.name}s</span>
                        </Chip>
                      );
                    })}
                  </div>
                ) : null}

                {view.sounds.mode === 'people' ? (
                  <div className="chips">
                    {people.map((id) => (
                      <Chip
                        key={id}
                        on={soundPeople.has(id)}
                        onClick={() => patchSounds({ people: toggled(view.sounds.people, id) })}
                      >
                        <PersonAvatar id={id} size="xs" />
                        <PersonName id={id} />
                      </Chip>
                    ))}
                  </div>
                ) : null}

                <p className="x-small subtle">{view.accessText}</p>
              </div>
            ) : null}
          </div>
        </fieldset>

        <DialogFooter>
          {view.roomCount > 1 ? <RoomDangerActions actions={actions} /> : null}

          <Button variant="reversed" onClick={() => void done()}>
            Done
          </Button>
        </DialogFooter>
      </div>
    </Dialog>
  );
}
