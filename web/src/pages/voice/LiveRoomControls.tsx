import {
  Badge,
  Button,
  Icon,
  Menu,
  useMenu,
  EmojiPicker,
  preloadEmojiPicker,
} from '@/design-system';
import { useAppState } from '@/data/store';
import { displayName } from '@/domain/selectors';
import type { LiveRoomView, RoomSession } from './live-room-view';
import type { useVoiceActions } from './use-voice-actions';

type VoiceActions = ReturnType<typeof useVoiceActions>;

export type ChatToggle = {
  readonly open: boolean;
  readonly unread: boolean;
  readonly toggle: () => void;
};

function ReactionPicker({ onPick }: { readonly onPick: (key: string) => void }) {
  const menu = useMenu();

  return (
    <EmojiPicker
      onPick={(key) => {
        onPick(key);
        menu?.close();
      }}
    />
  );
}

export function LiveRoomControls({
  view,
  session,
  actions,
  chat,
}: {
  readonly view: LiveRoomView;
  readonly session: RoomSession;
  readonly actions: VoiceActions;
  readonly chat: ChatToggle;
}) {
  const onStage = view.onStage;
  const sharingMine = session.share !== null && session.share.by === view.me;
  // A room has one share at a time, so someone else's keeps the button off until it stops
  const sharer = useAppState((state) =>
    session.share && !sharingMine ? displayName(state, session.share.by) : null,
  );

  return (
    <div id="voice-controls" className="voice-controls" role="toolbar" aria-label="Room controls">
      {onStage ? (
        <MuteButton view={view} actions={actions} />
      ) : (
        <HandButton session={session} actions={actions} />
      )}

      <Button
        id="voice-share-toggle"
        circle
        on={sharingMine}
        onClick={() => void actions.toggleShare()}
        disabled={!onStage || sharer !== null}
        aria-pressed={sharingMine}
        aria-label={sharingMine ? 'Stop sharing' : 'Share screen'}
        data-tip={shareTip(onStage, sharer, sharingMine)}
      >
        <Icon name="screen" />
      </Button>

      {view.canRecord && !session.recording.on ? (
        <Button
          id="voice-record"
          circle
          onClick={actions.askRecording}
          aria-label="Record"
          data-tip="Record"
        >
          <Icon name="record" />
        </Button>
      ) : null}

      <Menu
        up
        left
        popupClassName="p-0 overflow-hidden"
        trigger={({ open, toggle, id }) => (
          <Button
            id="voice-react"
            circle
            onClick={toggle}
            onPointerEnter={preloadEmojiPicker}
            onFocus={preloadEmojiPicker}
            aria-expanded={open}
            aria-controls={id}
            aria-label="React"
            data-tip="React"
          >
            <Icon name="smile" />
          </Button>
        )}
      >
        <ReactionPicker onPick={actions.react} />
      </Menu>

      <Button
        id="voice-chat-toggle"
        circle
        className="has-badge"
        on={chat.open}
        onClick={chat.toggle}
        aria-pressed={chat.open}
        aria-controls="voice-chat"
        aria-label={chat.unread ? 'Chat, new messages' : 'Chat'}
        data-tip="Chat"
      >
        <Icon name="chat" />
        {chat.unread ? <Badge red corner className="voice-chat-dot" aria-hidden="true" /> : null}
      </Button>

      {view.captionsAllowed ? (
        <Button
          id="voice-captions"
          circle
          on={view.captions}
          onClick={actions.toggleCaptions}
          aria-pressed={view.captions}
          aria-label="Captions"
          data-tip={view.captions ? 'Hide captions' : 'Show captions'}
        >
          <Icon name="captions" />
        </Button>
      ) : null}

      {view.role === 'speaker' && !view.open ? (
        <Button
          id="voice-back-to-listening"
          circle
          onClick={actions.moveToListeners}
          aria-label="Back to listening"
          data-tip="Back to listening"
        >
          <Icon name="volume" />
        </Button>
      ) : null}

      <span className="voice-controls__gap" aria-hidden="true" />

      <Button
        id="voice-leave"
        variant="negative"
        className="voice-controls__leave"
        onClick={() => void actions.leave()}
        aria-label="Leave"
        data-tip="Leave"
      >
        <Icon name="leave" />
      </Button>

      {view.asHost ? (
        <Button
          id="voice-end"
          variant="reversed"
          onClick={actions.endRoom}
          aria-label="End room"
          data-tip="End the room for everyone"
        >
          <Icon name="stop" />
          <span className="voice-controls__label">End room</span>
        </Button>
      ) : null}
    </div>
  );
}

function MuteButton({
  view,
  actions,
}: {
  readonly view: LiveRoomView;
  readonly actions: VoiceActions;
}) {
  return (
    <Button
      id="voice-mute"
      circle
      variant={view.muted ? 'default' : 'positive'}
      onClick={actions.toggleMute}
      aria-pressed={!view.muted}
      aria-label={view.muted ? 'Unmute' : 'Mute'}
      aria-keyshortcuts={view.muteKey}
      data-tip={`${view.muted ? 'Unmute' : 'Mute'} (${view.muteKey})`}
    >
      <Icon name={view.muted ? 'micoff' : 'mic'} />
    </Button>
  );
}

function HandButton({
  session,
  actions,
}: {
  readonly session: RoomSession;
  readonly actions: VoiceActions;
}) {
  return (
    <Button
      id="voice-hand"
      circle
      on={session.handUp}
      onClick={actions.raiseHand}
      aria-pressed={session.handUp}
      aria-label={session.handUp ? 'Lower hand' : 'Raise hand'}
      data-tip={session.handUp ? 'Lower hand' : 'Raise hand'}
    >
      <Icon name="hand" />
    </Button>
  );
}

function shareTip(onStage: boolean, sharer: string | null, mine: boolean) {
  if (sharer) return `${sharer} is sharing their screen. One person shares at a time.`;
  if (!onStage) return 'Join the stage to share your screen';

  return mine ? 'Stop sharing' : 'Share screen';
}
