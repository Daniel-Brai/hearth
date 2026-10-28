import { describe, expect, it, vi } from 'vitest';
import type { EventSpec } from '@/data/gateway';
import { at, community, gateway, routes, sent, session } from './test-support';

const event = {
  id: 'ev1',
  community_id: 'c1',
  host_id: 'u1',
  room_id: 'r1',
  title: 'Office hours',
  description: null,
  starts_at: at,
  next_starts_at: at,
  duration_min: 60,
  timezone: 'Africa/Lagos',
  repeat: 'weekly',
  place: 'room',
  url: null,
  talk_mode: null,
  cancelled_at: null,
  interested_ids: ['u1'],
};

const signedIn = async () => {
  routes['POST /api/auth/sessions'] = { status: 200, body: session };
  routes['GET /api/communities'] = { status: 200, body: [community] };

  const { gateway: g, store } = gateway();

  await g.session.verifyCode('ada@example.com', '123456');

  return { g, store };
};

describe('events', () => {
  it('shows each event in its room, at its next time', async () => {
    routes['GET /api/events'] = { status: 200, body: [event] };

    const { g, store } = await signedIn();

    await g.load.events(null);

    expect(store.get().events).toEqual([
      expect.objectContaining({
        id: 'ev1',
        c: 'gardeners',
        where: { type: 'chat', room: 'general' },
        interested: ['u1'],
        cancelled: false,
      }),
    ]);
  });

  it('schedules in the room picked, by its server id', async () => {
    routes['POST /api/communities/c1/events'] = { status: 201, body: event };

    const { g } = await signedIn();

    await g.load.events(null);

    const spec: EventSpec = {
      title: 'Office hours',
      desc: '',
      start: at,
      mins: 60,
      repeat: 'weekly',
      where: { type: 'chat', room: 'general' },
    };

    expect((await g.events.save('gardeners', null, spec)).ok).toBe(true);

    expect(sent.find((r) => r.method === 'POST' && r.path.endsWith('/events'))?.body).toMatchObject(
      {
        place: 'room',
        room_id: 'r1',
        description: null,
        talk_mode: null,
      },
    );
  });

  it('shows why scheduling was refused', async () => {
    routes['POST /api/communities/c1/events'] = { status: 403, body: { message: 'Forbidden' } };

    const { g } = await signedIn();

    await g.load.events(null);

    const spec: EventSpec = {
      title: 'Office hours',
      desc: '',
      start: at,
      mins: 60,
      repeat: 'none',
      where: { type: 'link', url: 'https://meet.example.com' },
    };

    expect(await g.events.save('gardeners', null, spec)).toEqual({ ok: false, error: 'Forbidden' });
  });
});

describe('events.loadRecordings', () => {
  it('keeps the recordings of the event under its title', async () => {
    routes['GET /api/events'] = { status: 200, body: [event] };

    routes['GET /api/events/ev1/recordings'] = {
      status: 200,
      body: {
        data: [
          {
            id: 'rec1',
            session_id: 's1',
            room_id: 'r1',
            community_id: 'c1',
            started_by_id: 'u1',
            status: 'ready',
            failure: null,
            started_at: at,
            ended_at: at,
            duration_ms: 65_000,
            byte_size: 1000,
            width: 1280,
            height: 720,
            has_screen: false,
            video_url: 'https://files.example.test/video.mp4',
            poster_url: null,
            speakers: [],
          },
        ],
      },
    };

    const { g, store } = await signedIn();

    await g.load.events(null);

    g.events.loadRecordings('ev1');
    await vi.waitFor(() => expect(store.get().recordings['rec1']).toBeDefined());

    expect(store.get().recordings['rec1']).toMatchObject({
      eventId: 'ev1',
      title: 'Office hours',
      duration: '1:05',
    });
  });
});
