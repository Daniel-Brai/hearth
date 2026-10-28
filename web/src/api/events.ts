import type { EventSpec } from '@/data/gateway';
import type { CommunityEvent, EventWhere } from '@/domain/types';
import type { CommunityEvent as ApiEvent, ScheduleEventBody } from '@/generated/schemas';

type RoomOf = (id: string) => { slug: string; type: 'text' | 'voice' } | undefined;

function whereOf(event: ApiEvent, roomOf: RoomOf): EventWhere {
  const room = event.room_id === null ? undefined : roomOf(event.room_id);

  if (room?.type === 'voice') return { type: 'voice', room: room.slug };
  if (room) return { type: 'chat', room: room.slug };

  return { type: 'link', url: event.url ?? '' };
}

export function toEvent(event: ApiEvent, cid: string, roomOf: RoomOf): CommunityEvent {
  return {
    id: event.id,
    c: cid,
    title: event.title,
    start: event.next_starts_at ?? event.starts_at,
    mins: event.duration_min,
    repeat: event.repeat,
    where: whereOf(event, roomOf),
    ...(event.talk_mode ? { talk: event.talk_mode } : {}),
    host: event.host_id,
    interested: event.interested_ids,
    cancelled: event.cancelled_at !== null,
    desc: event.description,
  };
}

// The browser's time zone so repeats keep the time the host picked
export function toEventBody(spec: EventSpec, roomId: string | null): ScheduleEventBody {
  const place = spec.where.type === 'link' ? 'link' : 'room';

  return {
    title: spec.title,
    description: spec.desc || null,
    starts_at: spec.start,
    duration_min: spec.mins,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    repeat: spec.repeat,
    place,
    room_id: place === 'room' ? roomId : null,
    url: spec.where.type === 'link' ? spec.where.url : null,
    talk_mode: spec.where.type === 'voice' ? (spec.talk ?? 'open') : null,
  };
}
