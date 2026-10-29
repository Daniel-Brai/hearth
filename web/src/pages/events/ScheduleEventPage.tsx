import { type FormEvent, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { Button, ButtonLink, Field, Icon, Input, Measure, Panel, Textarea } from '@/design-system';
import { useGateway } from '@/app/gateway-context';
import { useAppState } from '@/data/store';
import { useLoad } from '@/data/use-load';
import { canDo, canManageEvent, community } from '@/domain/selectors';
import type { CommunityEvent } from '@/domain/types';
import { idFromSegment, routes } from '@/runtime/routes';
import { PageHeader } from '@/shell/PageHeader';
import { LeaveDialog } from '@/pages/compose/LeaveDialog';
import { useLeaveGuard } from '@/pages/compose/use-leave-guard';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { TalkField, WhenFields, WhereFields } from './ScheduleFields';
import { useScheduleForm } from './use-schedule-form';
import './EventsPage.css';
import './ScheduleEventPage.css';

export function ScheduleEventPage() {
  const { community: cid, event: segment } = useParams();
  const gateway = useGateway();
  const eventId = idFromSegment(segment);

  const load = useLoad(
    () => (cid ? gateway.load.events(cid) : Promise.resolve({ ok: true, value: undefined })),
    `events:${cid ?? 'none'}`,
  );

  const exists = useAppState((state) => !!cid && !!community(state, cid));

  const event = useAppState((state) =>
    eventId ? (state.events.find((e) => e.id === eventId && e.c === cid) ?? null) : null,
  );

  const allowed = useAppState((state) =>
    eventId ? canManageEvent(state, event) : !!cid && canDo(state, cid, 'event.create'),
  );

  if (load.status === 'error') return <ErrorPage code={500} />;
  if (!cid || !exists || (eventId && !event)) return <ErrorPage code={404} />;
  if (!allowed) return <ErrorPage code={403} forbidden="events" />;

  // Keyed so opening another event starts a fresh form
  return <ScheduleEventForm key={event?.id ?? cid} cid={cid} event={event} />;
}

function ScheduleEventForm({
  cid,
  event,
}: {
  readonly cid: string;
  readonly event: CommunityEvent | null;
}) {
  const navigate = useNavigate();

  const form = useScheduleForm(cid, event);
  const { values, set, community: current, problem, summary } = form;

  const [initial] = useState(() => JSON.stringify(values));
  const guard = useLeaveGuard(JSON.stringify(values) !== initial);

  const submit = async (e: FormEvent) => {
    if (!(await form.submit(e))) return;

    guard.allowLeave();
    void navigate(routes.communityEvents(cid));
  };

  return (
    <>
      <PageHeader
        label={event ? 'edit event' : 'schedule an event'}
        eyebrow={current?.name ?? null}
        title={event ? 'Edit event' : 'Schedule an event'}
      />

      <main id="main">
        <form id="event-form" noValidate onSubmit={submit}>
          <Measure narrow className="grid gap-4 schedule-event">
            <Panel className="grid gap-4" id="event-form-when">
              <Field label="Name">
                <Input
                  id="ev-title"
                  value={values.title}
                  onChange={(e) => set.setTitle(e.target.value)}
                  maxLength={80}
                  placeholder="Office hours, release Q&A, workshop…"
                  shake={problem?.field === 'title'}
                  autoFocus
                />
              </Field>

              <WhenFields form={form} />
            </Panel>

            <Panel className="grid gap-4" id="event-form-where">
              <WhereFields form={form} />

              {form.voice ? <TalkField form={form} /> : null}
            </Panel>

            <Panel className="grid gap-4" id="event-form-about">
              <Field
                label={
                  <>
                    What happens <span className="subtle">(optional)</span>
                  </>
                }
              >
                <Textarea
                  value={values.desc}
                  onChange={(e) => set.setDesc(e.target.value)}
                  maxLength={2000}
                  style={{ minBlockSize: '5lh' }}
                  placeholder="Agenda, what to read first, who it is for. Formatting works."
                />
              </Field>

              {summary ? (
                <p className="summary small">
                  <span className="label">
                    <Icon name="calendar" />
                    When
                  </span>
                  <span>{summary}</span>
                </p>
              ) : null}

              {!event ? (
                <label className="icon-text small">
                  <input
                    type="checkbox"
                    className="size-[1.05rem] accent-[var(--color-link)]"
                    checked={values.notify}
                    onChange={(e) => set.setNotify(e.target.checked)}
                  />
                  Tell members in their notifications
                </label>
              ) : null}
            </Panel>

            {problem ? (
              <p className="field__error m-0" role="alert">
                {problem.text}
              </p>
            ) : null}

            <div className="schedule-event__bar">
              <ButtonLink to={routes.communityEvents(cid)}>Cancel</ButtonLink>
              <Button type="submit" variant="reversed">
                {event ? 'Save changes' : 'Schedule event'}
              </Button>
            </div>
          </Measure>
        </form>
      </main>

      <LeaveDialog
        blocker={guard.blocker}
        title="Leave without saving?"
        text="Your changes to this event haven't been saved."
        stay="Keep editing"
        leave="Discard changes"
      />
    </>
  );
}
