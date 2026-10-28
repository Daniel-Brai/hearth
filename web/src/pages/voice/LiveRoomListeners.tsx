import { Button, Label } from '@/design-system';
import { PersonAvatar, PersonName } from '@/shell/people';
import { MoreButton } from './LiveRoomStage';
import type { LiveRoomView, RoomSession } from './live-room-view';
import type { useVoiceActions } from './use-voice-actions';

type VoiceActions = ReturnType<typeof useVoiceActions>;

export function LiveRoomListeners({
  view,
  session,
  actions,
  extra,
  onMore,
}: {
  readonly view: LiveRoomView;
  readonly session: RoomSession;
  readonly actions: VoiceActions;
  readonly extra: number;
  readonly onMore: () => void;
}) {
  const handIds = new Set(session.hands);

  return (
    <section id="voice-listeners" className="grid gap-3">
      <Label>Listening · {view.total}</Label>

      <div className="listeners">
        {!view.onStage && view.me ? (
          <div className="listener">
            <PersonAvatar id={view.me} size="lg" />
            {session.handUp ? <span className="hand">✋</span> : null}
            <span>You</span>
          </div>
        ) : null}

        {session.listeners.map((id) => (
          <div key={id} className="listener">
            <PersonAvatar id={id} size="lg" />
            {handIds.has(id) ? <span className="hand">✋</span> : null}
            <span className="truncate max-w-full">
              <PersonName id={id} short />
            </span>
            {view.asHost && handIds.has(id) ? (
              <Button size="tiny" variant="link" onClick={() => actions.invite(id)}>
                Invite
              </Button>
            ) : null}
          </div>
        ))}

        {extra > 0 ? (
          <MoreButton open={false} total={view.total} extra={extra} onClick={onMore} />
        ) : null}
      </div>
    </section>
  );
}
