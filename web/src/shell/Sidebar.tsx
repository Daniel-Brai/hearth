import { useEffect, useRef } from 'react';
import {
  Badge,
  ButtonLink,
  CommunityMark,
  Icon,
  IconButton,
  Keys,
  Link,
  LiveDot,
  NavLink,
} from '@/design-system';
import { useAppState } from '@/data/store';
import {
  canDo,
  canRequestCommunity,
  canStartCommunity,
  communityUnread,
  creationMode,
  dmCount,
  isInstanceAdmin,
  isMod,
  joinedCids,
  openCommunities,
  pendingRequests,
  person,
  presence,
  queueCountIn,
  shortName,
  unseenCount,
  upcomingEvents,
  voiceOn,
} from '@/domain/selectors';
import { evState } from '@/domain/events';
import { cap } from '@/domain/format';
import { keyOf } from '@/runtime/keys';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { brandFor } from '@/runtime/brand';
import { AccountMenu } from './AccountMenu';
import { PersonAvatar } from './people';
import { useRouteContext } from './use-route-context';

export function Sidebar() {
  const openDialog = useUi((s) => s.openDialog);
  const setSidebarOpen = useUi((s) => s.setSidebarOpen);
  const { community: currentCid } = useRouteContext();
  const aside = useRef<HTMLElement>(null);

  // Following any link closes the drawer on small screens. A wide screen never opens it
  useEffect(() => {
    const el = aside.current;
    if (!el) return;

    const onClick = (e: MouseEvent) => {
      if ((e.target as Element).closest('a[href]')) setSidebarOpen(false);
    };

    el.addEventListener('click', onClick);

    return () => el.removeEventListener('click', onClick);
  }, [setSidebarOpen]);

  const view = useAppState((state) => ({
    brand: brandFor(state.instance),
    me: state.me,
    meName: state.me ? person(state, state.me).name : null,
    directs: state.directs,
    joined: joinedCids(state),
    findable: openCommunities(state).length > 0,
    unseen: unseenCount(state),
    canStart: canStartCommunity(state),
    canRequest: canRequestCommunity(state),
    admin: isInstanceAdmin(state),
    showRequests:
      isInstanceAdmin(state) &&
      (creationMode(state) === 'request' || pendingRequests(state).length > 0),
    pending: pendingRequests(state).length,
    invites: state.invites.mine.length,
    jumpKey: keyOf('jump', state.settings.keys),
    collapsed: state.settings.sidebarCollapsed,
  }));

  const collapse = () => {
    if (window.matchMedia('(min-width: 100ch)').matches) {
      document.documentElement.classList.add('sb-collapsed');
      localStorage.setItem('hearth-sidebar', 'collapsed');
    } else setSidebarOpen(false);
  };

  return (
    <>
      <div className="sidebar-scrim" aria-hidden="true" onClick={() => setSidebarOpen(false)} />

      <aside ref={aside} className="sidebar" id="sidebar" aria-label="Communities">
        <div className="sidebar__top">
          <div className="sidebar__brand">
            <Link to={routes.home} className="logo">
              <span className="contents" dangerouslySetInnerHTML={{ __html: view.brand.mark }} />
              <span>{view.brand.name}</span>
            </Link>

            <IconButton
              variant="borderless"
              onClick={collapse}
              aria-label="Close sidebar"
              data-tip="Hide sidebar"
              data-tip-pos="bottom"
            >
              <Icon name="x" />
            </IconButton>
          </div>

          <button type="button" className="jump-trigger" onClick={() => openDialog('jump')}>
            <Icon name="search" />
            <span>Jump to…</span>
            <Keys combo={view.jumpKey} className="kb-only" />
          </button>

          <DirectMessages directs={view.directs} />
        </div>

        <nav className="sidebar__scroll">
          <NavLink to={routes.home} end className="side-link">
            <span className="side-link__icon">
              <Icon name="inbox" />
            </span>
            <span className="side-link__name">Catch up</span>
            {view.unseen > 0 ? <Badge red count={view.unseen} /> : null}
          </NavLink>

          <div className="side-section">
            <div className="side-label">
              <span>Communities</span>
            </div>

            {view.joined.map((cid) => (
              <CommunitySection key={cid} cid={cid} open={cid === currentCid || !currentCid} />
            ))}

            {!view.joined.length && !view.admin ? (
              <div className="side-empty">
                <span className="side-empty__icon">
                  <Icon name="globe" />
                </span>
                <strong className="small">No communities yet</strong>
                {view.findable ? (
                  <>
                    <span className="x-small subtle">
                      Join one and its feed, rooms and events show up here.
                    </span>
                    <ButtonLink to={routes.home} size="small">
                      Find a community
                    </ButtonLink>
                  </>
                ) : (
                  <span className="x-small subtle">
                    Open an invite link and that community's feed, rooms and events show up here.
                  </span>
                )}
              </div>
            ) : null}

            {view.canStart || view.canRequest ? (
              <Link className="side-link side-link--new" to={routes.newCommunity}>
                <span className="side-link__icon">
                  <span className="side-new-mark">
                    <Icon name="plus" />
                  </span>
                </span>
                <span className="side-link__name">
                  {view.canRequest ? 'Request a community' : 'Start a community'}
                </span>
              </Link>
            ) : null}

            {view.invites ? (
              <NavLink to={routes.myInvites} className="side-link" id="side-my-invites">
                <span className="side-link__icon">
                  <Icon name="mail" />
                </span>
                <span className="side-link__name">Invites</span>
                <Badge red count={view.invites} />
              </NavLink>
            ) : null}

            {view.showRequests ? (
              <NavLink to={routes.requests} className="side-link subtle">
                <span className="side-link__icon">
                  <Icon name="inbox" />
                </span>
                <span className="side-link__name">Community requests</span>
                {view.pending ? <Badge red count={view.pending} /> : null}
              </NavLink>
            ) : null}
          </div>
        </nav>

        <div className="sidebar__tools">
          {view.me ? (
            <AccountMenu
              up
              left
              className="sidebar__me-anchor"
              trigger={({ open, toggle, id }) => (
                <button
                  type="button"
                  className="sidebar__me"
                  onClick={toggle}
                  aria-expanded={open}
                  aria-controls={open ? id : undefined}
                  aria-haspopup="menu"
                  data-tip="Your account"
                  data-tip-pos="top"
                >
                  <PersonAvatar id={view.me!} size="sm" />
                  <span className="truncate">{view.meName}</span>
                </button>
              )}
            />
          ) : null}

          <div className="flex items-center gap-1">
            <IconButton
              variant="borderless"
              className="kb-only"
              onClick={() => openDialog('shortcuts')}
              aria-label="Keyboard shortcuts"
              data-tip="Shortcuts"
              data-tip-pos="top"
            >
              <Icon name="keyboard" />
            </IconButton>

            <ButtonLink
              to={routes.settings}
              circle
              size="small"
              variant="borderless"
              aria-label="Settings"
              data-tip="Settings"
              data-tip-pos="top"
            >
              <Icon name="gear" />
            </ButtonLink>
          </div>
        </div>
      </aside>
    </>
  );
}

