import { startTransition, useState } from 'react';
import { useGateway } from '@/app/gateway-context';
import type { Result } from '@/data/gateway';
import { useLoad } from '@/data/use-load';
import { Button, EmptyState, Icon, Link, Pill, Segmented } from '@/design-system';
import { InlineMarkdown } from '@/features/markdown/Markdown';
import { PostRow } from '@/pages/shared/PostRow';
import type { ProfileReply } from './use-profile-view';
import { useProfileActivity } from './use-profile-view';

type Tab = 'posts' | 'replies';

export function ProfileActivity({
  id,
  handle,
  mine,
}: {
  readonly id: string;
  readonly handle: string;
  readonly mine: boolean;
}) {
  const [tab, setTab] = useState<Tab>('posts');

  return (
    <>
      <div className="flex justify-center">
        <Segmented
          name="ptab"
          value={tab}
          onChange={(next) => startTransition(() => setTab(next))}
          label="Posts or replies"
          options={[
            { value: 'posts', label: 'Posts' },
            { value: 'replies', label: 'Replies' },
          ]}
        />
      </div>

      {tab === 'posts' ? (
        <ProfilePosts id={id} handle={handle} mine={mine} />
      ) : (
        <ProfileReplies id={id} handle={handle} mine={mine} />
      )}
    </>
  );
}

type TabProps = { readonly id: string; readonly handle: string; readonly mine: boolean };

function ProfilePosts({ id, handle, mine }: TabProps) {
  const gateway = useGateway();
  const load = useLoad(() => gateway.load.activity(handle, 'posts'), 'profile-posts:' + handle);
  const { posts, postsMore } = useProfileActivity(id);

  return (
    <div className="feed">
      {posts.map((p) => (
        <PostRow key={p.id} post={p} showCommunity />
      ))}
      {load.status === 'error' ? (
        <EmptyState art="posts" title="Couldn't load posts" text={load.error} />
      ) : null}

      {load.status !== 'error' && !posts.length ? (
        <EmptyState
          art="posts"
          title="No posts yet"
          text={
            mine
              ? 'Your posts will show up here.'
              : 'When they post somewhere you can read, it will show up here.'
          }
        />
      ) : null}
      {postsMore ? (
        <ShowMore
          id="profile-posts-more"
          more={() => gateway.load.activity(handle, 'posts', true)}
        />
      ) : null}
    </div>
  );
}

function ProfileReplies({ id, handle, mine }: TabProps) {
  const gateway = useGateway();
  const load = useLoad(() => gateway.load.activity(handle, 'replies'), 'profile-replies:' + handle);
  const { replies, repliesMore } = useProfileActivity(id);

  return (
    <div className="feed">
      {replies.map((r) => (
        <ReplyRow key={r.key} reply={r} />
      ))}
      {load.status === 'error' ? (
        <EmptyState art="replies" title="Couldn't load replies" text={load.error} />
      ) : null}

      {load.status !== 'error' && !replies.length ? (
        <EmptyState
          art="replies"
          title="No replies yet"
          text={
            mine
              ? 'Your replies and answers will show up here.'
              : 'When they reply somewhere you can read, it will show up here.'
          }
        />
      ) : null}
      {repliesMore ? (
        <ShowMore
          id="profile-replies-more"
          more={() => gateway.load.activity(handle, 'replies', true)}
        />
      ) : null}
    </div>
  );
}

function ShowMore({ id, more }: { readonly id: string; readonly more: () => Promise<Result> }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const showMore = async () => {
    setLoading(true);

    try {
      const result = await more();
      setError(result.ok ? null : result.error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="grid justify-items-center gap-1 py-2">
      <Button
        id={id}
        variant="borderless"
        onClick={() => void showMore()}
        disabled={loading}
        busy={loading}
      >
        {loading ? 'Loading' : 'Show more'}
      </Button>
      {error ? (
        <span className="small subtle" role="alert">
          {error}
        </span>
      ) : null}
    </div>
  );
}

function ReplyRow({ reply: r }: { readonly reply: ProfileReply }) {
  return (
    <Link className="post-row" to={r.href}>
      <div className="flex items-center gap-2 flex-wrap">
        <Pill>{r.community}</Pill>
        {r.answer ? (
          <Pill tint="green">
            <Icon name="check" />
            Marked as the answer
          </Pill>
        ) : null}
      </div>
      <span className="small subtle">On “{r.title}”</span>
      {r.excerpt ? (
        <InlineMarkdown
          as="p"
          className="post-row__excerpt"
          text={r.excerpt}
          community={r.c}
          noLinks
        />
      ) : null}
      <span className="post-row__meta">
        <span>
          <Icon name="helpful" />
          <span>{r.helpful} found this helpful</span>
        </span>
        <span>{r.age}</span>
      </span>
    </Link>
  );
}
