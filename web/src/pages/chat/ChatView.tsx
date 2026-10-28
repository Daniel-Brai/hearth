import { Fragment, useState, type RefObject } from 'react';
import { Badge, Button, EmptyState, Icon, Separator } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { plural } from '@/domain/format';
import { canDo, community, isMod, modLevel, reportsOn, roomSettings } from '@/domain/selectors';
import type { Message } from '@/domain/types';
import { Thread } from '@/features/threads/Thread';
import { useThreadDepth } from '@/features/threads/use-thread-depth';
import { buildTree } from '@/features/threads/tree';
import { useUi } from '@/runtime/ui-store';
import { ChatHeader } from './ChatHeader';
import { MessageBox, SelectBar } from './ChatComposerBar';
import { MessageItem } from './MessageItem';
import { PromoteDialog } from './PromoteDialog';
import { RoomSettingsDialog } from './RoomSettingsDialog';
import {
  chatThreads,
  roomTitle,
  type ChatContext,
  type ChatTarget,
  type ChatThread,
} from './chat-select';
import { useChatComposer } from './use-chat-composer';
import { useChatScroll } from './use-chat-scroll';
import { useChatSelection } from './use-chat-selection';
import { useMarkRead } from './use-mark-read';

const NONE: Message[] = [];

type ChatViewProps = {
  readonly target: ChatTarget;
  readonly embedded?: boolean;
};

export function ChatView({ target, embedded = false }: ChatViewProps) {
  const messages = useAppState((state) => state.chats[target.key] ?? NONE);
  const threads = chatThreads(messages);

  const view = useAppState((state) => {
    const cid = target.cid;
    const c = community(state, cid);

    return {
      title: roomTitle(state, target),
      me: state.me,
      communityName: c?.name ?? null,
      joined: !!c?.joined,
      canChat: target.dm !== null || canDo(state, cid, 'message.create'),
      mod: isMod(state, cid),
      promote: target.dm === null && canDo(state, cid, 'chat.promote'),
      reports: target.dm !== null || (!!cid && reportsOn(state, cid, target.room)),
      previews: roomSettings(state, target.key).previews,
      soundsOn: state.settings.sounds,
      unmoderated: !!cid && modLevel(state, cid, target.room) === 'none',
    };
  });

  const [promoting, setPromoting] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);

  useMarkRead(target, messages);

  const scroll = useChatScroll(messages, target.key);
  const selection = useChatSelection(messages);

  const composer = useChatComposer({
    target,
    messages,
    me: view.me,
    soundsOn: view.soundsOn,
    onSent: () => {
      scroll.setAtBottom(true);
      requestAnimationFrame(() => scroll.scrollToLatest(true));
    },
  });

  const { selectMode, cancelSelect, startSelect } = selection;

  const chat: ChatContext = {
    target,
    title: view.title,
    me: view.me,
    mod: view.mod,
    promote: view.promote,
    reports: view.reports,
    previews: view.previews,
    selectMode,
    picked: selection.picked,
    activeId: selection.activeId,
    editingId: composer.editing?.id ?? null,
    setActive: selection.setActiveId,
    togglePick: selection.togglePick,
    startSelect,
    startEdit: composer.startEdit,
    stopEdit: composer.stopEdit,
    replyingId: composer.replying?.id ?? null,
    repliedTo: composer.repliedTo,
    replyTo: composer.replyTo,
  };

  const body = (
    <div className="chat">
      <MessageList
        messages={messages}
        threads={threads}
        chat={chat}
        scroller={scroll.scroller}
        onScroll={scroll.onScroll}
        dm={target.dm !== null}
      />

      {!scroll.atBottom ? (
        <ReturnToLatest missed={scroll.missed} onClick={() => scroll.scrollToLatest(true)} />
      ) : null}

      <div className="chat__composer">
        {selectMode ? (
          <SelectBar
            count={selection.picked.length}
            canPromote={selection.pickedMessages.length > 0}
            onCancel={cancelSelect}
            onPromote={() => setPromoting(true)}
          />
        ) : (
          <MessageBox
            target={target}
            title={view.title}
            canChat={view.canChat}
            joined={view.joined}
            communityName={view.communityName}
            composer={composer}
          />
        )}
      </div>
    </div>
  );

  const promote =
    promoting && target.cid ? (
      <PromoteDialog
        cid={target.cid}
        target={target}
        messages={selection.pickedMessages}
        onClose={() => setPromoting(false)}
        onDone={() => {
          setPromoting(false);
          cancelSelect();
        }}
      />
    ) : null;

  if (embedded) {
    return (
      <>
        {body}
        {promote}
      </>
    );
  }

  return (
    <>
      <ChatHeader
        target={target}
        title={view.title}
        selectMode={selectMode}
        canPromote={view.promote}
        onToggleSelect={() => (selectMode ? cancelSelect() : startSelect(null))}
        onOpenSettings={() => setSettingsOpen(true)}
      />

      <main id="main" className="flush">
        {body}
      </main>

      {promote}

      {settingsOpen && target.cid && target.room ? (
        <RoomSettingsDialog
          cid={target.cid}
          room={target.room}
          title={view.title}
          onClose={() => setSettingsOpen(false)}
        />
      ) : null}
    </>
  );
}

