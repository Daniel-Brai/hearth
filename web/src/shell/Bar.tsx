import { useEffect, useState, useSyncExternalStore } from 'react';
import { useLocation, useNavigate } from 'react-router';
import {
  Badge,
  Button,
  ButtonLink,
  cn,
  CommunityMark,
  EmptyState,
  Icon,
  IconButton,
  Keys,
  Link,
  LiveDot,
  Toasts,
} from '@/design-system';
import { useAppState } from '@/data/store';
import { useGateway } from '@/app/gateway-context';
import {
  displayName,
  liveRoom,
  liveRooms,
  unreadList,
  unreadNotifications,
} from '@/domain/selectors';
import { cap } from '@/domain/format';
import type { Notification } from '@/domain/types';
import { keyOf } from '@/runtime/keys';
import { routes } from '@/runtime/routes';
import { sfx } from '@/runtime/sounds';
import { useUi } from '@/runtime/ui-store';
import { AccountMenu } from './AccountMenu';
import { PersonAvatar } from './people';

export function Bar() {
  const trayOpen = useUi((s) => s.trayOpen);
  const liveTrayOpen = useUi((s) => s.liveTrayOpen);
  const toggleTray = useUi((s) => s.toggleTray);
  const closeTrays = useUi((s) => s.closeTrays);
  const openDialog = useUi((s) => s.openDialog);
  const toasts = useUi((s) => s.toasts);

  const view = useAppState((state) => ({
    live: liveRooms(state),
    joined: state.live.joined,
    joinedRoom: liveRoom(state)?.room.name ?? null,
    unread: unreadNotifications(state),
    jumpKey: keyOf('jump', state.settings.keys),
    me: state.me,
  }));

  const offline = useOffline();

  useEffect(() => {
    if (!trayOpen && !liveTrayOpen) return;

    const onDown = (e: PointerEvent) => {
      if (!(e.target as Element).closest('.bar')) closeTrays();
    };

    document.addEventListener('pointerdown', onDown, true);

    return () => document.removeEventListener('pointerdown', onDown, true);
  }, [trayOpen, liveTrayOpen, closeTrays]);

  const showLiveChip = view.live.length > 0 || view.joined;

  return (
    <div className="bar">
      {offline ? (
        <div className="offline-banner" role="status">
          <Icon name="globe" />
          <span>
            You're offline. You can keep reading, and anything you write sends when you reconnect.
          </span>
        </div>
      ) : null}

      <Toasts toasts={toasts} bar />

      <div className="bar__start">
        {showLiveChip ? (
          <button
            type="button"
            className={view.joined ? 'live-chip on-air' : 'live-chip'}
            onClick={() => toggleTray('live')}
            aria-expanded={liveTrayOpen}
          >
            <LiveDot />
            <span className="truncate">
              {view.joined ? 'On air · ' + view.joinedRoom : view.live.length + ' live now'}
            </span>
          </button>
        ) : null}
      </div>

      <button
        type="button"
        className="bar__jump"
        onClick={() => openDialog('jump')}
        aria-label="Jump to anything"
        data-tip="Search"
        data-tip-pos="top"
      >
        <Icon name="search" />
        <span className="bar__jump-label">Jump to anything</span>
        <Keys combo={view.jumpKey} />
      </button>

      <div className="bar__end">
        <IconButton
          className="has-badge"
          onClick={() => toggleTray('notifications')}
          aria-expanded={trayOpen}
          aria-label={view.unread > 0 ? `Notifications, ${view.unread} unread` : 'Notifications'}
          data-tip="Notifications"
          data-tip-pos="top"
        >
          <Icon name="bell" />
          {view.unread > 0 ? <Badge red corner count={view.unread} aria-hidden="true" /> : null}
        </IconButton>

        {view.me ? (
          <AccountMenu
            up
            className="bar__me"
            trigger={({ open, toggle, id }) => (
              <button
                type="button"
                className="bar__me-button"
                onClick={toggle}
                aria-expanded={open}
                aria-controls={open ? id : undefined}
                aria-haspopup="menu"
                aria-label="Your account"
                data-tip="Your account"
                data-tip-pos="top"
              >
                <PersonAvatar id={view.me!} size="sm" />
              </button>
            )}
          />
        ) : null}
      </div>

      {trayOpen ? <NotificationsTray /> : null}
      {liveTrayOpen ? <LiveTray /> : null}
    </div>
  );
}

const EARLIER_PAGE = 20;

export function NotificationsTray() {
  const gateway = useGateway();
  const closeTrays = useUi((s) => s.closeTrays);
  const [earlier, setEarlier] = useState(false);

  const view = useAppState((state) => ({
    unread: unreadList(state),
    read: state.notifications.filter((n) => n.read),
    more: state.notificationsAfter !== null,
    names: Object.fromEntries(
      state.notifications.concat(unreadList(state)).map((n) => [n.who, displayName(state, n.who)]),
    ),
  }));

  const markAll = () => {
    if (view.unread.length) sfx('cleared');
    gateway.notifications.markAllRead();
    setEarlier(false);
  };

  return (
    <div className="tray">
      <div className="tray__head">
        <strong>Notifications</strong>
        {view.unread.length ? (
          <Button size="tiny" variant="borderless" onClick={markAll}>
            Mark all read
          </Button>
        ) : null}
      </div>

      {view.unread.map((n) => (
        <TrayItem
          key={n.id}
          n={n}
          name={view.names[n.who]}
          unread
          onOpen={() => {
            gateway.notifications.open(n.id);
            closeTrays();
          }}
        />
      ))}

      {!view.unread.length ? (
        <EmptyState
          small
          art="caughtup"
          title="You're all caught up"
          text="New replies, mentions and live rooms show up here."
        />
      ) : null}

      {view.read.length ? (
        <EarlierNotifications
          read={view.read}
          more={view.more}
          names={view.names}
          open={earlier}
          onToggle={() => setEarlier((e) => !e)}
        />
      ) : null}
    </div>
  );
}

