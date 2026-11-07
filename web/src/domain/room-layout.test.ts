import { describe, expect, it } from 'vitest';

import {
  applyLayout,
  layoutOf,
  moveRoom,
  roomSections,
  shiftGroup,
  shiftRoom,
} from './room-layout';

const room = (id: string, position: number, group: string | null = null) => ({
  id,
  name: id,
  unread: 0,
  group,
  position,
});

const voice = (id: string, position: number, group: string | null = null) => ({
  id,
  name: id,
  live: false,
  listeners: 0,
  topic: null,
  host: '',
  postId: null,
  group,
  position,
});

const community = {
  rooms: [room('general', 0), room('help', 1, 'g1'), room('faq', 0, 'g1')],
  voice: [voice('hangout', 1)],
  groups: [{ id: 'g1', name: 'Getting started' }],
};

describe('roomSections', () => {
  it('leaves voice rooms out when voice is off', () => {
    const [loose] = roomSections(community, false);

    expect(loose?.rooms.map((r) => r.room.id)).toEqual(['general']);
  });

  it('puts rooms in no group first', () => {
    expect(roomSections(community, true).map((s) => s.group?.id ?? null)).toEqual([null, 'g1']);
  });

  it('mixes text and voice rooms in order', () => {
    const [loose] = roomSections(community, true);

    expect(loose?.rooms.map((r) => r.room.id)).toEqual(['general', 'hangout']);
  });

  it('keeps a room of an unknown group with the rest', () => {
    const lost = { ...community, rooms: [room('lost', 0, 'gone')] };
    const [loose] = roomSections(lost, false);

    expect(loose?.rooms.map((r) => r.room.id)).toEqual(['lost']);
  });
});

describe('layoutOf', () => {
  it('lists each group with its rooms in order', () => {
    expect(layoutOf(roomSections(community, true))).toEqual({
      rooms: ['general', 'hangout'],
      groups: [{ id: 'g1', rooms: ['faq', 'help'] }],
    });
  });
});

describe('applyLayout', () => {
  it('moves a room into a group', () => {
    const changed = structuredClone(community);

    applyLayout(changed, { rooms: ['hangout'], groups: [{ id: 'g1', rooms: ['general'] }] });

    expect(changed.rooms[0]?.group).toBe('g1');
  });
});

const layout = {
  rooms: ['general', 'hangout'],
  groups: [
    { id: 'g1', rooms: ['faq', 'help'] },
    { id: 'g2', rooms: [] },
  ],
};

describe('moveRoom', () => {
  it('leaves the layout alone for an unknown group', () => {
    expect(moveRoom(layout, 'general', { group: 'gone', before: null })).toBe(layout);
  });

  it('puts a room before another', () => {
    expect(moveRoom(layout, 'general', { group: 'g1', before: 'help' }).groups[0]?.rooms).toEqual([
      'faq',
      'general',
      'help',
    ]);
  });

  it('puts a room last in an empty group', () => {
    expect(moveRoom(layout, 'faq', { group: 'g2', before: null }).groups[1]?.rooms).toEqual([
      'faq',
    ]);
  });
});

describe('shiftRoom', () => {
  it('stays put at the very top', () => {
    expect(shiftRoom(layout, 'general', -1)).toBe(layout);
  });

  it('swaps with its neighbour', () => {
    expect(shiftRoom(layout, 'general', 1).rooms).toEqual(['hangout', 'general']);
  });

  it('crosses into the next group from the bottom', () => {
    expect(shiftRoom(layout, 'hangout', 1).groups[0]?.rooms).toEqual(['hangout', 'faq', 'help']);
  });
});

describe('shiftGroup', () => {
  it('stays put at the end', () => {
    expect(shiftGroup(layout, 'g2', 1)).toBe(layout);
  });

  it('moves a group up', () => {
    expect(shiftGroup(layout, 'g2', -1).groups.map((g) => g.id)).toEqual(['g2', 'g1']);
  });
});
