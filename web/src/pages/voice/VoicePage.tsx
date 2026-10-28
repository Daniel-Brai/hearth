import { useState } from 'react';
import { useParams } from 'react-router';
import {
  Badge,
  ButtonLink,
  cn,
  EmptyState,
  Icon,
  IconButton,
  LiveDot,
  Measure,
  Pill,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import type { AppState } from '@/domain/app-state';
import { useLoad } from '@/data/use-load';
import { canDo, community, post as selectPost, voiceOn } from '@/domain/selectors';
import { routes } from '@/runtime/routes';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { PageHeader } from '@/shell/PageHeader';
import { PageMeta } from '@/shell/PageMeta';
import { RoomRecordings } from './RoomRecordings';
import { IdleRoomCard } from './IdleRoomCard';
import { JoinCard } from './JoinCard';
import { LiveRoom } from './LiveRoom';
import type { ChatToggle } from './LiveRoomControls';
import { VoiceChat } from './VoiceChat';
import { VoiceRoomSettingsDialog } from './VoiceRoomSettingsDialog';
import { useVoiceChat } from './use-voice-chat';
import { useUi } from '@/runtime/ui-store';
import { useVoiceActions } from './use-voice-actions';
import './VoicePage.css';

export function VoicePage() {
  const { community: cid, room: rid } = useParams();

  if (!cid || !rid) return <ErrorPage code={404} />;

  return <VoiceGate cid={cid} rid={rid} />;
}

function VoiceGate({ cid, rid }: { readonly cid: string; readonly rid: string }) {
  const on = useAppState(voiceOn);

  if (!on) return <VoiceOff />;

  return <VoiceLoader cid={cid} rid={rid} />;
}

function VoiceOff() {
  return (
    <main className="error-in-app" id="main">
      <PageMeta title={['Voice rooms are off']} noindex />
      <div className="error-page" id="voice-off">
        <EmptyState
          art="voice"
          title="Voice rooms are off on this instance"
          text="The person who runs this server hasn't turned them on. Text rooms and posts work as usual."
        />
        <ButtonLink to={routes.home} variant="reversed">
          <Icon name="inbox" />
          Go to Catch up
        </ButtonLink>
      </div>
    </main>
  );
}

function VoiceLoader({ cid, rid }: { readonly cid: string; readonly rid: string }) {
  const gateway = useGateway();

  useLoad(() => gateway.load.voice(cid, rid), `voice:${cid}/${rid}`);

  const exists = useAppState((state) => !!community(state, cid)?.voice.some((v) => v.id === rid));

  if (!exists) return <ErrorPage code={404} />;

  return <VoiceView cid={cid} rid={rid} />;
}

function VoiceView({ cid, rid }: { readonly cid: string; readonly rid: string }) {
  const key = cid + '/' + rid;
  const [settingsOpen, setSettingsOpen] = useState(false);

  const view = useAppState((state) => voiceView(state, cid, rid, key));
  const actions = useVoiceActions(cid, rid);
  const ask = useUi((s) => s.ask);
  const [chatOpen, setChatOpen] = useState(false);
  const { unread } = useVoiceChat(key, chatOpen && !view.inRoom);
  const outsideChat = { open: chatOpen, unread, toggle: () => setChatOpen((o) => !o) };

  // Going back from inside a room asks first, and leaving takes you out of it at once
  const confirmLeave = (go: () => void) =>
    ask({
      title: `Leave ${view.name}?`,
      body: "You're still in the room. Leave it now, or stay and keep talking.",
      action: 'Leave room',
      onConfirm: () => void actions.leave().then(go),
    });

  return (
    <>
      <PageHeader
        label={view.name}
        confirmBack={view.inRoom ? confirmLeave : undefined}
        eyebrow={view.communityName}
        title={view.name}
        endActions={
          <>
            {/* Inside the room the tray already says it's on air */}
            {view.live && !view.inRoom ? (
              <Pill live id="voice-live-pill">
                <LiveDot />
                Live
              </Pill>
            ) : null}

            {view.inRoom ? null : <OutsideChatToggle chat={outsideChat} />}

            {view.canRooms ? (
              <IconButton
                id="voice-room-settings-open"
                onClick={() => setSettingsOpen(true)}
                aria-label="Room settings"
                data-tip="Room settings"
              >
                <Icon name="sliders" />
              </IconButton>
            ) : null}
          </>
        }
      />

      {settingsOpen ? (
        <VoiceRoomSettingsDialog
          cid={cid}
          rid={rid}
          name={view.name}
          onClose={() => setSettingsOpen(false)}
        />
      ) : null}

      <main id="main">
        {view.live && view.inRoom ? (
          <InRoom cid={cid} rid={rid} name={view.name} />
        ) : (
          <div className={cn('voice-layout', chatOpen && 'has-chat')}>
            <div className="voice-layout__room">
              <Measure className="grid max-w-[60rem] gap-5">
                {view.live ? (
                  <JoinCard
                    cid={cid}
                    rid={rid}
                    communityName={view.communityName}
                    member={view.member}
                    postId={view.postId}
                    postTitle={view.postTitle}
                  />
                ) : (
                  <IdleRoomCard cid={cid} rid={rid} />
                )}

                <RoomRecordings cid={cid} rid={rid} />
              </Measure>
            </div>

            {chatOpen ? (
              <VoiceChat cid={cid} rid={rid} name={view.name} onClose={() => setChatOpen(false)} />
            ) : null}
          </div>
        )}
      </main>
    </>
  );
}

function voiceView(state: AppState, cid: string, rid: string, key: string) {
  const c = community(state, cid)!;
  const room = c.voice.find((v) => v.id === rid)!;
  const post = selectPost(state, room.postId);

  return {
    communityName: c.name,
    member: c.joined,
    name: room.name,
    live: room.live,
    host: room.host,
    postId: room.postId,
    postTitle: post?.title ?? null,
    inRoom: state.live.joined && state.live.key === key,
    canRooms: canDo(state, cid, 'room.update'),
  };
}

function InRoom({
  cid,
  rid,
  name,
}: {
  readonly cid: string;
  readonly rid: string;
  readonly name: string;
}) {
  const [chatOpen, setChatOpen] = useState(false);
  const { unread } = useVoiceChat(cid + '/' + rid, chatOpen);
  // A share in full screen shows the chat inside it instead
  const shareFull = useUi((s) => s.shareFull);
  const pageChat = chatOpen && !shareFull;

  return (
    <div className={cn('voice-layout', pageChat && 'has-chat')}>
      <div className="voice-layout__room">
        <Measure className="grid max-w-[60rem] gap-5">
          <LiveRoom
            cid={cid}
            rid={rid}
            chat={{ open: chatOpen, unread, toggle: () => setChatOpen((o) => !o) }}
          />

          <RoomRecordings cid={cid} rid={rid} />
        </Measure>
      </div>

      {pageChat ? (
        <VoiceChat cid={cid} rid={rid} name={name} onClose={() => setChatOpen(false)} />
      ) : null}
    </div>
  );
}

// Reading the room's chat doesn't need anyone in the room
function OutsideChatToggle({ chat }: { readonly chat: ChatToggle }) {
  return (
    <IconButton
      id="voice-chat-open"
      className="has-badge"
      onClick={chat.toggle}
      aria-pressed={chat.open}
      aria-controls="voice-chat"
      aria-label={chat.unread ? 'Chat, new messages' : 'Chat'}
      data-tip="Chat"
    >
      <Icon name="chat" />
      {chat.unread ? <Badge red corner className="voice-chat-dot" aria-hidden="true" /> : null}
    </IconButton>
  );
}