function TrayItem({
  n,
  name,
  unread,
  onOpen,
}: {
  readonly n: Notification;
  readonly name: string | undefined;
  readonly unread?: boolean;
  readonly onOpen: () => void;
}) {
  return (
    <Link className={cn('tray__item', unread && 'unread')} to={n.href} onClick={onOpen}>
      <PersonAvatar id={n.who} size="sm" />
      <span className="tray__text">
        <strong>{name}</strong> <span>{n.text}</span>
        <span className="tray__target">{n.target}</span>
      </span>
      <span className="x-small subtle">{n.age}</span>
    </Link>
  );
}

function EarlierNotifications({
  read,
  more,
  names,
  open,
  onToggle,
}: {
  readonly read: readonly Notification[];
  readonly more: boolean;
  readonly names: Record<string, string>;
  readonly open: boolean;
  readonly onToggle: () => void;
}) {
  const gateway = useGateway();
  const closeTrays = useUi((s) => s.closeTrays);
  const [shown, setShown] = useState(EARLIER_PAGE);
  const [loading, setLoading] = useState(false);

  const showMore = async () => {
    if (shown >= read.length && more) {
      setLoading(true);

      try {
        await gateway.notifications.loadEarlier();
      } finally {
        setLoading(false);
      }
    }

    setShown((n) => n + EARLIER_PAGE);
  };

  const count = cap(read.length) + (more && read.length <= 99 ? '+' : '');

  return (
    <div className="tray__earlier">
      <button type="button" className="tray__toggle" onClick={onToggle} aria-expanded={open}>
        <span>{open ? 'Hide earlier' : `Show earlier (${count})`}</span>
        <span className={open ? 'tray__caret is-open' : 'tray__caret'}>
          <Icon name="chevron" />
        </span>
      </button>

      {open
        ? read
            .slice(0, shown)
            .map((n) => <TrayItem key={n.id} n={n} name={names[n.who]} onOpen={closeTrays} />)
        : null}

      {open && (shown < read.length || more) ? (
        <Button
          id="tray-show-more"
          size="tiny"
          variant="borderless"
          onClick={() => void showMore()}
          disabled={loading}
          busy={loading}
        >
          Show more
        </Button>
      ) : null}
    </div>
  );
}

export function LiveTray() {
  const gateway = useGateway();
  const navigate = useNavigate();
  const { pathname } = useLocation();
  const flash = useUi((s) => s.flash);
  const closeTrays = useUi((s) => s.closeTrays);

  const view = useAppState((state) => {
    const mine = liveRoom(state);
    return {
      rooms: liveRooms(state),
      joined: state.live.joined,
      muted: state.live.muted,
      mineName: mine?.room.name ?? null,
      mineHref: mine ? routes.voice(mine.cid, mine.room.id) : null,
    };
  });

  const leave = () => {
    const name = view.mineName;

    gateway.voice.leave();
    sfx('leave');
    closeTrays();
    if (name) flash('You left ' + name);
  };

  return (
    <div className="tray tray--start">
      <div className="tray__head">
        <strong>Live now</strong>
      </div>

      {view.joined && view.mineHref ? (
        <div className="tray__item tray__item--plain">
          <LiveDot />
          <div className="tray__text">
            <strong>You are in {view.mineName}</strong>
            <span className="tray__target">{view.muted ? 'Muted' : 'Mic on'}</span>
          </div>
          <div className="flex items-center gap-1">
            {pathname === view.mineHref ? null : (
              <Button
                id="live-tray-return"
                size="tiny"
                onClick={() => void navigate(view.mineHref!)}
              >
                Return
              </Button>
            )}
            <Button size="tiny" variant="negative" onClick={leave}>
              Leave
            </Button>
          </div>
        </div>
      ) : null}

      {!view.rooms.length && !view.joined ? (
        <EmptyState
          small
          art="voice"
          title="Nothing is live right now"
          text="When a voice room starts in one of your communities, it shows up here."
        />
      ) : null}

      {view.rooms.map((r) => (
        <Link
          key={r.key}
          className="tray__item"
          to={routes.voice(r.cid, r.id)}
          onClick={closeTrays}
        >
          <CommunityMark hue={r.hue} letter={r.letter} logo={r.logo} />
          <span className="tray__text">
            <strong>{r.name}</strong> in {r.community}
            <span className="tray__target">{r.topic}</span>
          </span>
          <Badge red count={r.listeners} />
        </Link>
      ))}

      <ButtonLink to={routes.events} size="tiny" variant="borderless" className="hidden">
        Events
      </ButtonLink>
    </div>
  );
}

function subscribeOnline(onChange: () => void) {
  window.addEventListener('online', onChange);
  window.addEventListener('offline', onChange);

  return () => {
    window.removeEventListener('online', onChange);
    window.removeEventListener('offline', onChange);
  };
}

function useOffline(): boolean {
  return useSyncExternalStore(
    subscribeOnline,
    () => !navigator.onLine,
    () => false,
  );
}
