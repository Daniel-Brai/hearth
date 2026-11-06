import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import {
  Button,
  cn,
  FileList,
  Icon,
  IconButton,
  Link,
  LinkPreview,
  Menu,
  MenuItem,
} from '@/design-system';
import { authorName, displayName } from '@/domain/selectors';
import type { Message } from '@/domain/types';
import { BoostMenu, Boosts } from '@/features/boosts/BoostMenu';
import { InlineMarkdown, Markdown } from '@/features/markdown/Markdown';
import { useModerationActions } from '@/features/moderation/use-moderation-actions';
import { PollCard } from '@/features/polls/PollCard';
import { firstUrl, useLinkPreview } from '@/features/previews';
import { ReplyingTo } from '@/features/threads/ReplyingTo';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { PersonAvatar, PersonLink } from '@/shell/people';

import type { ChatContext } from './chat-select';

type MessageItemProps = {
  readonly message: Message;
  readonly grouped: boolean;
  readonly chat: ChatContext;
  readonly answers?: Message | null | undefined;
};

export function MessageItem({ message: m, grouped, chat, answers }: MessageItemProps) {
  if (m.system) return <SystemMessage message={m} chat={chat} />;

  return <ChatMessage message={m} grouped={grouped} chat={chat} answers={answers} />;
}

function SystemMessage({
  message: m,
  chat,
}: {
  readonly message: Message;
  readonly chat: ChatContext;
}) {
  const name = useAppState((state) => authorName(state, m.who));
  const { restore } = useModerationActions();

  if (m.moderated)
    return (
      <div className="message--system" id={'msg-' + m.id}>
        <Icon name="shield" />
        <span className="subtle">Removed by a moderator</span>
        {chat.mod ? (
          <Button
            size="tiny"
            onClick={() =>
              restore({
                c: chat.target.cid ?? 'dm',
                kind: 'Message',
                id: m.id,
                key: chat.target.key,
              })
            }
          >
            Put back
          </Button>
        ) : null}
      </div>
    );

  if (m.promoted && chat.target.cid)
    return (
      <div className="message--system" id={'msg-' + m.id}>
        <Icon name="megaphone" />
        <span>
          <strong>{name}</strong> turned messages into a post{' '}
          <Link to={routes.post(chat.target.cid, m.promoted.id, m.promoted.title)}>
            {m.promoted.title}
          </Link>
        </span>
      </div>
    );

  return (
    <div className="message--system" id={'msg-' + m.id}>
      <PersonAvatar id={m.who} size="xs" />
      <span>
        <strong>{name}</strong> <InlineMarkdown text={m.text} community={chat.target.cid} />
      </span>
    </div>
  );
}

function ChatMessage({ message: m, grouped, chat, answers }: MessageItemProps) {
  const gateway = useGateway();

  const { target } = chat;
  const mine = m.who === chat.me;
  const picked = chat.picked.includes(m.id);
  const editing = chat.editingId === m.id;

  const name = useAppState((state) => displayName(state, m.who));
  const author = useAppState((state) => authorName(state, m.who));

  const hasText = !!m.text;
  const tools = chat.selectMode ? null : <MessageTools message={m} chat={chat} />;

  return (
    <div
      className={cn(
        'message',
        grouped && 'is-grouped',
        mine && 'is-me',
        picked && 'is-selected',
        chat.activeId === m.id && 'is-active',
        chat.replyingId === m.id && 'is-reply-target',
        editing && 'is-editing',
      )}
      id={'msg-' + m.id}
    >
      <PersonLink id={m.who} className="message__avatar" labelled>
        <PersonAvatar id={m.who} size="sm" />
      </PersonLink>

      <div className="message__meta">
        <strong>{author}</strong>
        {answers ? <ReplyingTo who={answers.who} target={'msg-' + answers.id} /> : null}
        <span>{m.time}</span>
        {m.edited ? <span>edited</span> : null}
      </div>

      <div className="message__body">
        {chat.selectMode ? (
          <input
            type="checkbox"
            className="message__check"
            checked={picked}
            onChange={() => chat.togglePick(m.id)}
            aria-label={'Select message from ' + name}
          />
        ) : null}

        {hasText ? <MessageContent message={m} chat={chat} mine={mine} /> : null}

        {hasText ? tools : null}
      </div>

      <MessageFiles message={m} />

      {hasText ? null : <div className="message__body message__body--after">{tools}</div>}

      <MessagePreview message={m} chat={chat} />

      <Boosts
        boosts={m.boosts}
        onToggle={(key) => gateway.chat.toggleBoost(target.key, m.id, key)}
      />
    </div>
  );
}

/** A poll's question shows on its card, and every other message in a bubble */
function MessageContent({
  message: m,
  chat,
  mine,
}: {
  readonly message: Message;
  readonly chat: ChatContext;
  readonly mine: boolean;
}) {
  if (!m.poll) return <MessageBubble message={m} chat={chat} />;

  return (
    <PollCard
      chatKey={chat.target.key}
      messageId={m.id}
      question={m.text}
      poll={m.poll}
      canClose={mine || chat.mod}
    />
  );
}

