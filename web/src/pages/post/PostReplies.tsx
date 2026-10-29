import { useState } from 'react';
import { Button, EmptyState, Icon, OriginNote } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { plural } from '@/domain/format';
import type { Attachment, Post } from '@/domain/types';
import { Thread } from '@/features/threads/Thread';
import { useThreadDepth } from '@/features/threads/use-thread-depth';
import { buildForest } from '@/features/threads/tree';
import { Composer } from '@/features/composer/Composer';
import { sfx } from '@/runtime/sounds';
import { useUi } from '@/runtime/ui-store';
import { useGuest } from '@/shell/use-guest';
import { ReplyItem } from './ReplyItem';
import type { PostViewData } from './use-post-view';
import { usePostActions } from './use-post-actions';

const TOP_PAGE = 20;

type PostProps = { readonly post: Post; readonly view: PostViewData };

export function PostReplies({ post, view }: PostProps) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const depth = useThreadDepth();
  const [replyTo, setReplyTo] = useState<string | null>(null);
  const [shownTop, setShownTop] = useState(TOP_PAGE);

  const forest = buildForest(post.replies, depth, (r) => r.who);

  const top = [...forest.values()]
    .map((n) => n.item)
    .sort((a, b) => Number(b.id === post.answer) - Number(a.id === post.answer));

  const moreTop = top.length - shownTop;

  return (
    <section aria-label="Replies">
      {top.slice(0, shownTop).map((r) => (
        <Thread
          key={r.id}
          className="thread--post"
          node={forest.get(r.id)!}
          keyOf={(x) => x.id}
          authorOf={(x) => x.who}
          renderItem={(x, answers) => (
            <ReplyItem
              post={post}
              reply={x}
              answers={answers}
              isAuthor={x.who === post.author}
              canAnswer={view.canAnswer && !x.parent}
              onReplyTo={() => setReplyTo((cur) => (cur === x.id ? null : x.id))}
            />
          )}
          serverCount={(x) => x.answerCounts ?? null}
          onOpen={async (x) => {
            const res = await gateway.posts.loadReplies(post.id, x.id);
            if (!res.ok) flash(res.error);
          }}
          composerFor={(x) =>
            replyTo === x.id && !post.locked ? (
              <ChildComposer post={post} parent={x.id} onDone={() => setReplyTo(null)} />
            ) : null
          }
        />
      ))}

      {moreTop > 0 ? (
        <button
          type="button"
          className="thread__more thread__more--top"
          onClick={() => setShownTop((shown) => shown + TOP_PAGE)}
        >
          <Icon name="chevron" />
          Show {plural(Math.min(moreTop, TOP_PAGE), 'more reply', 'more replies')}
        </button>
      ) : null}

      {!post.replies.length && !post.locked ? (
        <EmptyState
          art="replies"
          title="No replies yet"
          text={
            post.author === view.me
              ? 'Answers show up here, and you get a notification for each. Add details below if it helps.'
              : 'Be the first to help. Even a link to the docs counts.'
          }
        />
      ) : null}
    </section>
  );
}

export function ReplyFooter({ post, view }: PostProps) {
  const { viewer, signIn } = useGuest();

  if (post.locked) {
    return (
      <OriginNote id="post-locked-note" className="mt-5">
        <span className="flex items-center gap-2">
          <Icon name="lock" />
          {view.mod
            ? 'Replies are closed. Unlock the post from its menu to open them again.'
            : 'Replies are closed on this post.'}
        </span>
      </OriginNote>
    );
  }

  if (viewer === 'unknown') return <span className="skel skel--block mt-5" aria-hidden="true" />;

  if (viewer === 'guest') {
    return (
      <OriginNote id="guest-reply-note" className="mt-5">
        <span>
          Sign in to reply, mark things helpful and join <strong>{view.communityName}</strong>.
        </span>
        <Button size="tiny" variant="reversed" onClick={signIn}>
          Sign in
        </Button>
      </OriginNote>
    );
  }

  return view.joined ? <TopComposer post={post} /> : <JoinNote post={post} view={view} />;
}

function JoinNote({ post, view }: PostProps) {
  const { join } = usePostActions(post, view);

  return (
    <OriginNote className="mt-5">
      <span>
        Join <strong>{view.communityName}</strong> to reply.
      </span>
      <Button size="tiny" variant="reversed" onClick={join}>
        <Icon name="plus" />
        Join
      </Button>
    </OriginNote>
  );
}

function TopComposer({ post }: { readonly post: Post }) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const [text, setText] = useState('');
  const [files, setFiles] = useState<Attachment[]>([]);
  const [error, setError] = useState<string | null>(null);

  // The box empties at once and gets the reply back if it doesn't post
  const send = async () => {
    const sent = { text, files };

    setText('');
    setFiles([]);
    setError(null);

    const r = await gateway.posts.reply(post.id, {
      parent: null,
      body: sent.text,
      files: sent.files,
    });

    if (!r.ok) {
      setText(sent.text);
      setFiles(sent.files);
      setError(r.error);
      sfx('error');
      return;
    }

    flash('Reply posted');

    requestAnimationFrame(() =>
      document
        .getElementById('reply-' + r.value.reply.id)
        ?.scrollIntoView({ behavior: 'smooth', block: 'center' }),
    );
  };

  return (
    <div className="mt-5">
      <Composer
        id="reply-box"
        value={text}
        onChange={setText}
        onSubmit={() => void send()}
        placeholder="Add to the conversation. You can @mention people and add #tags."
        sendLabel="Reply"
        community={post.c}
        attachments={files}
        onAttachmentsChange={setFiles}
        error={error}
      />
    </div>
  );
}

function ChildComposer({
  post,
  parent,
  onDone,
}: {
  readonly post: Post;
  readonly parent: string;
  readonly onDone: () => void;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const [text, setText] = useState('');
  const [files, setFiles] = useState<Attachment[]>([]);
  const [error, setError] = useState<string | null>(null);

  const send = async () => {
    const r = await gateway.posts.reply(post.id, { parent, body: text, files });

    if (!r.ok) {
      setError(r.error);
      sfx('error');
      return;
    }

    flash('Reply posted');
    onDone();
  };

  return (
    <Composer
      id="child-box"
      value={text}
      onChange={setText}
      onSubmit={() => void send()}
      placeholder="Write a reply"
      sendLabel="Reply"
      community={post.c}
      attachments={files}
      onAttachmentsChange={setFiles}
      error={error}
      autoFocus
      onEscape={onDone}
    />
  );
}
