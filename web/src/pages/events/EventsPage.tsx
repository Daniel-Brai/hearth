import { useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { EmptyState, Label, Measure } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { canDo, community, joinedCids, pastEvents, upcomingEvents } from '@/domain/selectors';
import type { CommunityEvent } from '@/domain/types';
import { idFromSegment, routes } from '@/runtime/routes';
import { eventGraph, eventsGraph, indexable, useStructuredData } from '@/app/structured-data';
import { plainText } from '@/features/markdown/plain-text';
import { PageHeader } from '@/shell/PageHeader';
import { shareImage } from '@/app/share-image';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { EventCard } from './EventCard';
import { EventDialog } from './EventDialog';
import { EventsToolbar, type EventsTab } from './EventsToolbar';
import { alwaysChanged, groupEvents, snapshot } from './event-utils';
import { GateScreen } from '@/shell/GuestWall';
import { useGate } from '@/shell/use-guest';
import './EventsPage.css';

export function EventsPage() {
  const { community: param, event: eventSegment } = useParams();
  const cid = param ?? null;
  const routeEvent = idFromSegment(eventSegment);

  const gateway = useGateway();

  useLoad(() => gateway.load.events(cid), 'events:' + (cid ?? 'all'));

  const name = useAppState((state) => community(state, cid)?.name ?? null);
  const exists = useAppState((state) => !cid || !!community(state, cid));
  const gate = useGate(cid);

  const eventExists = useAppState(
    (state) => !routeEvent || state.events.some((e) => e.id === routeEvent),
  );

  const eyebrow = cid ? name : 'Your communities';

  if (!exists || !eventExists) return <ErrorPage code={404} />;
  if (gate !== 'open') return <GateScreen gate={gate} />;

  return <EventsView cid={cid} routeEvent={routeEvent} eyebrow={eyebrow} />;
}

function useEventsMeta(cid: string | null, routeEvent: string | null, eyebrow: string | null) {
  const shown = useAppState((state) => {
    const e = routeEvent ? state.events.find((x) => x.id === routeEvent) : null;
    return e ? { title: e.title, desc: e.desc } : null;
  });

  const indexed = useAppState((state) => !!cid && indexable(state, cid));

  const jsonLd = useStructuredData((state, origin) => {
    if (routeEvent) return eventGraph(state, routeEvent, origin);
    return cid ? eventsGraph(state, cid, origin) : null;
  });

  return {
    documentTitle: shown ? [shown.title, ...(eyebrow ? [eyebrow] : [])] : undefined,
    description: shown?.desc
      ? plainText(shown.desc).slice(0, 200)
      : `Upcoming events, voice rooms and meetups in ${eyebrow ?? 'your communities'}`,
    image: routeEvent ? shareImage(`/og/events/${routeEvent}`, null) : null,
    noindex: !indexed,
    jsonLd,
  };
}

function useEventsData(cid: string | null, tab: EventsTab) {
  const list = useAppState(
    (state) => (tab === 'past' ? pastEvents(state, cid) : upcomingEvents(state, cid)).map(snapshot),
    alwaysChanged,
  );

  const count = useAppState(
    (state) => upcomingEvents(state, cid).filter((e) => !e.cancelled).length,
  );

  const canSchedule = useAppState((state) => !!cid && canDo(state, cid, 'event.create'));

  const schedulable = useAppState(
    (state) =>
      joinedCids(state)
        .filter((id) => canDo(state, id, 'event.create'))
        .map((id) => ({
          id,
          name: state.communities[id]!.name,
          hue: state.communities[id]!.hue,
          letter: state.communities[id]!.letter,
          logo: state.communities[id]!.logo,
        })),
    alwaysChanged,
  );

  return { list, count, canSchedule, schedulable };
}

function emptyCopy(tab: EventsTab, canSchedule: boolean) {
  if (tab === 'past') {
    return {
      title: 'No past events yet',
      text: 'Events show up here after they end, with links to any recordings.',
    };
  }
  return {
    title: 'Nothing scheduled',
    text: canSchedule
      ? 'Office hours, release Q&As, workshops. Schedule one and members can say they are interested.'
      : 'When an admin schedules something, it shows up here and you can ask for a reminder.',
  };
}

function EventsView({
  cid,
  routeEvent,
  eyebrow,
}: {
  readonly cid: string | null;
  readonly routeEvent: string | null;
  readonly eyebrow: string | null;
}) {
  const navigate = useNavigate();

  const [tab, setTab] = useState<EventsTab>('upcoming');
  const [opened, setOpened] = useState<string | null>(null);

  const { list, count, canSchedule, schedulable } = useEventsData(cid, tab);
  const meta = useEventsMeta(cid, routeEvent, eyebrow);

  const openId = opened ?? routeEvent;
  const groups = groupEvents(list, tab === 'past');

  const closeEvent = () => {
    setOpened(null);
    if (routeEvent)
      void navigate(cid ? routes.communityEvents(cid) : routes.events, { replace: true });
  };

  const edit = (e: CommunityEvent) => void navigate(routes.eventEdit(e.c, e.id, e.title));

  const empty = emptyCopy(tab, canSchedule);

  return (
    <>
      <PageHeader label="events" eyebrow={eyebrow} title="Events" {...meta} />

      <main id="main">
        <Measure className="grid gap-4" style={{ maxInlineSize: '54rem' }}>
          <EventsToolbar
            cid={cid}
            tab={tab}
            onTab={setTab}
            count={count}
            canSchedule={canSchedule}
            schedulable={schedulable}
            onSchedule={(target) => void navigate(routes.eventNew(target))}
          />

          {!groups.length ? (
            <div className="cover">
              <EmptyState art="events" title={empty.title} text={empty.text} />
            </div>
          ) : null}

          {groups.map((g) => (
            <section key={g.label} className="grid gap-2">
              <Label>{g.label}</Label>
              <div className="grid gap-2">
                {g.items.map((e) => (
                  <EventCard
                    key={e.id}
                    event={e}
                    showCommunity={!cid}
                    onOpen={(ev) => setOpened(ev.id)}
                    onEdit={edit}
                  />
                ))}
              </div>
            </section>
          ))}
        </Measure>
      </main>

      {openId ? <EventDialog key={openId} id={openId} onClose={closeEvent} onEdit={edit} /> : null}
    </>
  );
}
