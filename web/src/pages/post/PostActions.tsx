import { Button, Icon, Keys } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { plural } from '@/domain/format';
import type { Post } from '@/domain/types';
import { BoostMenu } from '@/features/boosts/BoostMenu';
import { useGuest } from '@/shell/use-guest';
import type { PostViewData } from './use-post-view';
import { usePostActions } from './use-post-actions';
import { useFlashFailure } from '@/runtime/use-flash-failure';

export function PostActions({ post, view }: { readonly post: Post; readonly view: PostViewData }) {
  const { guest, signIn } = useGuest();

  if (guest) {
    return (
      <GuestActions
        helpful={post.helpful}
        replies={post.replies.length}
        locked={!!post.locked}
        onSignIn={signIn}
      />
    );
  }

  return <MemberActions post={post} view={view} />;
}

function MemberActions({ post, view }: { readonly post: Post; readonly view: PostViewData }) {
  const gateway = useGateway();
  const settle = useFlashFailure();
  const { startLive } = usePostActions(post, view);
  const id = post.id;
  const mine = post.author === view.me;

  return (
    <div className="post-actions">
      {mine ? (
        <span className="helpful-count" id="post-helpful-count">
          <Icon name="helpful" />
          <span>Helpful · {post.helpful}</span>
        </span>
      ) : (
        <Button
          size="small"
          className="helpful-btn"
          on={post.helpfulMine}
          onClick={() => settle(gateway.posts.toggleHelpful(id))}
          aria-pressed={post.helpfulMine}
        >
          <Icon name="helpful" />
          <span>Helpful · {post.helpful}</span>
        </Button>
      )}

      <BoostMenu
        boosts={post.boosts}
        onPick={(key) => settle(gateway.posts.toggleBoost(id, key))}
        trigger={({ toggle, open }) => (
          <Button size="small" onClick={toggle} aria-expanded={open}>
            <Icon name="smile" />
            Boost
          </Button>
        )}
      />

      {post.locked ? null : (
        <Button size="small" onClick={() => document.getElementById('reply-box')?.focus()}>
          <Icon name="reply" />
          Reply
          <Keys combo={view.replyKey} className="hide-mobile" />
        </Button>
      )}

      {view.voice && !view.live && mine && view.joined ? (
        <Button
          size="small"
          onClick={() => void startLive()}
          data-tip={`Talk your post through in a voice room. Everyone reading it gets asked to join${view.transcribed ? ', and the transcript is saved back here.' : '.'}`}
        >
          <Icon name="mic" />
          Discuss live
        </Button>
      ) : null}

      {/* With none, the replies below already say there are none yet */}
      {post.replies.length ? (
        <span className="x-small subtle ms-auto">
          {plural(post.replies.length, 'reply', 'replies')}
        </span>
      ) : null}
    </div>
  );
}

function GuestActions({
  helpful,
  replies,
  locked,
  onSignIn,
}: {
  readonly helpful: number;
  readonly replies: number;
  readonly locked: boolean;
  readonly onSignIn: () => void;
}) {
  return (
    <div className="post-actions">
      <Button size="small" className="helpful-btn" onClick={onSignIn}>
        <Icon name="helpful" />
        <span>Helpful · {helpful}</span>
      </Button>

      {locked ? null : (
        <Button size="small" onClick={onSignIn}>
          <Icon name="reply" />
          Reply
        </Button>
      )}

      {replies ? (
        <span className="x-small subtle ms-auto">{plural(replies, 'reply', 'replies')}</span>
      ) : null}
    </div>
  );
}
