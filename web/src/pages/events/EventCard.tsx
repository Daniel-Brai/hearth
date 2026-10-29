import { useDisplayZone, useOrigin } from '@/app/request-context';
import { Button, Icon, Menu, MenuItem, Pill, cn, useMenu } from '@/design-system';
import { useAppState } from '@/data/store';
import { evRepeatLabel, evState, evWhen, evWhere } from '@/domain/events';
import { canManageEvent, displayName, isInterested } from '@/domain/selectors';
import type { Community, CommunityEvent } from '@/domain/types';
import { EventDate } from '@/pages/shared/EventMini';
import { PersonAvatar } from '@/shell/people';
import { useViewer } from '@/shell/use-guest';
import { EventManageItems } from './EventManageItems';
import { JoinButton, PlaceLink } from './Place';
import { eventFile, eventIcs, interestedText, voiceModeInfo } from './event-utils';
import { useEventActions } from './use-event-actions';

export type EventCardProps = {
  readonly event: CommunityEvent;
  readonly showCommunity?: boolean | undefined;
  readonly onOpen: (e: CommunityEvent) => void;
  readonly onEdit: (e: CommunityEvent) => void;
};

type EventCardView = {
  readonly interested: boolean;
  readonly manage: boolean;
  readonly host: string;
  readonly place: ReturnType<typeof evWhere>;
  readonly community: Community | undefined;
  readonly communityName: string | null;
};

function useEventCardView(event: CommunityEvent): EventCardView {
  return useAppState(
    (state) => ({
      interested: isInterested(state, event),
      manage: canManageEvent(state, event),
      host: displayName(state, event.host),
      place: evWhere(event, state.communities[event.c]),
      community: state.communities[event.c],
      communityName: state.communities[event.c]?.name ?? null,
    }),
    () => false,
  );
}

export function EventCard({ event, showCommunity, onOpen, onEdit }: EventCardProps) {
  const view = useEventCardView(event);
  const phase = evState(event);

  return (
    <article
      className={cn('event-card', event.cancelled && 'is-off', phase === 'live' && 'is-live')}
    >
      <EventDate event={event} />

      <div className="event-card__main">
        <EventCardPills
          event={event}
          phase={phase}
          communityName={showCommunity ? view.communityName : null}
        />

        <button type="button" className="event-card__title" onClick={() => onOpen(event)}>
          {event.title}
        </button>

        <EventCardMeta event={event} place={view.place} />
        <EventCardPeople event={event} host={view.host} />
      </div>

      <EventCardActions event={event} phase={phase} view={view} onOpen={onOpen} onEdit={onEdit} />
    </article>
  );
}

function EventCardPills({
  event,
  phase,
  communityName,
}: {
  readonly event: CommunityEvent;
  readonly phase: ReturnType<typeof evState>;
  readonly communityName: string | null;
}) {
  const repeat = evRepeatLabel(event);

  return (
    <div className="flex items-center gap-2 flex-wrap min-w-0">
      {phase === 'live' ? <Pill live>Live now</Pill> : null}
      {event.cancelled ? <Pill>Cancelled</Pill> : null}
      {repeat ? (
        <Pill>
          <Icon name="repeat" />
          <span>{repeat}</span>
        </Pill>
      ) : null}
      {communityName ? (
        <Pill title={communityName}>
          <span className="truncate">{communityName}</span>
        </Pill>
      ) : null}
    </div>
  );
}

function EventCardMeta({
  event,
  place,
}: {
  readonly event: CommunityEvent;
  readonly place: EventCardView['place'];
}) {
  const mode = voiceModeInfo(event.talk);
  const zone = useDisplayZone();

  return (
    <div className="event-card__meta small subtle">
      <span className="icon-text">
        <Icon name="clock" />
        <span>{evWhen(event, zone)}</span>
      </span>

      <PlaceLink place={place} />

      {event.where.type === 'voice' ? (
        <span className="icon-text subtle" data-tip={mode.text}>
          <Icon name={mode.icon} />
          <span>{event.talk === 'open' ? 'Anyone can talk' : 'Raise a hand to talk'}</span>
        </span>
      ) : null}
    </div>
  );
}

function EventCardPeople({
  event,
  host,
}: {
  readonly event: CommunityEvent;
  readonly host: string;
}) {
  return (
    <div className="event-card__people x-small subtle">
      {event.interested.length ? (
        <span className="avatar-stack">
          {event.interested.slice(0, 4).map((id) => (
            <PersonAvatar key={id} id={id} size="xs" />
          ))}
        </span>
      ) : null}
      <span>{interestedText(event)}</span>
      <span>· Hosted by {host}</span>
    </div>
  );
}

function EventCardActions({
  event,
  phase,
  view,
  onOpen,
  onEdit,
}: {
  readonly event: CommunityEvent;
  readonly phase: ReturnType<typeof evState>;
  readonly view: EventCardView;
  readonly onOpen: (e: CommunityEvent) => void;
  readonly onEdit: (e: CommunityEvent) => void;
}) {
  const actions = useEventActions();
  const origin = useOrigin();
  const viewer = useViewer();
  const active = !event.cancelled && phase !== 'past';

  return (
    <div className="event-card__actions">
      {phase === 'live' ? <JoinButton place={view.place} small /> : null}

      {active && viewer === 'unknown' ? (
        <span className="skel skel--btn" aria-hidden="true" />
      ) : null}

      {active && viewer !== 'unknown' ? (
        <Button
          size="small"
          className={cn('interest-btn', view.interested && 'is-on')}
          onClick={() => actions.toggleInterest(event, view.interested)}
          aria-pressed={view.interested}
        >
          <Icon name="star" />
          <span>{view.interested ? 'Interested' : 'Mark interested'}</span>
        </Button>
      ) : null}

      <Menu
        left
        trigger={({ open, toggle, id }) => (
          <Button
            circle
            size="small"
            variant="borderless"
            onClick={toggle}
            aria-expanded={open}
            aria-controls={id}
            aria-label="Event options"
          >
            <Icon name="dots" />
          </Button>
        )}
      >
        <MenuItem icon="eye" onSelect={() => onOpen(event)}>
          View details
        </MenuItem>
        <MenuItem icon="link" onSelect={() => actions.copyLink(event)}>
          Copy link
        </MenuItem>
        {active ? (
          <CalendarItem event={event} href={eventIcs(event, view.community, origin)} />
        ) : null}
        {view.manage ? (
          <EventManageItems event={event} active={active} actions={actions} onEdit={onEdit} />
        ) : null}
      </Menu>
    </div>
  );
}

function CalendarItem({ event, href }: { readonly event: CommunityEvent; readonly href: string }) {
  const menu = useMenu();

  return (
    <a
      className="popup__item"
      href={href}
      download={eventFile(event)}
      onClick={() => menu?.close()}
    >
      <Icon name="calendar" />
      Add to calendar
    </a>
  );
}
