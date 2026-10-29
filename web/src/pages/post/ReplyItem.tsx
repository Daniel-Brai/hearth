import { useState } from 'react';
import { Button, FileList, Icon, IconButton, Menu, MenuItem, Pill, cn } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import type { ReplyPatch } from '@/data/gateway';
import { useAppState } from '@/data/store';
import {
  canDo,
  community,
  displayName,
  isMod,
  person,
  reportsOn,
  shortName,
} from '@/domain/selectors';
import { attachmentSrc, type Post, type Reply } from '@/domain/types';
import { Composer } from '@/features/composer/Composer';
import { Markdown } from '@/features/markdown/Markdown';
import { useFlashFailure } from '@/runtime/use-flash-failure';
import { useUi } from '@/runtime/ui-store';
import { useGuest } from '@/shell/use-guest';
import { ReplyingTo } from '@/features/threads/ReplyingTo';
import { useModerationActions } from '@/features/moderation/use-moderation-actions';
import { PersonAvatar, PersonLink } from '@/shell/people';

type ReplyProps = { readonly post: Post; readonly reply: Reply };

export function ReplyItem({
  post,
  reply,
  isAuthor,
  canAnswer,
  onReplyTo,
  answers,
}: ReplyProps & {
  readonly answers?: Reply | null | undefined;
  readonly isAuthor: boolean;
  readonly canAnswer: boolean;
  readonly onReplyTo: () => void;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);

  const view = useAppState((state) => ({
    admin: community(state, post.c)?.maintainer === reply.who,
    authorShort: shortName(state, post.author),
  }));

  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState<ReplyPatch>({ body: '', files: [] });

  const isAnswer = post.answer === reply.id;

  const save = () => {
    setEditing(false);
    void gateway.posts.editReply(post.id, reply.id, draft).then((r) => {
      if (r.ok) return flash('Saved');
      flash(r.error);
      setEditing(true);
    });
  };

  if (reply.removed) return <RemovedReply post={post} reply={reply} />;

  return (
    <div
      className={cn('reply', reply.parent && 'reply--child', isAnswer && 'is-answer')}
      id={'reply-' + reply.id}
    >
      <PersonAvatar id={reply.who} size={reply.parent ? 'sm' : 'md'} link />

      <div className="grid gap-2 min-w-0">
        <div className="reply__meta">
          <PersonLink id={reply.who} className="reply__author" you />
          {isAuthor ? <Pill>Author</Pill> : null}
          {view.admin ? <Pill tint="violet">Admin</Pill> : null}
          {answers ? <ReplyingTo who={answers.who} target={'reply-' + answers.id} /> : null}
          <span className="subtle">{reply.age === 'now' ? 'just now' : reply.age}</span>
          {reply.edited ? <span className="subtle x-small">edited</span> : null}
        </div>

        {isAnswer ? (
          <div>
            <span className="stamp">
              <strong>Answer</strong>
              <small>Marked by {view.authorShort}</small>
            </span>
          </div>
        ) : null}

        {editing ? (
          <ReplyEditor
            id={reply.id}
            community={post.c}
            draft={draft}
            onChange={setDraft}
            onSave={save}
            onCancel={() => setEditing(false)}
          />
        ) : (
          <>
            <Markdown text={reply.body} community={post.c} files={reply.files ?? []} />
            <ReplyAttachments reply={reply} />
          </>
        )}

        <ReplyActions
          post={post}
          reply={reply}
          isAnswer={isAnswer}
          canAnswer={canAnswer}
          onReplyTo={onReplyTo}
        />
      </div>

      <ReplyMenu
        post={post}
        reply={reply}
        onEdit={() => {
          setDraft({ body: reply.body.join('\n\n'), files: reply.files ?? [] });
          setEditing(true);
        }}
      />
    </div>
  );
}

function ReplyEditor({
  id,
  community: cid,
  draft,
  onChange,
  onSave,
  onCancel,
}: {
  readonly id: string;
  readonly community: string;
  readonly draft: ReplyPatch;
  readonly onChange: (draft: ReplyPatch) => void;
  readonly onSave: () => void;
  readonly onCancel: () => void;
}) {
  return (
    <Composer
      id={'reply-edit-' + id}
      value={draft.body}
      onChange={(body) => onChange({ ...draft, body })}
      onSubmit={onSave}
      onEscape={onCancel}
      placeholder="Write a reply"
      label="Edit reply"
      sendLabel="Save"
      community={cid}
      attachments={draft.files}
      onAttachmentsChange={(files) => onChange({ ...draft, files })}
      autoFocus
      beforeSend={
        <Button size="small" onClick={onCancel}>
          Cancel
        </Button>
      }
    />
  );
}

function ReplyAttachments({ reply }: { readonly reply: Reply }) {
  const openImage = useUi((s) => s.openImage);

  const looseFiles = (reply.files ?? []).filter(
    (f) => !reply.body.join('\n').includes(`attachment:${f.id}`),
  );

  if (!looseFiles.length) return null;

  return (
    <FileList
      files={looseFiles}
      onOpenImage={(f) => openImage(attachmentSrc(f), f.name, f.download)}
    />
  );
}

