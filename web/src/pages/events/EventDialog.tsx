import { useGateway } from '@/app/gateway-context';
import { useDisplayZone, useOrigin } from '@/app/request-context';
import { useEffect, type ReactNode } from 'react';
import {
  Button,
  cn,
  Dialog,
  DialogBody,
  DialogClose,
  DialogFooter,
  Icon,
  Label,
  Link,
  Menu,
  type IconName,
} from '@/design-system';
import { useAppState } from '@/data/store';
import { evRepeatLabel, evState, evWhen, evWhere, evZone } from '@/domain/events';
import { tintStyle } from '@/domain/format';
import { canManageEvent, displayName, isInterested, shortName } from '@/domain/selectors';
import type { CommunityEvent } from '@/domain/types';
import { Markdown } from '@/features/markdown/Markdown';
import { RecordingList } from '@/features/recordings/RecordingList';
import { toRow } from '@/features/recordings/recording-row';
import { plainText } from '@/features/markdown/plain-text';
import { ShareButton } from '@/features/share/ShareButton';
import { useShareable } from '@/features/share/use-shareable';
import { routes } from '@/runtime/routes';
import { EventDate } from '@/pages/shared/EventMini';
import { PersonAvatar } from '@/shell/people';
import { eventFile, eventIcs, alwaysChanged, snapshot } from './event-utils';
import { EventManageItems } from './EventManageItems';
import { JoinButton, PlaceIcon } from './Place';
import { useEventActions } from './use-event-actions';

export type EventDialogProps = {
  readonly id: string;
  readonly onClose: () => void;
  readonly onEdit: (e: CommunityEvent) => void;
};

export function EventDialog({ id, onClose, onEdit }: EventDialogProps) {
  const event = useAppState((state) => {
    const e = state.events.find((x) => x.id === id);
    return e ? snapshot(e) : null;
  }, alwaysChanged);

  if (!event) return null;

  return <EventDialogBody event={event} onClose={onClose} onEdit={onEdit} />;
}

function EventDialogBody({
  event,
  onClose,
  onEdit,
}: {
  readonly event: CommunityEvent;
  readonly onClose: () => void;
  readonly onEdit: (e: CommunityEvent) => void;
}) {
  const actions = useEventActions(onClose);
  const origin = useOrigin();

  const view = useAppState(
    (state) => ({
      community: state.communities[event.c],
      interested: isInterested(state, event),
      manage: canManageEvent(state, event),
      host: displayName(state, event.host),
      me: state.me,
      names: Object.fromEntries(event.interested.map((id) => [id, shortName(state, id)])),
    }),
    alwaysChanged,
  );

  const shareable = useShareable(event.c);
  const phase = evState(event);
  const place = evWhere(event, view.community);
  const active = !event.cancelled && phase !== 'past';

  return (
    <Dialog open onClose={onClose} width="34rem" labelledBy="ev-view-title">
      <DialogClose onClick={onClose} />

      <DialogBody className="text-start">
        {view.manage ? (
          <Menu
            left
            className="dialog__more"
            trigger={({ open, toggle, id }) => (
              <Button
                circle
                size="small"
                variant="borderless"
                onClick={toggle}
                aria-expanded={open}
                aria-controls={id}
                aria-label="Manage event"
                data-tip="Manage event"
              >
                <Icon name="dots" />
              </Button>
            )}
          >
            <EventManageItems event={event} active={active} actions={actions} onEdit={onEdit} />
          </Menu>
        ) : null}

        <div className="event-hero" style={tintStyle(view.community?.hue)}>
          <EventDate event={event} />
          <div className="grid gap-1" style={{ minInlineSize: 0 }}>
            <Label>{view.community?.name}</Label>
            <h2 className="dialog__title m-0" id="ev-view-title">
              {event.title}
            </h2>
          </div>
        </div>

        <EventDetails event={event} place={place} host={view.host} />

        {event.desc ? <Markdown className="small" text={event.desc} community={event.c} /> : null}

        <InterestedList event={event} me={view.me} names={view.names} />

        <EventRecordings event={event} />

        <DialogFooter>
          {phase === 'live' || (place.external && !event.cancelled && phase === 'soon') ? (
            <JoinButton place={place} />
          ) : null}

          {active ? (
            <Button
              className={cn('interest-btn', view.interested && 'is-on')}
              onClick={() => actions.toggleInterest(event, view.interested)}
              aria-pressed={view.interested}
            >
              <Icon name="star" />
              <span>{view.interested ? 'Interested' : 'I am interested'}</span>
            </Button>
          ) : null}

          {active ? (
            <a
              className="btn"
              href={eventIcs(event, view.community, origin)}
              download={eventFile(event)}
            >
              <Icon name="calendar" />
              Add to calendar
            </a>
          ) : null}

          {shareable ? (
            <ShareButton
              id="event-share"
              cid={event.c}
              path={routes.event(event.c, event.id, event.title)}
              title={event.title}
              text={event.desc ? plainText(event.desc).slice(0, 160) || null : null}
              label="Share event"
              labelled
            />
          ) : (
            <Button onClick={() => actions.copyLink(event)}>
              <Icon name="link" />
              Copy link
            </Button>
          )}
        </DialogFooter>
      </DialogBody>
    </Dialog>
  );
}

