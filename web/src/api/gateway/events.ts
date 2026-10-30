import type { HearthGateway, Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import type { CommunityEvent as ApiEvent } from '@/generated/schemas';
import { communityIndex } from '@/generated/api/communities/communities';
import {
  eventCancel,
  eventCreate,
  eventDelete,
  eventIndex,
  eventInterest,
  eventUpdate,
} from '@/generated/api/events/events';
import { recordingEventIndex } from '@/generated/api/voice/voice';
import { toEvent, toEventBody } from '../events';
import { toRecording } from '../mappers';
import { accessToken } from '../session-token';
import type { GatewayContext } from './context';
import { call, failed } from './context';

export function createEventsGateway(
  ctx: GatewayContext,
  loadCommunity: (cid: string) => Promise<Result>,
) {
  const remember = (events: readonly ApiEvent[]) => {
    const mapped = events.flatMap((event) => {
      const cid = ctx.communitySlugs.get(event.community_id);
      return cid ? [toEvent(event, cid, (id) => ctx.roomsById.get(id))] : [];
    });

    ctx.store.set((state) => {
      for (const event of mapped) {
        const index = state.events.findIndex((e) => e.id === event.id);
        if (index >= 0) state.events[index] = event;
        else state.events.push(event);
      }
    });

    return mapped;
  };

  // Someone else scheduling, moving or cancelling an event shows without a reload
  const follow = (communityId: string) =>
    ctx.watch(
      `community:${communityId}`,
      (realtime, topic) => {
        const refresh = async () => {
          const answer = await call(() => eventIndex({ community_id: communityId }));
          if (answer.status === 200) remember(answer.data);
        };

        const stops = [
          realtime.onPush(topic, 'EventScheduled', () => void refresh()),
          realtime.onPush(topic, 'EventUpdated', () => void refresh()),
          realtime.onPush(topic, 'EventCancelled', () => void refresh()),
        ];

        return () => stops.forEach((stop) => stop());
      },
      'events',
    );

  // Every community's events need its rooms known, to say where each one is
  const loadAll = async (): Promise<Result> => {
    if (!accessToken()) return ok(undefined);

    const joined = await call(() => communityIndex());

    if (joined.status !== 200) return failed(joined);
    for (const community of joined.data) ctx.rememberCommunity(community, null);

    const answer = await call(() => eventIndex());

    for (const community of joined.data) follow(community.id);

    if (answer.status !== 200) return failed(answer);

    remember(answer.data);

    return ok(undefined);
  };

  const loadOne = async (cid: string): Promise<Result> => {
    if (ctx.needsDetail(cid)) await loadCommunity(cid);

    const id = ctx.communityIds.get(cid);

    if (!id) return fail("This community isn't here.");

    const answer = await call(() => eventIndex({ community_id: id }));

    if (answer.status !== 200) return failed(answer);

    remember(answer.data);
    follow(id);

    return ok(undefined);
  };

  const load = {
    events: async (cid: string | null) => {
      await ctx.sessionLoaded;

      if (cid === null) return loadAll();

      return loadOne(cid);
    },
  } satisfies Partial<HearthGateway['load']>;

  const roomIdOf = (cid: string, room: string) => ctx.roomIds.get(`${cid}/${room}`) ?? null;

  // Shows the change at once then the server's answer replaces the event
  const setCancelled = async (id: string, cancelled: boolean) => {
    ctx.store.set((state) => {
      const event = state.events.find((e) => e.id === id);
      if (event) event.cancelled = cancelled;
    });

    const answer = await call(() => eventCancel(id, { cancelled }));
    if (answer.status === 200) remember([answer.data]);
  };

  const events: HearthGateway['events'] = {
    loadRecordings: (id) => {
      const event = ctx.store.get().events.find((e) => e.id === id);
      if (!event || !accessToken()) return;

      void call(() => recordingEventIndex(id)).then((answer) => {
        if (answer.status !== 200) return;

        ctx.store.set((state) => {
          for (const [key, r] of Object.entries(state.recordings))
            if (r.eventId === id) delete state.recordings[key];
          for (const r of answer.data.data) {
            const rid = ctx.roomsById.get(r.room_id)?.slug ?? '';
            const room = state.communities[event.c]?.voice.find((v) => v.id === rid)?.name ?? '';
            state.recordings[r.id] = {
              ...toRecording(r, event.c, rid, room, { eventId: id }),
              title: event.title,
            };
          }
        });
      });
    },

    save: async (cid, id, spec) => {
      const room = spec.where.type === 'link' ? null : roomIdOf(cid, spec.where.room);
      const body = toEventBody(spec, room);

      if (id) {
        const answer = await call(() => eventUpdate(id, body));

        if (answer.status !== 200) return failed(answer);

        const [event] = remember([answer.data]);

        return event ? ok({ event }) : fail("This community isn't here.");
      }

      const communityId = ctx.communityIds.get(cid);

      if (!communityId) return fail("This community isn't here.");

      const answer = await call(() =>
        eventCreate(communityId, { ...body, notify: spec.notify ?? false }),
      );

      if (answer.status !== 201) return failed(answer);

      const [event] = remember([answer.data]);

      return event ? ok({ event }) : fail("This community isn't here.");
    },

    toggleInterest: (id) => {
      const me = ctx.store.get().me;

      ctx.store.set((state) => {
        const event = state.events.find((e) => e.id === id);
        if (!event || !me) return;
        event.interested = event.interested.includes(me)
          ? event.interested.filter((who) => who !== me)
          : [...event.interested, me];
      });

      void call(() => eventInterest(id));
    },

    cancel: (id) => void setCancelled(id, true),
    restore: (id) => void setCancelled(id, false),

    remove: (id) => {
      ctx.store.set((state) => (state.events = state.events.filter((e) => e.id !== id)));
      void call(() => eventDelete(id));
    },
  };

  return { load, events };
}
