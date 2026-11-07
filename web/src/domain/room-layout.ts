import type { Community, Room, RoomGroup, VoiceRoom } from './types';

export type LaidOutRoom =
  | { readonly kind: 'text'; readonly room: Room }
  | { readonly kind: 'voice'; readonly room: VoiceRoom };

export type RoomSection = { readonly group: RoomGroup | null; readonly rooms: LaidOutRoom[] };

export function roomSections(
  community: Pick<Community, 'rooms' | 'voice' | 'groups'>,
  withVoice: boolean,
): RoomSection[] {
  const known = new Set(community.groups.map((g) => g.id));

  const all: LaidOutRoom[] = [
    ...community.rooms.map((room) => ({ kind: 'text' as const, room })),
    ...(withVoice ? community.voice.map((room) => ({ kind: 'voice' as const, room })) : []),
  ].sort((a, b) => (a.room.position ?? 0) - (b.room.position ?? 0));

  const groupOf = (r: LaidOutRoom) =>
    r.room.group && known.has(r.room.group) ? r.room.group : null;

  return [
    { group: null, rooms: all.filter((r) => groupOf(r) === null) },
    ...community.groups.map((group) => ({
      group,
      rooms: all.filter((r) => groupOf(r) === group.id),
    })),
  ];
}

export type RoomLayout = {
  readonly groups: { readonly id: string; readonly rooms: string[] }[];
  readonly rooms: string[];
};

/** Room slugs are unique in a community across text and voice */
export const layoutOf = (sections: readonly RoomSection[]): RoomLayout => ({
  rooms: sections.find((s) => s.group === null)?.rooms.map((r) => r.room.id) ?? [],
  groups: sections.flatMap((s) =>
    s.group ? [{ id: s.group.id, rooms: s.rooms.map((r) => r.room.id) }] : [],
  ),
});

export function applyLayout(
  community: Pick<Community, 'rooms' | 'voice' | 'groups'>,
  layout: RoomLayout,
) {
  const places = new Map<string, { group: string | null; position: number }>();

  layout.rooms.forEach((id, position) => places.set(id, { group: null, position }));
  layout.groups.forEach((g) =>
    g.rooms.forEach((id, position) => places.set(id, { group: g.id, position })),
  );

  for (const room of [...community.rooms, ...community.voice]) {
    const place = places.get(room.id);

    if (place) {
      room.group = place.group;
      room.position = place.position;
    }
  }

  const order = new Map(layout.groups.map((g, i) => [g.id, i]));

  community.groups.sort((a, b) => (order.get(a.id) ?? 0) - (order.get(b.id) ?? 0));
}

export const nextPlace = (
  community: Pick<Community, 'rooms' | 'voice'>,
  group: string | null,
): number =>
  Math.max(
    -1,
    ...[...community.rooms, ...community.voice]
      .filter((r) => (r.group ?? null) === group)
      .map((r, i) => r.position ?? i),
  ) + 1;

type Slot = { group: string | null; rooms: string[] };

const slotsOf = (layout: RoomLayout): Slot[] => [
  { group: null, rooms: [...layout.rooms] },
  ...layout.groups.map((g) => ({ group: g.id, rooms: [...g.rooms] })),
];

const layoutFrom = (slots: readonly Slot[]): RoomLayout => ({
  rooms: slots[0]?.rooms ?? [],
  groups: slots.flatMap((s) => (s.group ? [{ id: s.group, rooms: s.rooms }] : [])),
});

const without = (slots: Slot[], id: string) =>
  slots.map((s) => ({ ...s, rooms: s.rooms.filter((r) => r !== id) }));

export function moveRoom(
  layout: RoomLayout,
  id: string,
  to: { readonly group: string | null; readonly before: string | null },
): RoomLayout {
  const slots = without(slotsOf(layout), id);
  const target = slots.find((s) => s.group === to.group);

  if (!target) return layout;

  const at = to.before ? target.rooms.indexOf(to.before) : -1;

  target.rooms.splice(at < 0 ? target.rooms.length : at, 0, id);

  return layoutFrom(slots);
}

export function shiftRoom(layout: RoomLayout, id: string, by: -1 | 1): RoomLayout {
  const slots = slotsOf(layout);
  const from = slots.findIndex((s) => s.rooms.includes(id));
  const slot = slots[from];

  if (!slot) return layout;

  const at = slot.rooms.indexOf(id);
  const next = at + by;

  if (next >= 0 && next < slot.rooms.length) {
    slot.rooms.splice(at, 1);
    slot.rooms.splice(next, 0, id);
    return layoutFrom(slots);
  }

  const into = slots[from + by];

  if (!into) return layout;

  slot.rooms.splice(at, 1);

  if (by < 0) into.rooms.push(id);
  else into.rooms.unshift(id);

  return layoutFrom(slots);
}

export function shiftGroup(layout: RoomLayout, id: string, by: -1 | 1): RoomLayout {
  const groups = [...layout.groups];
  const at = groups.findIndex((g) => g.id === id);
  const next = at + by;

  if (at < 0 || next < 0 || next >= groups.length) return layout;

  const [moved] = groups.splice(at, 1);
  if (moved) groups.splice(next, 0, moved);

  return { ...layout, groups };
}