function ReplyActions({
  post,
  reply,
  isAnswer,
  canAnswer,
  onReplyTo,
}: ReplyProps & {
  readonly isAnswer: boolean;
  readonly canAnswer: boolean;
  readonly onReplyTo: () => void;
}) {
  const gateway = useGateway();
  const settle = useFlashFailure();
  const flash = useUi((s) => s.flash);
  const { viewer, signIn } = useGuest();
  const mine = useAppState((state) => state.me === reply.who);
  const member = viewer === 'member';

  return (
    <div className="reply__actions">
      {mine ? (
        <span className="helpful-count">
          <Icon name="helpful" />
          <span>{reply.helpful}</span>
          <span className="sr-only">found this helpful</span>
        </span>
      ) : (
        <Button
          className="helpful-btn"
          on={member && reply.helpfulMine}
          disabled={viewer === 'unknown'}
          onClick={
            member ? () => settle(gateway.posts.toggleReplyHelpful(post.id, reply.id)) : signIn
          }
          aria-pressed={member && reply.helpfulMine}
        >
          <Icon name="helpful" />
          <span>{reply.helpful}</span>
          <span className="sr-only">helpful</span>
        </Button>
      )}
      {post.locked ? null : (
        <Button
          size="tiny"
          variant="borderless"
          disabled={viewer === 'unknown'}
          onClick={member ? onReplyTo : signIn}
        >
          <Icon name="reply" />
          Reply
        </Button>
      )}
      {canAnswer && !reply.parent ? (
        <Button
          size="tiny"
          onClick={() => {
            const done = isAnswer ? 'Answer removed' : 'Marked as the answer';
            void gateway.posts
              .toggleAnswer(post.id, reply.id)
              .then((r) => flash(r.ok ? done : r.error));
          }}
        >
          <Icon name="check" />
          <span>{isAnswer ? 'Unmark answer' : 'Mark as answer'}</span>
        </Button>
      ) : null}
    </div>
  );
}

function ReplyMenu({
  post,
  reply,
  onEdit,
}: ReplyProps & {
  readonly onEdit: () => void;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const ask = useUi((s) => s.ask);
  const { viewer } = useGuest();

  const moderation = useModerationActions();
  const ref = { c: post.c, kind: 'Reply' as const, id: reply.id, postId: post.id };

  const view = useAppState((state) => ({
    me: state.me,
    name: displayName(state, reply.who),
    short: shortName(state, reply.who),
    username: person(state, reply.who).username,
    mod: isMod(state, post.c),
    canBan: canDo(state, post.c, 'member.ban'),
    reports: reportsOn(state, post.c),
  }));

  const mine = reply.who === view.me;

  const remove = () =>
    mine
      ? ask({
          title: 'Delete this reply?',
          body: 'This removes it for everyone. Replies under it stay.',
          action: 'Delete reply',
          onConfirm: () =>
            void gateway.posts
              .removeReply(post.id, reply.id)
              .then((r) => flash(r.ok ? 'Reply deleted' : r.error)),
        })
      : moderation.remove(ref);

  const report = () =>
    moderation.report({
      c: post.c,
      kind: 'Reply',
      id: reply.id,
      who: reply.who,
      where: 'on “' + post.title + '”',
      text: reply.body[0] ?? '',
    });

  const ban = () =>
    ask({
      title: `Ban ${view.name}?`,
      body: "They can't post, chat or join rooms there until someone unbans them. The reason shows in the public log.",
      action: 'Ban',
      note: { label: 'Reason', placeholder: 'Which guideline they broke', required: true },
      onConfirm: ({ note }) =>
        void gateway.moderation
          .ban({ c: post.c, username: view.username, reason: note, until: 'permanent' })
          .then((r) => flash(r.ok ? `${view.name} is banned` : r.error)),
    });

  return (
    <Menu
      className="reply__menu"
      trigger={({ toggle, open }) => (
        <IconButton
          variant="borderless"
          onClick={toggle}
          aria-expanded={open}
          aria-label="Reply options"
        >
          <Icon name="dots" />
        </IconButton>
      )}
    >
      <MenuItem
        icon="link"
        onSelect={() =>
          void navigator.clipboard
            .writeText(window.location.origin + window.location.pathname + '#reply-' + reply.id)
            .then(
              () => flash('Link copied'),
              () => flash('Could not copy'),
            )
        }
      >
        Copy link
      </MenuItem>
      {mine ? (
        <MenuItem icon="pencil" onSelect={onEdit}>
          Edit
        </MenuItem>
      ) : null}
      {!mine && view.reports && viewer === 'member' ? (
        <MenuItem icon="flag" onSelect={report}>
          Report
        </MenuItem>
      ) : null}
      {mine || view.mod ? (
        <MenuItem icon="trash" danger onSelect={remove}>
          {mine ? 'Delete' : 'Remove'}
        </MenuItem>
      ) : null}
      {!mine && view.canBan ? (
        <MenuItem icon="shield" danger onSelect={ban}>
          Ban {view.short}
        </MenuItem>
      ) : null}
    </Menu>
  );
}

function RemovedReply({ post, reply }: ReplyProps) {
  const mod = useAppState((state) => isMod(state, post.c));
  const { restore } = useModerationActions();

  return (
    <div className={cn('reply', reply.parent && 'reply--child')} id={'reply-' + reply.id}>
      <p className="subtle flex items-center gap-2">
        {reply.moderated ? 'Removed by a moderator' : 'Reply deleted'}
        {reply.moderated && mod ? (
          <Button
            size="tiny"
            onClick={() => restore({ c: post.c, kind: 'Reply', id: reply.id, postId: post.id })}
          >
            Put back
          </Button>
        ) : null}
      </p>
    </div>
  );
}