function DirectMessages({
  directs,
}: {
  readonly directs: readonly { who: string; unread: number | boolean }[];
}) {
  const names = useAppState((state) =>
    directs.map((d) => ({
      who: d.who,
      unread: dmCount(d),
      short: shortName(state, d.who),
      username: person(state, d.who).username,
      online: !!presence(state, d.who)?.online,
      name: person(state, d.who).name,
    })),
  );

  return (
    <div className="directs" aria-label="Direct messages">
      <NavLink
        to={routes.people}
        className="direct direct--all"
        data-tip="Everyone you can message"
      >
        <span className="avatar avatar--lg direct__all">
          <Icon name="users" />
        </span>
        <span className="direct__name">People</span>
      </NavLink>

      {names.map((d) => (
        <Link
          key={d.who}
          to={routes.dm(d.username)}
          className={d.unread ? 'direct unread' : 'direct'}
          data-tip={[
            d.online ? `${d.name} is online` : d.name,
            d.unread ? `${d.unread} unread` : null,
          ]
            .filter(Boolean)
            .join(' · ')}
        >
          <PersonAvatar id={d.who} size="lg" online={d.online} />
          {d.unread ? <span className="sr-only">{d.unread} unread</span> : null}
          <span className="direct__name">{d.short}</span>
        </Link>
      ))}
    </div>
  );
}

