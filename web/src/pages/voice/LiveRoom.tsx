import { useMemo, useState } from 'react';
import { Button, cn, Icon, Link, OriginNote } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { routes } from '@/runtime/routes';
import { usePageKeys } from '@/shell/key-actions';
import { LiveRoomCaptions } from './LiveRoomCaptions';
import { ModePill } from './ModePill';
import { LiveRoomControls, type ChatToggle } from './LiveRoomControls';
import { LiveRoomListeners } from './LiveRoomListeners';
import { FloatZone, LiveRoomStage, ShareStrip } from './LiveRoomStage';
import { stageTalkers } from './talkers';
import { PeopleDialog } from './PeopleDialog';
import { RecordingBanner } from './RecordingBanner';
import { ShareTile } from './ShareTile';
import { shareLayout } from './share-view';
import { useLiveRoomView, type LiveRoomView } from './live-room-view';
import { useVoiceActions } from './use-voice-actions';
import { unnamedCount, useRoomSession } from './voice-session';

type LiveRoomProps = { readonly cid: string; readonly rid: string; readonly chat: ChatToggle };

export function LiveRoom({ cid, rid, chat }: LiveRoomProps) {
  const key = cid + '/' + rid;
  const actions = useVoiceActions(cid, rid);
  const session = useRoomSession(key);
  const [peopleOpen, setPeopleOpen] = useState(false);
  const view = useLiveRoomView(cid, rid);
  const roomName = useAppState(
    (state) => state.communities[cid]?.voice.find((v) => v.id === rid)?.name ?? '',
  );

  const keys = useMemo(
    () => ({
      voice_mute: () => actions.toggleMute(),
      voice_share: () => void actions.toggleShare(),
    }),
    [actions],
  );

  usePageKeys(keys);

  const extra = unnamedCount(view.total, session, true);
  const sharingMine = session.share !== null && session.share.by === view.me;
  const [gridFor, setGridFor] = useState<string | null>(null);
  const layout = shareLayout(session.share, gridFor);
  const openPeople = () => setPeopleOpen(true);

  return (
    <div id="voice-live" className="grid gap-5">
      <RoomHeading cid={cid} rid={rid} view={view} />

      {session.recording.on ? (
        <RecordingBanner
          startedAt={session.recording.startedAt}
          canStop={view.canRecord}
          onStop={actions.askStopRecording}
        />
      ) : null}

      {session.share && (layout === 'focus' || layout === 'grid') ? (
        <div className={cn(layout === 'focus' && 'voice-focus')}>
          <ShareTile
            by={session.share.by}
            mine={sharingMine}
            focus={layout === 'focus'}
            floats={session.floats}
            talkers={stageTalkers(view, session)}
            onToggleFocus={() => setGridFor(layout === 'focus' ? session.share!.by : null)}
            onReact={actions.react}
            chat={chat}
            room={{ cid, rid, name: roomName }}
          />
          {layout === 'focus' ? (
            <ShareStrip view={view} session={session} onMore={openPeople} />
          ) : null}
        </div>
      ) : null}

      {layout === 'focus' ? null : (
        <>
          <LiveRoomStage
            view={view}
            session={session}
            actions={actions}
            extra={extra}
            sharingMine={sharingMine}
            onMore={openPeople}
          />

          {layout === 'grid' ? null : <FloatZone floats={session.floats} />}

          {view.open ? null : (
            <LiveRoomListeners
              view={view}
              session={session}
              actions={actions}
              extra={extra}
              onMore={openPeople}
            />
          )}
        </>
      )}

      <CallNotices view={view} />

      <LiveRoomControls view={view} session={session} actions={actions} chat={chat} />

      {view.captions ? <LiveRoomCaptions captions={session.captions} /> : null}

      <PeopleDialog
        open={peopleOpen}
        onClose={() => setPeopleOpen(false)}
        total={view.total}
        me={view.me}
        myRole={view.role}
        myMuted={view.muted}
        host={view.host}
        asHost={view.asHost}
        openRoom={view.open}
        session={session}
        onInvite={actions.invite}
      />
    </div>
  );
}

function RoomHeading({
  cid,
  rid,
  view,
}: {
  readonly cid: string;
  readonly rid: string;
  readonly view: LiveRoomView;
}) {
  return (
    <div className="grid gap-1 text-center">
      <ModePill cid={cid} rid={rid} />
      {view.connection === 'reconnecting' ? (
        <div id="voice-reconnecting" className="reconnect-pill" role="status">
          <span className="reconnect-pill__dot" aria-hidden="true" />
          Reconnecting
        </div>
      ) : null}

      {view.topic ? (
        <h2 className="section-title balance text-[length:var(--text-large)] font-black">
          {view.topic}
        </h2>
      ) : null}

      {view.postId ? (
        <Link
          className="small subtle underline"
          to={routes.post(cid, view.postId, view.postTitle ?? undefined)}
        >
          On the post: {view.postTitle ?? 'Read it'}
        </Link>
      ) : null}
    </div>
  );
}

function CallNotices({ view }: { readonly view: LiveRoomView }) {
  const gateway = useGateway();

  if (view.audioBlocked)
    return (
      <OriginNote id="voice-audio-blocked">
        <span className="origin-note__text">
          <Icon name="volume" />
          Your browser held back the room's sound until you tap.
        </span>
        <Button size="tiny" variant="reversed" onClick={() => gateway.voice.resumeAudio()}>
          Tap to hear
        </Button>
      </OriginNote>
    );

  return null;
}