function MessageList({
  messages,
  threads,
  chat,
  scroller,
  onScroll,
  dm,
}: {
  readonly messages: readonly Message[];
  readonly threads: readonly ChatThread[];
  readonly chat: ChatContext;
  readonly scroller: RefObject<HTMLDivElement | null>;
  readonly onScroll: () => void;
  readonly dm: boolean;
}) {
  const emptyText = dm
    ? 'Say hi. Only the two of you can see this.'
    : 'Say hi and get the room going.';

  return (
    <div
      className="chat__messages"
      id="messages"
      ref={scroller}
      onScroll={onScroll}
      aria-live="polite"
    >
      <div className="chat__spacer" />

      {!messages.length ? <EmptyState art="chat" title="No messages yet" text={emptyText} /> : null}

      {threads.map((thread) => (
        <Fragment key={thread.message.id}>
          {thread.day ? <Separator>{thread.day}</Separator> : null}

          <ChatThreadView thread={thread} chat={chat} />
        </Fragment>
      ))}
    </div>
  );
}

function ReturnToLatest({
  missed,
  onClick,
}: {
  readonly missed: number;
  readonly onClick: () => void;
}) {
  const label = missed ? `Jump to ${plural(missed, 'new message')}` : 'Jump to the latest message';

  return (
    <Button
      circle
      className="return-latest has-badge"
      onClick={onClick}
      aria-label={label}
      data-tip="Latest"
    >
      <Icon name="send" style={{ rotate: '180deg' }} />
      {missed ? <Badge red corner count={missed} aria-hidden="true" /> : null}
    </Button>
  );
}

type ChatThreadViewProps = {
  readonly thread: ChatThread;
  readonly chat: ChatContext;
};

function ChatThreadView({ thread, chat }: ChatThreadViewProps) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const depth = useThreadDepth();
  const { message, replies, grouped } = thread;

  if (message.system) return <MessageItem message={message} grouped={false} chat={chat} />;

  return (
    <Thread
      className="thread--chat"
      node={buildTree(message, replies, depth, (m) => m.who)}
      keyOf={(m) => m.id}
      authorOf={(m) => m.who}
      renderItem={(m, answers) => (
        <MessageItem
          message={m}
          grouped={m.id === message.id && grouped}
          chat={chat}
          answers={answers}
        />
      )}
      openFor={(m) => m.id === chat.replyingId || chat.repliedTo.has(m.id)}
      serverCount={(m) => m.answerCounts ?? null}
      onOpen={async (m) => {
        const r = await gateway.chat.loadReplies(chat.target.key, m.id);
        if (!r.ok) flash(r.error);
      }}
    />
  );
}
