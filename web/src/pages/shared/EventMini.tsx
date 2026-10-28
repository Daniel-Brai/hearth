import { useDisplayZone } from '@/app/request-context';
import { Button, ButtonLink, cn, ExternalButtonLink, Icon, Link } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { evDay, evRel, evState, evWhere } from '@/domain/events';
import { isInterested } from '@/domain/selectors';
import type { CommunityEvent } from '@/domain/types';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';

export function EventDate({ event }: { readonly event: CommunityEvent }) {
  const phase = evState(event);
  const day = evDay(event, useDisplayZone());

  return (
    <span className={cn('event-date', phase === 'live' && 'is-live', event.cancelled && 'is-off')}>
      <span className="event-date__mon">{phase === 'live' ? 'Live' : day.mon}</span>
      <span className="event-date__day">{day.day}</span>
    </span>
  );
}

export function EventMini({
  event,
  showCommunity,
}: {
  readonly event: CommunityEvent;
  readonly showCommunity?: boolean;
}) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);

  const view = useAppState((state) => ({
    interested: isInterested(state, event),
    where: evWhere(event, state.communities[event.c]),
    community: state.communities[event.c]?.name ?? null,
  }));

  const phase = evState(event);

  const zone = useDisplayZone();

  const toggle = () => {
    gateway.events.toggleInterest(event.id);

    if (view.interested) flash('Removed from your events');
    else if (phase === 'live') flash('Marked as interested');
    else
      flash("Interested. We'll remind you an hour before it starts, and again 10 minutes before.");
  };

  return (
    <div className={cn('event-mini', event.cancelled && 'is-off')}>
      <EventDate event={event} />

      <Link className="event-mini__main" to={routes.event(event.c, event.id, event.title)}>
        <strong className="truncate">{event.title}</strong>
        <span className="x-small subtle truncate">
          <span className={phase === 'live' ? 'event-live-text' : undefined}>
            {evRel(event, zone)}
          </span>
          <span> · {view.where.label}</span>
          {showCommunity && view.community ? <span> · {view.community}</span> : null}
        </span>
      </Link>

      {phase === 'live' && view.where.external ? (
        <ExternalButtonLink size="tiny" variant="reversed" href={view.where.href} target="_blank">
          Join
        </ExternalButtonLink>
      ) : null}

      {phase === 'live' && !view.where.external ? (
        <ButtonLink size="tiny" variant="reversed" to={view.where.href}>
          Join
        </ButtonLink>
      ) : null}

      {phase !== 'live' && !event.cancelled ? (
        <Button
          size="tiny"
          className={cn('interest-btn', view.interested && 'is-on')}
          onClick={toggle}
          aria-pressed={view.interested}
          data-tip={view.interested ? 'You will get a reminder' : 'Get a reminder'}
        >
          <Icon name="star" />
          <span>{event.interested.length}</span>
        </Button>
      ) : null}
    </div>
  );
}
