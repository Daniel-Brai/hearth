import { ButtonLink, Icon, Label, Link } from '@/design-system';
import type { CommunityEvent } from '@/domain/types';
import { routes } from '@/runtime/routes';
import { EventMini } from '@/pages/shared/EventMini';

export function CommunityEventsStrip({
  cid,
  events,
  canSchedule,
}: {
  readonly cid: string;
  readonly events: readonly CommunityEvent[];
  readonly canSchedule: boolean;
}) {
  return (
    <section className="events-strip">
      <div className="flex items-center justify-between gap-2">
        <Label className="icon-text">
          <Icon name="calendar" />
          Coming up
        </Label>
        <ButtonLink to={routes.communityEvents(cid)} size="tiny" variant="borderless">
          All events
          <Icon name="chevron" style={{ rotate: '-90deg' }} />
        </ButtonLink>
      </div>
      <div className="events-strip__list">
        {events.map((e) => (
          <EventMini key={e.id} event={e} />
        ))}
        {!events.length && canSchedule ? (
          <Link className="event-mini event-mini--add" to={routes.communityEvents(cid) + '?new=1'}>
            <span className="event-date event-date--add">
              <Icon name="plus" />
            </span>
            <span className="event-mini__main">
              <strong>Schedule the first event</strong>
              <span className="x-small subtle">Office hours, a release Q&amp;A, a workshop</span>
            </span>
          </Link>
        ) : null}
      </div>
    </section>
  );
}