function EventRecordings({ event }: { readonly event: CommunityEvent }) {
  const gateway = useGateway();

  const rows = useAppState((state) =>
    Object.values(state.recordings)
      .filter((r) => r.eventId === event.id)
      .reverse()
      .map((r) => toRow(r)),
  );

  const started = ['live', 'past'].includes(evState(event));

  useEffect(() => {
    if (started) gateway.events.loadRecordings(event.id);
  }, [gateway, event.id, started]);

  return <RecordingList id="event-recordings" label="Recordings" cid={event.c} rows={rows} />;
}

function EventDetails({
  event,
  place,
  host,
}: {
  readonly event: CommunityEvent;
  readonly place: ReturnType<typeof evWhere>;
  readonly host: string;
}) {
  const repeat = evRepeatLabel(event);
  const zone = useDisplayZone();

  return (
    <div className="grid gap-2 small">
      <Row icon="clock">
        <span>{evWhen(event, zone)}</span> <span className="subtle">{evZone(zone)}</span>
      </Row>

      {repeat ? (
        <Row icon="repeat">
          <span>{repeat}</span>
        </Row>
      ) : null}

      {place.external ? (
        <a className="icon-text event-where" href={place.href} target="_blank" rel="noopener">
          <PlaceBody icon={place.icon} label={place.label} sub={place.sub} />
        </a>
      ) : (
        <Link className="icon-text event-where" to={place.href}>
          <PlaceBody icon={place.icon} label={place.label} sub={place.sub} />
        </Link>
      )}

      <span className="icon-text">
        <PersonAvatar id={event.host} size="xs" />
        <span>Hosted by {host}</span>
      </span>
    </div>
  );
}

const INTERESTED_SHOWN = 10;

function InterestedList({
  event,
  me,
  names,
}: {
  readonly event: CommunityEvent;
  readonly me: string | null;
  readonly names: Readonly<Record<string, string>>;
}) {
  const total = event.interested.length;

  return (
    <div className="grid gap-2">
      <Label>{total} interested</Label>

      {total ? (
        <div className="flex gap-2 flex-wrap">
          {event.interested.slice(0, INTERESTED_SHOWN).map((id) => (
            <PersonChip key={id} id={id} name={id === me ? 'You' : (names[id] ?? null)} />
          ))}
          {total > INTERESTED_SHOWN ? (
            <span className="x-small subtle">and {total - INTERESTED_SHOWN} more</span>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function Row({ icon, children }: { readonly icon: IconName; readonly children: ReactNode }) {
  return (
    <span className="icon-text">
      <Icon name={icon} />
      <span>{children}</span>
    </span>
  );
}

function PlaceBody({
  icon,
  label,
  sub,
}: {
  readonly icon: string;
  readonly label: string;
  readonly sub: string;
}) {
  return (
    <>
      <PlaceIcon name={icon} />
      <span>
        <span>{label}</span> <span className="subtle">{sub}</span>
      </span>
    </>
  );
}

function PersonChip({ id, name }: { readonly id: string; readonly name: string | null }) {
  const username = useAppState((state) => state.people[id]?.username ?? id);

  return (
    <Link className="person-chip" to={routes.profile(username)}>
      <PersonAvatar id={id} size="xs" />
      <span>{name}</span>
    </Link>
  );
}
