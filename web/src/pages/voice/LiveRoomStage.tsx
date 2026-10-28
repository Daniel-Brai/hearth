import { Avatar, cn, Emoji, Label } from '@/design-system';
import { PersonAvatar } from '@/shell/people';
import { StageSpeaker } from './StageSpeaker';
import { audibleSpeakers, stagePeople, stageTalkers, youSpeaking } from './talkers';
import type { LiveRoomView, RoomSession } from './live-room-view';
import type { useVoiceActions } from './use-voice-actions';

type VoiceActions = ReturnType<typeof useVoiceActions>;

export function ShareStrip({
  view,
  session,
  onMore,
}: {
  readonly view: LiveRoomView;
  readonly session: RoomSession;
  readonly onMore: () => void;
}) {
  return (
    <aside id="voice-share-strip" className="share-strip" aria-label="People in the room">
      <div className="share-strip__people">
        {stageTalkers(view, session).map((t) => (
          <span
            key={t.id}
            id={'strip-' + t.id}
            className={cn('speaker speaker--mini', t.speaking && 'is-speaking')}
            data-speaking={t.speaking || undefined}
          >
            <PersonAvatar id={t.id} size="sm" />
          </span>
        ))}
      </div>
      <button type="button" className="share-strip__more small subtle" onClick={onMore}>
        {view.total} in the room
      </button>
    </aside>
  );
}

export function MoreButton({
  open,
  total,
  extra,
  onClick,
}: {
  readonly open: boolean;
  readonly total: number;
  readonly extra: number;
  readonly onClick: () => void;
}) {
  return (
    <button
      type="button"
      className={open ? 'speaker speaker--more' : 'listener speaker--more'}
      onClick={onClick}
      aria-label={`See all ${total} people in the room`}
    >
      <Avatar hue="ink" initials={'+' + extra} size={open ? 'md' : 'lg'} />
      <span className={open ? 'speaker__name' : undefined}>more</span>
    </button>
  );
}

export function LiveRoomStage({
  view,
  session,
  actions,
  extra,
  sharingMine,
  onMore,
}: {
  readonly view: LiveRoomView;
  readonly session: RoomSession;
  readonly actions: VoiceActions;
  readonly extra: number;
  readonly sharingMine: boolean;
  readonly onMore: () => void;
}) {
  const mutedIds = new Set(session.muted);
  const lockedIds = new Set(session.locked);
  const speakingIds = audibleSpeakers(session);

  return (
    <section className="grid gap-3">
      <Label>{view.open ? `In the room · ${view.total}` : 'On stage'}</Label>

      <div id="voice-stage" className="stage">
        {view.onStage && view.me ? (
          <StageSpeaker
            id={view.me}
            you
            host={view.asHost}
            muted={view.muted}
            locked={lockedIds.has(view.me)}
            speaking={youSpeaking(view, session)}
            sharing={sharingMine}
            canManage={false}
            openRoom={view.open}
            onServerMute={() => undefined}
            onDemote={() => undefined}
            onDisconnect={() => undefined}
          />
        ) : null}

        {stagePeople(view, session).map((id) => (
          <StageSpeaker
            key={id}
            id={id}
            host={id === view.host}
            muted={mutedIds.has(id) || lockedIds.has(id)}
            locked={lockedIds.has(id)}
            speaking={speakingIds.has(id)}
            sharing={session.share?.by === id}
            canManage={view.asHost && id !== view.host}
            openRoom={view.open}
            onServerMute={() => actions.toggleServerMute(id)}
            onDemote={() => actions.demote(id)}
            onDisconnect={() => actions.disconnect(id)}
          />
        ))}

        {view.open && extra > 0 ? (
          <MoreButton open total={view.total} extra={extra} onClick={onMore} />
        ) : null}
      </div>
    </section>
  );
}

export function FloatZone({
  floats,
  over,
}: {
  readonly floats: RoomSession['floats'];
  readonly over?: boolean | undefined;
}) {
  return (
    <div className={cn('float-zone', over && 'float-zone--over')} aria-hidden="true">
      {floats.map((f) => (
        <span key={f.id} className="float-emoji" style={{ left: f.x + '%', bottom: 0 }}>
          <Emoji value={f.emoji} />
          {f.by ? <PersonAvatar id={f.by} size="xs" className="float-emoji__by" /> : null}
        </span>
      ))}
    </div>
  );
}