function MessageBubble({
  message: m,
  chat,
}: {
  readonly message: Message;
  readonly chat: ChatContext;
}) {
  const clickBubble = (e: { target: EventTarget }) => {
    if (chat.selectMode) {
      chat.togglePick(m.id);
      return;
    }

    if (e.target instanceof Element && e.target.closest('a')) return;

    chat.setActive(chat.activeId === m.id ? null : m.id);
  };

  return (
    // react-doctor-disable-next-line react-doctor/click-events-have-key-events, react-doctor/no-static-element-interactions -- tapping a bubble is a touch shortcut; keyboard users select with the checkbox and reach the tools by focus
    <div
      className="message__bubble"
      onClick={clickBubble}
      style={chat.selectMode ? { cursor: 'pointer' } : undefined}
    >
      <Markdown
        text={m.text}
        community={chat.target.cid}
        files={m.files ?? []}
        everyone={m.mentionsAll}
      />
    </div>
  );
}

function MessageFiles({ message: m }: { readonly message: Message }) {
  const openImage = useUi((s) => s.openImage);
  const looseFiles = (m.files ?? []).filter((f) => !m.text.includes(`attachment:${f.id}`));

  if (!looseFiles.length) return null;

  return (
    <FileList
      files={looseFiles}
      onOpenImage={(f) => {
        const src = f.data ?? f.url;
        if (src) openImage(src, f.name, f.download);
      }}
    />
  );
}

function MessagePreview({
  message: m,
  chat,
}: {
  readonly message: Message;
  readonly chat: ChatContext;
}) {
  const gateway = useGateway();
  const previewUrl = chat.previews && !m.previewHidden ? firstUrl(m.text) : null;
  const preview = useLinkPreview(previewUrl);

  if (!preview) return null;

  return (
    <div className="og-wrap">
      <LinkPreview
        preview={preview}
        onRemove={
          m.who === chat.me || chat.mod
            ? () => gateway.chat.hidePreview(chat.target.key, m.id)
            : undefined
        }
      />
    </div>
  );
}

function MessageTools({
  message: m,
  chat,
}: {
  readonly message: Message;
  readonly chat: ChatContext;
}) {
  const gateway = useGateway();
  const { target } = chat;

  return (
    <div className="message__tools">
      <BoostMenu
        up
        boosts={m.boosts}
        onPick={(key) => gateway.chat.toggleBoost(target.key, m.id, key)}
        trigger={({ toggle, open }) => (
          <IconButton
            variant="borderless"
            onClick={toggle}
            aria-expanded={open}
            aria-label="Boost"
            data-tip="Boost"
            data-tip-pos="top"
          >
            <Icon name="smile" />
          </IconButton>
        )}
      />

      <IconButton
        variant="borderless"
        onClick={() => chat.replyTo(m)}
        aria-pressed={chat.replyingId === m.id}
        aria-label="Reply"
        data-tip="Reply"
        data-tip-pos="top"
      >
        <Icon name="reply" />
      </IconButton>

      <MessageMenu message={m} chat={chat} />
    </div>
  );
}

function MessageMenu({
  message: m,
  chat,
}: {
  readonly message: Message;
  readonly chat: ChatContext;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const ask = useUi((s) => s.ask);

  const { target } = chat;
  const mine = m.who === chat.me;

  const copyLink = () =>
    void navigator.clipboard
      .writeText(window.location.origin + window.location.pathname + '#msg-' + m.id)
      .then(
        () => flash('Link copied'),
        () => flash('Copy the address from the bar'),
      );

  const moderation = useModerationActions();
  const ref = { c: target.cid ?? 'dm', kind: 'Message' as const, id: m.id, key: target.key };

  const remove = () =>
    mine
      ? ask({
          title: 'Delete this message?',
          body: 'It will be removed for everyone in the room.',
          action: 'Delete message',
          onConfirm: () => {
            gateway.chat.remove(target.key, m.id);
            flash('Message deleted');
          },
        })
      : moderation.remove(ref);

  const report = () =>
    moderation.report({
      c: target.cid ?? 'dm',
      r: target.room,
      kind: 'Message',
      id: m.id,
      who: m.who,
      where: 'in ' + chat.title,
      text: m.text,
      dm: target.dm !== null,
    });

  return (
    <Menu
      up
      left
      trigger={({ toggle, open }) => (
        <IconButton variant="borderless" onClick={toggle} aria-expanded={open} aria-label="More">
          <Icon name="dots" />
        </IconButton>
      )}
    >
      {chat.promote ? (
        <MenuItem icon="megaphone" onSelect={() => chat.startSelect(m.id)}>
          Promote to a post
        </MenuItem>
      ) : null}
      <MenuItem icon="link" onSelect={copyLink}>
        Copy link
      </MenuItem>
      {mine && !m.poll ? (
        <MenuItem icon="pencil" keys="up" onSelect={() => chat.startEdit(m.id)}>
          Edit
        </MenuItem>
      ) : null}
      {!mine && chat.reports ? (
        <MenuItem icon="flag" onSelect={report}>
          Report
        </MenuItem>
      ) : null}
      {mine || chat.mod ? (
        <MenuItem icon="trash" danger onSelect={remove}>
          {mine ? 'Delete' : 'Remove'}
        </MenuItem>
      ) : null}
    </Menu>
  );
}
