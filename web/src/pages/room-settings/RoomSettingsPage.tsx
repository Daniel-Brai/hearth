import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import {
  Button,
  ButtonLink,
  Chip,
  Field,
  Icon,
  Input,
  InputWithPrefix,
  Measure,
  Panel,
  Segmented,
  SettingsRow,
  Switch,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import {
  canDo,
  community,
  modLevel,
  roleRef,
  rolesOf,
  roomSettings,
  soundAccess,
} from '@/domain/selectors';
import type { ModerationLevel, RoomSettings, RoomSoundMode } from '@/domain/types';
import { routes, slugify } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PageHeader } from '@/shell/PageHeader';
import { PersonAvatar, PersonName } from '@/shell/people';
import { RoomDangerActions } from '@/shell/RoomDangerActions';
import { useRoomActions } from '@/shell/use-room-actions';
import { RoomAccessSetting } from '@/features/rooms/RoomAccessSetting';
import { communityPeople, LEVELS } from '@/pages/chat/chat-select';
import { LeaveDialog } from '@/pages/compose/LeaveDialog';
import { useLeaveGuard } from '@/pages/compose/use-leave-guard';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import './RoomSettingsPage.css';

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
      return 'Checks messages and takes reports.';
    case 'reports':
      return 'Only reports reach the queue.';
    case 'none':
      return 'No checks and no reports.';
  }
}

export function RoomSettingsPage() {
  const { community: cid, room } = useParams();
  const gateway = useGateway();

  const load = useLoad(
    () =>
      cid && room
        ? gateway.load.chat(`${cid}/${room}`)
        : Promise.resolve({ ok: true, value: undefined }),
    `chat:${cid ?? 'none'}/${room ?? 'none'}`,
  );

  const exists = useAppState(
    (state) => !!cid && !!community(state, cid)?.rooms.some((r) => r.id === room),
  );
  const allowed = useAppState((state) => !!cid && canDo(state, cid, 'room.update'));

  if (load.status === 'error') return <ErrorPage code={500} />;
  if (!cid || !room || !exists) return <ErrorPage code={404} />;
  if (!allowed) return <ErrorPage code={403} forbidden="rooms" />;

  // Keyed by room so opening another starts a fresh form
  return <RoomSettingsForm key={`${cid}/${room}`} cid={cid} room={room} />;
}

function RoomSettingsForm({ cid, room }: { readonly cid: string; readonly room: string }) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const flash = useUi((s) => s.flash);

  const key = `${cid}/${room}`;

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
      accessText: access.ok ? null : access.reason + '.',
      roomCount: community(state, cid)?.rooms.length ?? 0,
    };
  });

  const roles = useAppState((state) => rolesOf(state, cid).filter((r) => !r.locked));
  const people = useAppState((state) => communityPeople(state, cid));

  const soundRoles = new Set(view.sounds.roles);
  const soundPeople = new Set(view.sounds.people);

  const [nameDraft, setName] = useState<string | null>(null);
  const [topicDraft, setTopic] = useState<string | null>(null);

  const name = nameDraft ?? room;
  const topic = topicDraft ?? view.topic ?? '';

  const dirty = name !== room || topic.trim() !== (view.topic ?? '');
  const guard = useLeaveGuard(dirty);
  const actions = useRoomActions(cid, room, `#${room}`, guard.allowLeave);

  const patch = (next: Partial<RoomSettings>) => gateway.rooms.updateSettings(key, next);

  const patchSounds = (next: Partial<RoomSettings['sounds']>) =>
    patch({ sounds: { ...view.sounds, ...next } });

  const saveTopic = () => {
    patch({ topic: topic.trim() || null });
  };

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

      guard.allowLeave();
      flash(`Renamed to #${r.value.id}`);
      void navigate(routes.chat(cid, r.value.id));

      return;
    }

    guard.allowLeave();
    flash('Room settings saved');
    void navigate(routes.chat(cid, room));
  };

  const ceiling = LEVELS.indexOf(view.communityLevel);

  return (
    <>
      <PageHeader label="room settings" eyebrow={view.communityName} title={`#${room} settings`} />

      <main id="main">
        <form
          id="room-settings-form"
          noValidate
          onSubmit={(e) => {
            e.preventDefault();
            void done();
          }}
        >
          <Measure narrow className="grid gap-4 room-settings">
            <Panel className="grid gap-5" id="room-settings-identity">
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
            </Panel>

            <Panel className="grid gap-5" id="room-settings-access">
              <RoomAccessSetting cid={cid} rid={room} />

              <SettingsRow
                className="border-0 p-0"
                title="Link previews"
                sub="Show a card for links people share."
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
                    {view.communityLevel !== 'full' ? ' The community caps it.' : null}
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
            </Panel>

            <Panel className="grid gap-4" id="room-settings-sounds">
              <SettingsRow
                className="border-0 p-0"
                title="Sounds"
                sub={
                  <>
                    Let people use <code>/play</code> in the room.
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
                <div className="grid gap-4">
                  <Segmented
                    name="sound-mode"
                    label="Who can play sounds"
                    className="justify-self-start"
                    value={view.sounds.mode}
                    options={MODE_OPTIONS}
                    onChange={(mode) => patchSounds({ mode })}
                  />

                  {view.sounds.mode === 'roles' ? (
                    <div className="chips">
                      {roles.map((r) => {
                        const on = soundRoles.has(roleRef(r));

                        return (
                          <Chip
                            key={r.id}
                            on={on}
                            onClick={() =>
                              patchSounds({ roles: toggled(view.sounds.roles, roleRef(r)) })
                            }
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

                  {view.accessText ? <p className="x-small subtle">{view.accessText}</p> : null}
                </div>
              ) : null}
            </Panel>

            <div className="room-settings__bar">
              {view.roomCount > 1 ? <RoomDangerActions actions={actions} /> : null}

              <ButtonLink to={routes.chat(cid, room)}>Cancel</ButtonLink>
              <Button type="submit" variant="reversed">
                Done
              </Button>
            </div>
          </Measure>
        </form>
      </main>

      <LeaveDialog
        blocker={guard.blocker}
        title="Leave without saving?"
        text="Your changes to this room haven't been saved."
        stay="Keep editing"
        leave="Discard changes"
      />
    </>
  );
}
