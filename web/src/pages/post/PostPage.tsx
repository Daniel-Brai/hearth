import { useState } from 'react';
import { useParams } from 'react-router';
import { useGateway } from '@/app/gateway-context';
import { fail } from '@/data/gateway';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { post as selectPost } from '@/domain/selectors';
import { idFromSegment } from '@/runtime/routes';
import { GuestWall } from '@/shell/GuestWall';
import { useGuestBlocked } from '@/shell/use-guest';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { PostActions } from './PostActions';
import { PostBody, PostHeading, PostOrigins } from './PostContent';
import { PostEditor } from './PostEditor';
import { PostHeaderBar } from './PostHeaderBar';
import { PostReplies, ReplyFooter } from './PostReplies';
import { usePostEffects } from './use-post-effects';
import { usePostView } from './use-post-view';
import './PostPage.css';

export function PostPage() {
  const params = useParams();
  const id = idFromSegment(params.post);
  const gateway = useGateway();

  useLoad(
    () => (id ? gateway.load.post(id) : Promise.resolve(fail('No post'))),
    'post:' + (id ?? 'none'),
  );

  const exists = useAppState((state) => !!id && !!selectPost(state, id));
  const cid = useAppState((state) => (id ? selectPost(state, id)?.c : null));
  const blocked = useGuestBlocked(cid);

  if (!id || !exists) return <ErrorPage code={410} />;
  if (blocked) return <GuestWall />;

  return <PostView id={id} />;
}

function PostView({ id }: { readonly id: string }) {
  const post = useAppState((state) => selectPost(state, id)!);
  const view = usePostView(id);

  usePostEffects(id);

  // Only a click opens the editor so the server renders the post as it reads
  const [editing, setEditing] = useState(false);

  return (
    <>
      <PostHeaderBar post={post} view={view} onEdit={() => setEditing(true)} />

      <main id="main">
        <article className="measure measure--read">
          {editing ? (
            <PostEditor post={post} onDone={() => setEditing(false)} />
          ) : (
            <>
              <PostHeading post={post} view={view} />
              <PostOrigins post={post} view={view} />
              <PostBody post={post} view={view} />
            </>
          )}
          <PostActions post={post} view={view} />
          <PostReplies post={post} view={view} />
          <ReplyFooter post={post} view={view} />
        </article>
      </main>
    </>
  );
}
