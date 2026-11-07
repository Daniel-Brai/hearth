import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { EmptyState, Measure } from '@/design-system';
import { ScrollMore } from '@/features/paging/ScrollMore';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { PostRow } from '@/pages/shared/PostRow';
import { PageHeader } from '@/shell/PageHeader';

export function SavedPage() {
  const gateway = useGateway();
  const load = useLoad(() => gateway.load.saved(), 'saved');
  const ids = useAppState((state) => state.saved.ids);
  const more = useAppState((state) => state.saved.after !== null);

  if (load.status === 'error') return <ErrorPage code="offline" />;

  return (
    <>
      <PageHeader label="Saved" eyebrow="For you" title="Saved" />

      <main id="main">
        <Measure narrow className="feed" id="saved-posts">
          {ids.map((id) => (
            <SavedRow key={id} id={id} />
          ))}

          {!ids.length ? (
            <EmptyState
              art="posts"
              title="Nothing saved yet"
              text="Tap Save on a post to keep it here. Only you can see what you saved."
            />
          ) : null}

          {more ? <ScrollMore id="saved-more" more={() => gateway.load.saved(true)} /> : null}
        </Measure>
      </main>
    </>
  );
}

function SavedRow({ id }: { readonly id: string }) {
  const post = useAppState((state) => state.posts.find((p) => p.id === id));

  return post ? <PostRow post={post} showCommunity /> : null;
}
