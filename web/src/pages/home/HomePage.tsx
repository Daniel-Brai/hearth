import { useNavigate } from 'react-router';
import {
  Button,
  ButtonLink,
  CommunityMark,
  EmptyState,
  Icon,
  IconButton,
  Label,
  Link,
  LiveDot,
  Measure,
  OriginNote,
  Separator,
} from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useDisplayZone } from '@/app/request-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { fmt, noun, plural, todayIn } from '@/domain/format';
import {
  canRequestCommunity,
  canStartCommunity,
  catchupCommunities,
  homeEvents,
  isInstanceAdmin,
  joinedCids,
  myRequests,
  openCommunities,
  pendingRequests,
  person,
  seenPosts,
  unseenCount,
} from '@/domain/selectors';
import { InlineMarkdown } from '@/features/markdown/Markdown';
import { routes } from '@/runtime/routes';
import { sfx } from '@/runtime/sounds';
import { useUi } from '@/runtime/ui-store';
import { PageHeader } from '@/shell/PageHeader';
import { EventMini } from '@/pages/shared/EventMini';
import { PostRow } from '@/pages/shared/PostRow';
import './HomePage.css';

function timeOfDayGreeting(hour: number) {
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

function greeting(first: string | null, hour: number, short = false) {
  if (short) return first ? 'Hi, ' + first : 'Hi';
  const time = timeOfDayGreeting(hour);
  return first ? `${time}, ${first}` : time;
}

export function HomePage() {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const navigate = useNavigate();

  useLoad(() => gateway.load.home(), 'home');

  const view = useAppState((state) => ({
    first: state.me ? (person(state, state.me).name.split(' ')[0] ?? null) : null,
    joined: joinedCids(state).length,
    unseen: unseenCount(state),
    admin: isInstanceAdmin(state),
    canStart: canStartCommunity(state),
    canRequest: canRequestCommunity(state),
    pendingRequests: pendingRequests(state).length,
  }));

  const today = todayIn(useDisplayZone());

  const markAll = async () => {
    const r = await gateway.posts.markAllSeen();

    if (!r.ok) return flash(r.error);
    if (view.unseen) sfx('cleared');
    flash("You're all caught up");
  };

  return (
    <>
      <PageHeader
        label="Catch up"
        description="New posts, replies and events from the communities you joined"
        back={false}
        eyebrow={
          <>
            <span className="greet-long">{greeting(view.first, today.hour)}</span>
            <span className="greet-short">{greeting(view.first, today.hour, true)}</span>
            <span className="greet-date"> · {today.date}</span>
          </>
        }
        title="Catch up"
        actions={
          <ButtonLink
            to={routes.newPost}
            circle
            size="small"
            aria-label="Write a post"
            data-tip="Write a post"
          >
            <Icon name="pencil" />
          </ButtonLink>
        }
        endActions={
          view.unseen > 0 ? (
            <IconButton
              onClick={markAll}
              aria-label="Mark everything as seen"
              data-tip="Mark all seen"
            >
              <Icon name="check" />
            </IconButton>
          ) : null
        }
      />

      <main id="main">
        {!view.joined ? (
          <FirstRun
            admin={view.admin}
            canStart={view.canStart}
            canRequest={view.canRequest}
            onCreate={() => void navigate(routes.newCommunity)}
          />
        ) : (
          <Measure className="grid gap-4">
            {view.admin && view.pendingRequests ? (
              <Link className="origin-note" to={routes.requests}>
                <span className="origin-note__text">
                  <Icon name="plus" />
                  <strong>{plural(view.pendingRequests, 'community request')}</strong>
                  <span className="subtle">waiting for you</span>
                </span>
                <span className="btn btn--tiny">Review</span>
              </Link>
            ) : null}

            {view.unseen === 0 ? (
              <div className="cover">
                <EmptyState
                  art="caughtup"
                  title="You're all caught up"
                  text="New posts from your communities show up here first. Older ones move below the line."
                />
              </div>
            ) : null}

            <ComingUp />

            {view.unseen > 0 ? (
              <Separator className="mt-1.5 mb-0">{view.unseen} new for you</Separator>
            ) : null}

            <CatchUpCards />

            <Separator heading>Previously seen</Separator>

            <SeenPosts />
          </Measure>
        )}
      </main>
    </>
  );
}

function FirstRun({
  admin,
  canStart,
  canRequest,
  onCreate,
}: {
  readonly admin: boolean;
  readonly canStart: boolean;
  readonly canRequest: boolean;
  readonly onCreate: () => void;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const openDialog = useUi((s) => s.openDialog);

  const view = useAppState((state) => ({
    requests: myRequests(state).map((r) => r.name),
    open: openCommunities(state).map(([cid, c]) => ({
      cid,
      name: c.name,
      hue: c.hue,
      letter: c.letter,
      logo: c.logo,
      tagline: c.tagline,
      members: c.members,
    })),
  }));

  const join = (cid: string) => {
    const r = gateway.communities.join(cid);
    if (!r.ok) return flash(r.error);
    openDialog('welcome', { community: cid });
  };

  return (
    <Measure className="grid gap-4">
      {admin ? (
        <section className="panel start-card">
          <span className="start-card__mark">
            <Icon name="sparkles" />
          </span>
          <h2 className="start-card__title">Start your first community</h2>
          <p className="subtle">
            You run this instance, so you set things up. Pick a template, name it and choose who can
            see it. You'll be its Owner, and you can invite people right after.
          </p>
          <div>
            <Button variant="reversed" id="start-first" onClick={onCreate}>
              <Icon name="plus" />
              Start a community
            </Button>
          </div>
        </section>
      ) : (
        <section className="grid gap-3">
          <div className="panel start-card">
            <span className="start-card__mark">
              <Icon name="globe" />
            </span>
            <h2 className="start-card__title">Find your people</h2>
            <p className="subtle">
              You're not in any community yet. Join one below, or open an invite link if someone
              sent you one.
            </p>
          </div>

          {canRequest || canStart ? (
            <div className="panel start-card">
              <h2 className="section-title">Want one of your own?</h2>
              <p className="subtle small">
                {canRequest
                  ? "Tell the instance admin what it's for. Once they approve it, you're its Owner."
                  : "Anyone here can start a community. You'll be its Owner."}
              </p>
              {view.requests.map((name) => (
                <p key={name} className="small icon-text">
                  <Icon name="clock" />
                  <span>Your request for {name} is waiting for the admin.</span>
                </p>
              ))}
              <div>
                <Button size="small" onClick={onCreate}>
                  <Icon name="plus" />
                  <span>{canRequest ? 'Request a community' : 'Start a community'}</span>
                </Button>
              </div>
            </div>
          ) : null}

          <div className="join-list" id="join-list">
            {view.open.map((c) => (
              <div key={c.cid} className="join-row">
                <CommunityMark hue={c.hue} letter={c.letter} logo={c.logo} size="2.2rem" />
                <div className="grid" style={{ flex: 1, minInlineSize: 0 }}>
                  <Link
                    to={routes.community(c.cid)}
                    className="truncate"
                    style={{ fontWeight: 800 }}
                  >
                    {c.name}
                  </Link>
                  <span className="x-small subtle truncate">
                    {c.tagline} · {fmt(c.members)} {noun(c.members, 'member')}
                  </span>
                </div>
                <Button size="small" onClick={() => join(c.cid)}>
                  <Icon name="plus" />
                  Join
                </Button>
              </div>
            ))}

            {!view.open.length ? (
              <EmptyState
                art="posts"
                title="No open communities yet"
                text="Communities here are invite only for now. Ask someone for an invite link."
              />
            ) : null}
          </div>
        </section>
      )}
    </Measure>
  );
}

function ComingUp() {
  const events = useAppState((state) => homeEvents(state));

  if (!events.length) return null;

  return (
    <section className="events-strip">
      <div className="flex items-center justify-between gap-2">
        <Label className="icon-text">
          <Icon name="calendar" />
          Coming up in your communities
        </Label>
        <ButtonLink to={routes.events} size="tiny" variant="borderless">
          All events
          <Icon name="chevron" style={{ rotate: '-90deg' }} />
        </ButtonLink>
      </div>

      <div className="events-strip__list">
        {events.map((e) => (
          <EventMini key={e.id} event={e} showCommunity />
        ))}
      </div>
    </section>
  );
}

function CatchUpCards() {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const groups = useAppState((state) => catchupCommunities(state));

  return (
    <>
      {groups.map((g) => (
        <section key={g.cid} className="catchup-card">
          <div className="catchup-card__head">
            <CommunityMark hue={g.c.hue} letter={g.c.letter} logo={g.c.logo} size="2.2rem" />
            <div className="grid" style={{ flex: 1, minInlineSize: 0 }}>
              <h2 className="section-title">
                <Link to={routes.community(g.cid)}>{g.c.name}</Link>
              </h2>
              <span className="x-small subtle">
                {g.total ? plural(g.total, 'new post') : 'Nothing new to read'}
              </span>
            </div>
            {g.total ? (
              <Button
                size="tiny"
                onClick={async () => {
                  const r = await gateway.posts.markCommunitySeen(g.cid);
                  flash(r.ok ? 'Marked as seen' : r.error);
                }}
              >
                <Icon name="check" />
                Mark seen
              </Button>
            ) : null}
          </div>

          {g.c.summary && g.total ? (
            <div className="summary">
              <Label>
                <Icon name="sparkles" />
                While you were away
              </Label>
              <InlineMarkdown as="p" text={g.c.summary} community={g.cid} />
            </div>
          ) : null}

          {g.c.voice
            .filter((v) => v.live)
            .map((v) => (
              <OriginNote key={v.id} live>
                <span className="origin-note__text">
                  <LiveDot />
                  <strong>{v.name}</strong>
                  <span className="truncate subtle">{v.topic}</span>
                </span>
                <span className="listen-actions">
                  <span
                    className="listen-count"
                    data-tip={plural(v.listeners, 'person listening', 'people listening')}
                    aria-label={v.listeners + ' listening'}
                  >
                    <Icon name="users" />
                    <span>{v.listeners}</span>
                  </span>
                  <ButtonLink size="tiny" to={routes.voice(g.cid, v.id)}>
                    <Icon name="volume" />
                    <span>{v.mode === 'open' ? 'Join' : 'Listen in'}</span>
                  </ButtonLink>
                </span>
              </OriginNote>
            ))}

          <div className="feed">
            {g.fresh.map((p) => (
              <PostRow key={p.id} post={p} />
            ))}
          </div>

          {g.more ? (
            <Link className="catchup-card__more" to={routes.community(g.cid)}>
              {plural(g.more, 'more new post', 'more new posts')} in {g.c.name}
              <Icon name="chevron" />
            </Link>
          ) : null}
        </section>
      ))}
    </>
  );
}

function SeenPosts() {
  const posts = useAppState((state) => seenPosts(state));

  if (!posts.length)
    return (
      <EmptyState
        art="posts"
        title="Nothing here yet"
        text="Posts you have read will collect here."
      />
    );

  return (
    <div className="feed">
      {posts.map((p) => (
        <PostRow key={p.id} post={p} showCommunity />
      ))}
    </div>
  );
}
