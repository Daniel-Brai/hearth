import { Button, ButtonLink, cn, Icon, Img, Link, Pill } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { ageText, plural } from '@/domain/format';
import {
  authorName,
  canDo,
  kindInfo,
  liveOnPost,
  postHref,
  recordingFor,
  replyCountOf,
  transcriptionOn,
} from '@/domain/selectors';
import { attachmentSrc, type Post } from '@/domain/types';
import { InlineMarkdown } from '@/features/markdown/Markdown';
import { plainText } from '@/features/markdown/plain-text';
import { ShareButton } from '@/features/share/ShareButton';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { useFlashFailure } from '@/runtime/use-flash-failure';
import { PersonAvatar } from '@/shell/people';

export type PostRowProps = {
  readonly post: Post;
  readonly selected?: boolean | undefined;
  readonly showCommunity?: boolean | undefined;
};

type PostRowView = {
  readonly kindHue: ReturnType<typeof kindInfo>['hue'];
  readonly communityName: string | null;
  readonly author: string;
  readonly live: boolean;
  readonly recorded: boolean;
  readonly transcribed: boolean;
  readonly canPin: boolean;
};

function usePostRowView(post: Post): PostRowView {
  return useAppState((state) => ({
    kindHue: kindInfo(state, post.c, post.kind).hue,
    communityName: state.communities[post.c]?.name ?? null,
    author: authorName(state, post.author),
    live: !!liveOnPost(state, post),
    recorded: !!recordingFor(state, post.id),
    transcribed: !!post.transcript && transcriptionOn(state),
    canPin: canDo(state, post.c, 'post.pin'),
  }));
}

export function PostRow({ post, selected, showCommunity }: PostRowProps) {
  const gateway = useGateway();
  const view = usePostRowView(post);

  const thumb = post.files?.find((f) => f.kind === 'image') ?? null;
  const href = postHref(post);

  return (
    <article
      className={cn(
        'post-row',
        thumb && 'has-thumb',
        !post.seen && 'is-unread',
        selected && 'is-selected',
      )}
    >
      <Link
        className="post-row__link"
        to={href}
        aria-label={post.title}
        onClick={() => void gateway.posts.markSeen(post.id)}
      />

      <PostRowKicker post={post} view={view} showCommunity={showCommunity} />

      {thumb ? <Img className="post-row__thumb" src={attachmentSrc(thumb)} alt="" /> : null}

      <h3 className="post-row__title">{post.title}</h3>

      {post.body[0] ? (
        <InlineMarkdown
          as="p"
          className="post-row__excerpt"
          text={post.body[0]}
          community={post.c}
        />
      ) : null}

      {post.tags.length ? (
        <div className="tags">
          {post.tags.map((t) => (
            <Link key={t} className="ref ref--tag" to={routes.tag(post.c, t)}>
              #{t}
            </Link>
          ))}
        </div>
      ) : null}

      <div className="post-row__foot">
        <PostRowMeta post={post} view={view} />
        <PostRowActions post={post} href={href} canPin={view.canPin} />
      </div>
    </article>
  );
}

function PostRowKicker({
  post,
  view,
  showCommunity,
}: {
  readonly post: Post;
  readonly view: PostRowView;
  readonly showCommunity: boolean | undefined;
}) {
  return (
    <div className="post-row__kicker">
      <Pill tint={view.kindHue} data-tip={post.answer ? 'Answered' : undefined}>
        {post.answer ? (
          <span className="pill__check">
            <Icon name="check" />
          </span>
        ) : null}
        <span>{post.kind}</span>
        {post.answer ? <span className="sr-only">, answered</span> : null}
      </Pill>

      {view.live ? <Pill live>Live now</Pill> : null}
      {showCommunity && view.communityName ? (
        <span className="kicker-text">{view.communityName}</span>
      ) : null}
      {post.pinned ? (
        <span className="kicker-icon" role="img" data-tip="Pinned" aria-label="Pinned">
          <Icon name="pin" />
        </span>
      ) : null}
      {post.locked ? (
        <span className="kicker-icon" role="img" data-tip="Locked" aria-label="Locked">
          <Icon name="lock" />
        </span>
      ) : null}
    </div>
  );
}

function PostRowMeta({ post, view }: { readonly post: Post; readonly view: PostRowView }) {
  return (
    <div className="post-row__meta">
      <span>
        <PersonAvatar id={post.author} size="xs" />
        <span>{view.author}</span>
      </span>
      <span>{ageText(post.age)}</span>
      <span>
        <Icon name="chat" />
        <span>{plural(replyCountOf(post), 'reply', 'replies')}</span>
      </span>
      <span>
        <Icon name="helpful" />
        <span>{post.helpful} helpful</span>
      </span>

      {post.fromChat || view.transcribed || view.recorded ? (
        <PostRowContext post={post} recorded={view.recorded} transcribed={view.transcribed} />
      ) : null}
    </div>
  );
}

function PostRowContext({
  post,
  recorded,
  transcribed,
}: {
  readonly post: Post;
  readonly recorded: boolean;
  readonly transcribed: boolean;
}) {
  return (
    <span className="post-row__context">
      {post.fromChat ? (
        <span
          role="img"
          data-tip={'Started in #' + post.fromChat.room}
          aria-label={'Started in #' + post.fromChat.room}
        >
          <Icon name="hash" />
        </span>
      ) : null}
      {transcribed ? (
        <span role="img" data-tip="Has a transcript" aria-label="Has a transcript">
          <Icon name="captions" />
        </span>
      ) : null}
      {recorded ? (
        <span role="img" data-tip="Has a recording" aria-label="Has a recording">
          <Icon name="video" />
        </span>
      ) : null}
    </span>
  );
}

function PostRowActions({
  post,
  href,
  canPin,
}: {
  readonly post: Post;
  readonly href: string;
  readonly canPin: boolean;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const settle = useFlashFailure();

  const pin = async () => {
    const pinned = post.pinned;
    const r = await gateway.posts.togglePin(post.id);
    flash(r.ok ? (pinned ? 'Unpinned' : 'Pinned') : r.error);
  };

  return (
    <div className="post-row__actions">
      <Button
        className="helpful-btn"
        on={post.helpfulMine}
        aria-pressed={post.helpfulMine}
        onClick={() => settle(gateway.posts.toggleHelpful(post.id))}
      >
        <Icon name="helpful" />
        <span>{post.helpfulMine ? 'Helpful' : 'Mark helpful'}</span>
      </Button>

      {post.locked ? null : (
        <ButtonLink size="tiny" to={href + '?reply=1'}>
          <Icon name="reply" />
          Reply
        </ButtonLink>
      )}

      <ShareButton
        id={`post-row-share-${post.id}`}
        cid={post.c}
        path={href}
        title={post.title}
        text={plainText(post.body).slice(0, 160) || null}
        label="Share post"
      />

      {canPin ? (
        <Button size="tiny" onClick={pin}>
          <Icon name="pin" />
          <span>{post.pinned ? 'Unpin' : 'Pin'}</span>
        </Button>
      ) : null}
    </div>
  );
}
