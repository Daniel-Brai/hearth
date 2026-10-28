import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { Icon, ButtonLink, EmptyState, Measure } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { fail } from '@/data/gateway';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import {
  comingUp,
  community,
  feed,
  feedEmpty,
  pinnedPosts,
  type FeedSort,
} from '@/domain/selectors';
import type { Post } from '@/domain/types';
import { ShareButton } from '@/features/share/ShareButton';
import { routes } from '@/runtime/routes';
import { useFlashFailure } from '@/runtime/use-flash-failure';
import { GuestWall } from '@/shell/GuestWall';
import { useGuest, useGuestBlocked } from '@/shell/use-guest';
import { communityGraph, indexable, useStructuredData } from '@/app/structured-data';
import { PageHeader } from '@/shell/PageHeader';
import { shareImage } from '@/app/share-image';
import { usePageKeys } from '@/shell/key-actions';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { CommunityEventsStrip } from './CommunityEventsStrip';
import { FeedControls, GuestNote, MainFeed, PinnedFeed, TagNote } from './CommunityFeed';
import { CommunityHero } from './CommunityHero';
import { useCommunityView, type CommunityViewData } from './use-community-view';
import { useJoinToggle } from './use-join-toggle';
import './CommunityPage.css';

export function CommunityPage() {
  const { community: cid, tag } = useParams();
  const gateway = useGateway();

  useLoad(
    () => (cid ? gateway.load.community(cid) : Promise.resolve(fail('No community'))),
    'community:' + (cid ?? 'none'),
  );

  const exists = useAppState((state) => !!cid && !!community(state, cid));
  const blocked = useGuestBlocked(cid);

  if (!cid || !exists) return <ErrorPage code={404} />;
  if (blocked) return <GuestWall />;

  return <CommunityView cid={cid} tag={tag?.toLowerCase() ?? null} />;
}

function CommunityView({ cid, tag }: { readonly cid: string; readonly tag: string | null }) {
  const { guest } = useGuest();

  const view = useCommunityView(cid);
  const indexed = useAppState((state) => indexable(state, cid));
  const jsonLd = useStructuredData((state, origin) => communityGraph(state, cid, origin));
  const toggleJoin = useJoinToggle(cid, view.name, view.joined);

  return (
    <>
      <PageHeader
        label={view.name}
        eyebrow="Community"
        title={view.name}
        documentTitle={[view.name]}
        description={view.tagline}
        image={shareImage(`/og/communities/${cid}`, view.banner ?? view.logo)}
        noindex={!indexed || !!tag}
        jsonLd={jsonLd}
        actions={
          guest || view.locked ? null : <WriteActions cid={cid} generalRoom={view.generalRoom} />
        }
        endActions={
          <ShareButton
            id="community-share"
            cid={cid}
            path={routes.community(cid)}
            title={view.name}
            text={view.tagline || null}
            label="Share community"
          />
        }
      />

      <main id="main">
        <Measure className="grid gap-4">
          <CommunityHero cid={cid} view={view} onToggleJoin={toggleJoin} />

          {view.locked ? (
            <EmptyState
              art="invite"
              title="Invite only"
              text="You need an invite to see its posts, rooms and events. Ask someone inside for a link."
            />
          ) : (
            <CommunityContent cid={cid} tag={tag} view={view} guest={guest} />
          )}
        </Measure>
      </main>
    </>
  );
}

function CommunityContent({
  cid,
  tag,
  view,
  guest,
}: {
  readonly cid: string;
  readonly tag: string | null;
  readonly view: CommunityViewData;
  readonly guest: boolean;
}) {
  const [sort, setSort] = useState<FeedSort>('active');
  const [kind, setKind] = useState('all');
  const [selected, setSelected] = useState(-1);

  const posts = useAppState((state) => feed(state, cid, { sort, kind, tag }));
  const pinned = useAppState((state) => pinnedPosts(state, cid));
  const events = useAppState((state) => comingUp(state, cid).slice(0, 2));
  const empty = useAppState((state) => feedEmpty(state, cid, { sort, kind, tag }));

  useFeedKeys(posts, selected, setSelected);

  const showPinned = pinned.length > 0 && kind === 'all' && sort === 'active' && !tag;

  return (
    <>
      {events.length || view.canEvents ? (
        <CommunityEventsStrip cid={cid} events={events} canSchedule={view.canEvents} />
      ) : null}

      {!view.joined ? <GuestNote guest={guest} /> : null}

      {tag ? <TagNote cid={cid} tag={tag} count={posts.length} /> : null}

      <FeedControls
        view={view}
        sort={sort}
        kind={kind}
        onSort={setSort}
        onKind={(k) => {
          setKind(k);
          setSelected(-1);
        }}
      />

      {showPinned ? <PinnedFeed pinned={pinned} compact={view.compact} /> : null}

      <MainFeed cid={cid} view={view} sort={sort} posts={posts} selected={selected} empty={empty} />
    </>
  );
}

function WriteActions({
  cid,
  generalRoom,
}: {
  readonly cid: string;
  readonly generalRoom: string | null;
}) {
  return (
    <>
      <ButtonLink
        to={routes.communityNew(cid)}
        circle
        size="small"
        aria-label="Write a post"
        data-tip="Write a post"
      >
        <Icon name="pencil" />
      </ButtonLink>
      {generalRoom ? (
        <ButtonLink
          to={routes.chat(cid, generalRoom)}
          circle
          size="small"
          className="hide-mobile"
          aria-label="Open chat"
          data-tip="Chat"
        >
          <Icon name="chat" />
        </ButtonLink>
      ) : null}
    </>
  );
}

function useFeedKeys(
  posts: readonly Post[],
  selected: number,
  setSelected: (update: (selected: number) => number) => void,
) {
  const gateway = useGateway();
  const navigate = useNavigate();
  const { guest, signIn } = useGuest();
  const settle = useFlashFailure();

  const keys = useMemo(
    () => ({
      feed_next: () => setSelected((s) => Math.min(posts.length - 1, s + 1)),
      feed_prev: () => setSelected((s) => Math.max(0, s - 1)),
      feed_open: () => {
        const p = posts[selected];
        if (p) void navigate(routes.post(p.c, p.id, p.title));
      },
      feed_helpful: () => {
        const p = posts[selected];
        if (p && guest) signIn();
        else if (p) settle(gateway.posts.toggleHelpful(p.id));
      },
    }),
    [posts, selected, setSelected, navigate, gateway, guest, signIn, settle],
  );

  usePageKeys(keys);
}