function CommunitySection({ cid, open }: { readonly cid: string; readonly open: boolean }) {
  const openDialog = useUi((s) => s.openDialog);

  const view = useAppState((state) => {
    const c = state.communities[cid]!;
    return {
      name: c.name,
      hue: c.hue,
      letter: c.letter,
      logo: c.logo,
      unread: communityUnread(state, cid),
      live: voiceOn(state) && c.voice.some((v) => v.live),
      eventLive: upcomingEvents(state, cid).some((e) => evState(e) === 'live'),
      rooms: c.rooms,
      voice: voiceOn(state) ? c.voice : [],
      canRooms: canDo(state, cid, 'room.update'),
      canInvite: canDo(state, cid, 'invite.create'),
      // Bans alone still reach the screen, without a count
      mod: isMod(state, cid) || canDo(state, cid, 'member.ban'),
      queue: isMod(state, cid) ? queueCountIn(state, cid) : 0,
      canRoles: canDo(state, cid, 'role.update'),
    };
  });

  return (
    <details className="side-community" open={open}>
      <summary className={view.unread ? 'side-link unread' : 'side-link'}>
        <span className="side-link__icon">
          <CommunityMark hue={view.hue} letter={view.letter} logo={view.logo} size="1.3rem" />
        </span>
        <span className="side-link__name">{view.name}</span>
        {view.live ? <LiveDot /> : null}
        <span className="caret">
          <Icon name="chevron" />
        </span>
      </summary>

      <div className="rooms">
        <NavLink to={routes.community(cid)} end className="side-link">
          <span className="side-link__icon">
            <Icon name="list" />
          </span>
          <span className="side-link__name">Feed</span>
        </NavLink>

        <NavLink to={routes.communityEvents(cid)} className="side-link">
          <span className="side-link__icon">
            <Icon name="calendar" />
          </span>
          <span className="side-link__name">Events</span>
          {view.eventLive ? (
            <Badge red text>
              Live
            </Badge>
          ) : null}
        </NavLink>

        {view.rooms.map((r) => (
          <NavLink
            key={r.id}
            to={routes.chat(cid, r.id)}
            className={r.unread ? 'side-link unread' : 'side-link'}
          >
            <span className="side-link__icon">
              <Icon name="hash" />
            </span>
            <span className="side-link__name">{r.name}</span>
            {r.unread ? <Badge count={r.unread} /> : null}
          </NavLink>
        ))}

        {view.voice.map((v) => (
          <NavLink key={v.id} to={routes.voice(cid, v.id)} className="side-link">
            <span className="side-link__icon">
              <Icon name="volume" />
            </span>
            <span className="side-link__name">{v.name}</span>
            {v.live ? <Badge red count={v.listeners} /> : null}
          </NavLink>
        ))}

        {view.canRooms ? (
          <button
            type="button"
            className="side-link subtle side-link--new"
            onClick={() => openDialog('newRoom', { community: cid })}
          >
            <span className="side-link__icon">
              <Icon name="plus" />
            </span>
            <span className="side-link__name">Add a room</span>
          </button>
        ) : null}

        {view.canRooms ? (
          <button
            type="button"
            id={`archived-rooms-${cid}`}
            className="side-link subtle side-link--new"
            onClick={() => openDialog('archivedRooms', { community: cid })}
          >
            <span className="side-link__icon">
              <Icon name="archive" />
            </span>
            <span className="side-link__name">Archived rooms</span>
          </button>
        ) : null}

        {view.canInvite ? (
          <NavLink to={routes.invite(cid)} className="side-link subtle">
            <span className="side-link__icon">
              <Icon name="invite" />
            </span>
            <span className="side-link__name">Invite people</span>
          </NavLink>
        ) : null}

        {view.mod ? (
          <NavLink to={routes.moderation(cid)} className="side-link subtle">
            <span className="side-link__icon">
              <Icon name="shield" />
            </span>
            <span className="side-link__name">Moderation</span>
            {view.queue ? <Badge red>{cap(view.queue)}</Badge> : null}
          </NavLink>
        ) : null}

        {view.canRoles ? (
          <NavLink to={routes.roles(cid)} className="side-link subtle">
            <span className="side-link__icon">
              <Icon name="roles" />
            </span>
            <span className="side-link__name">Roles</span>
          </NavLink>
        ) : null}
      </div>
    </details>
  );
}
