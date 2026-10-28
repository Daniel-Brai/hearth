import { Icon, IconButton } from '@/design-system';
import { ChatView } from '@/pages/chat/ChatView';
import '@/pages/chat/ChatPage.css';

type VoiceChatProps = {
  readonly cid: string;
  readonly rid: string;
  readonly name: string;
  readonly onClose: () => void;
};

export function VoiceChat({ cid, rid, name, onClose }: VoiceChatProps) {
  const key = cid + '/' + rid;

  return (
    <aside id="voice-chat" className="voice-chat" aria-label={'Chat in ' + name}>
      <header className="voice-chat__head">
        <span className="icon-text" aria-hidden="true">
          <Icon name="chat" />
        </span>
        <span className="voice-chat__title">
          <strong className="small">Chat</strong>
          <span className="x-small subtle truncate">{name} · stays here after the room ends</span>
        </span>
        <IconButton
          id="voice-chat-close"
          variant="borderless"
          onClick={onClose}
          aria-label="Close the chat"
          data-tip="Close"
        >
          <Icon name="x" />
        </IconButton>
      </header>

      <ChatView embedded target={{ key, cid, room: rid, dm: null }} />
    </aside>
  );
}
