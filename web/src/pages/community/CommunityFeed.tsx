import { useMemo } from 'react';
import {
  ButtonLink,
  EmptyState,
  Icon,
  Label,
  OriginNote,
  Segmented,
  Select,
  cn,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { plural } from '@/domain/format';
import type { FeedSort, feedEmpty } from '@/domain/selectors';
import type { Post } from '@/domain/types';
import { routes } from '@/runtime/routes';
import { PostRow } from '@/pages/shared/PostRow';
import type { CommunityViewData } from './use-community-view';

const SORTS: { value: FeedSort; label: string }[] = [
  { value: 'active', label: 'Active' },
  { value: 'new', label: 'New' },
  { value: 'top', label: 'Most helpful' },
  { value: 'unanswered', label: 'Unanswered' },
];

const SORT_LABEL: Record<FeedSort, string> = {
  active: 'Recent activity',
  new: 'Newest first',
  top: 'Most helpful',
  unanswered: 'Questions without an answer',
};

// The Join button sits in the hero above, so the note only explains
export function GuestNote({ guest }: { readonly guest: boolean }) {
  return (
    <OriginNote id="community-guest-note">
      <span>
        {guest
          ? 'You are reading as a guest. Sign in to post, reply and chat.'
          : "You're reading as a guest. Join to post, reply and chat."}
      </span>
    </OriginNote>
  );
}

export function TagNote({
  cid,
  tag,
  count,
}: {
  readonly cid: string;
  readonly tag: string;
  readonly count: number;
}) {
  return (
    <OriginNote>
      <span className="origin-note__text">
        <Icon name="tag" />
        Posts tagged <strong className="ref ref--tag">#{tag}</strong>
        <span className="subtle">· {plural(count, 'post')}</span>
      </span>
      <ButtonLink size="tiny" to={routes.community(cid)}>
        <Icon name="x" />
        Clear
      </ButtonLink>
    </OriginNote>
  );
}

export function FeedControls({
  view,
  sort,
  kind,
  onSort,
  onKind,
}: {
  readonly view: CommunityViewData;
  readonly sort: FeedSort;
  readonly kind: string;
  readonly onSort: (sort: FeedSort) => void;
  readonly onKind: (kind: string) => void;
}) {
  const gateway = useGateway();

  const kindOptions = useMemo(
    () => [
      { value: 'all', label: 'Everything', hint: String(view.total), count: true },
      ...view.kinds.map((k) => ({
        value: k,
        label: k,
        hint: String(view.kindCounts[k] ?? 0),
        count: true,
      })),
    ],
    [view.kinds, view.kindCounts, view.total],
  );

  return (
    <div className="feed-tools">
      <div className="feed-filter">
        <Select value={sort} options={SORTS} onChange={onSort} label="Sort posts" />
      </div>
      <div className="feed-filter">
        <Select value={kind} options={kindOptions} onChange={onKind} label="Show posts of kind" />
      </div>
      <Segmented
        className="feed-tools__layout"
        name="layout"
        value={view.compact ? 'compact' : 'roomy'}
        onChange={(v) => gateway.settings.update({ compact: v === 'compact' })}
        label="Layout"
        options={[
          {
            value: 'roomy',
            label: (
              <>
                <Icon name="grid" />
                <span className="sr-only">Roomy</span>
              </>
            ),
            tip: 'Roomy',
          },
          {
            value: 'compact',
            label: (
              <>
                <Icon name="list" />
                <span className="sr-only">Compact</span>
              </>
            ),
            tip: 'Compact',
          },
        ]}
      />
    </div>
  );
}

export function PinnedFeed({
  pinned,
  compact,
}: {
  readonly pinned: readonly Post[];
  readonly compact: boolean;
}) {
  return (
    <section className="grid gap-2">
      <Label>Pinned</Label>
      <div className={cn('feed', compact && 'feed--compact')}>
        {pinned.map((p) => (
          <PostRow key={p.id} post={p} />
        ))}
      </div>
    </section>
  );
}

export function MainFeed({
  cid,
  view,
  sort,
  posts,
  selected,
  empty,
}: {
  readonly cid: string;
  readonly view: CommunityViewData;
  readonly sort: FeedSort;
  readonly posts: readonly Post[];
  readonly selected: number;
  readonly empty: ReturnType<typeof feedEmpty>;
}) {
  return (
    <section className="grid gap-2">
      <div className="flex items-center justify-between">
        <Label>{SORT_LABEL[sort]}</Label>
      </div>

      <div className={cn('feed', view.compact && 'feed--compact')}>
        {posts.map((p, i) => (
          <PostRow key={p.id} post={p} selected={i === selected} />
        ))}
      </div>

      {!posts.length ? (
        <div>
          <EmptyState art={empty.art} title={empty.title} text={empty.text} />
          {empty.title === 'No posts yet' && view.canPost ? (
            <div className="flex justify-center">
              <ButtonLink variant="reversed" to={routes.communityNew(cid)}>
                <Icon name="pencil" />
                Write the first post
              </ButtonLink>
            </div>
          ) : null}
        </div>
      ) : null}
    </section>
  );
}
