import { describe, expect, it, vi } from 'vitest';
import { getRoomSession } from '@/data/voice-session';
import { useUi } from '@/runtime/ui-store';
import { at, community, gateway, me, page, routes, sent, session } from './test-support';

type Handler = (payload: unknown) => void;

const channel = vi.hoisted(() => {
  const state = {
    handlers: new Map<string, Handler>(),
    topics: new Map<string, Handler>(),
    pushes: [] as { event: string; payload: unknown }[],
    joinReply: { status: 'ok', payload: {} as unknown },
  };
  const push = (status: string, payload: unknown) => {
    const receiver = {
      receive(s: string, cb: Handler) {
        if (s === status) cb(payload);
        return receiver;
      },
    };
    return receiver;
  };
  return {
    state,
    open: () => ({
      on: (event: string, cb: Handler) => state.handlers.set(event, cb),
      join: () => push(state.joinReply.status, state.joinReply.payload),
      push: (event: string, payload: unknown) => {
        state.pushes.push({ event, payload });
        return push('none', null);
      },
      leave: () => undefined,
    }),
  };
});

const sounds = vi.hoisted(() => ({ played: [] as string[] }));

vi.mock('@/runtime/sounds', async (original) => {
  const real = await original<typeof import('@/runtime/sounds')>();

  return {
    ...real,
    sfx: (name: Parameters<typeof real.sfx>[0]) => {
      sounds.played.push(name);
      real.sfx(name);
    },
  };
});

vi.mock('../realtime', () => ({
  getRealtime: () => ({
    onPush: (topic: string, event: string, handler: Handler) => {
      channel.state.topics.set(`${topic} ${event}`, handler);
      return () => undefined;
    },
    open: channel.open,
  }),
}));

class FakePeer {
  connectionState = 'new';
  getTransceivers = () => [];
  close = () => undefined;
  setConfiguration = () => undefined;
}

const voiceRoom = {
  id: 'v1',
  community_id: 'c1',
  type: 'voice',
  slug: 'office-hours',
  name: 'Office hours',
  topic: null,
  position: 1,
  moderation: null,
  archived_at: null,
};

const live = {
  id: 's1',
  community_id: 'c1',
  room_id: 'v1',
  host_id: 'u9',
  event_id: null,
  mode: 'stage',
  topic: 'Open floor',
  started_at: at,
  ended_at: null,
  recording: false,
};

const participant = (user_id: string, role: string) => ({
  user_id,
  role,
  self_muted: true,
  server_muted: false,
  hand_raised_at: null,
});

const joinReply = {
  ice_servers: [],
  me: { role: 'listener', server_muted: false },
  mode: 'stage',
  share: null,
  recording: null,
  hands: [],
  speaking: [],
  participants: [participant(me.id, 'listener'), participant('u9', 'host')],
};

async function joined() {
  routes['POST /api/auth/sessions'] = { status: 200, body: session };

  routes['GET /api/communities/gardeners'] = {
    status: 200,
    body: {
      community: { ...community, rooms: [...community.rooms, voiceRoom] },
      kinds: [],
      membership: null,
    },
  };

  routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
  routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };
  routes['GET /api/rooms/v1/voice-session'] = { status: 200, body: live };

  routes['GET /api/voice-sessions/s1'] = {
    status: 200,
    body: {
      session: live,
      participants: joinReply.participants,
      hands: [],
      speaking: [],
      share: null,
      recording: null,
      host_tools: false,
      may_record: false,
    },
  };

  vi.stubGlobal('RTCPeerConnection', FakePeer);
  channel.state.joinReply = { status: 'ok', payload: joinReply };
  channel.state.handlers.clear();
  channel.state.pushes.length = 0;

  const opened = gateway();

  await opened.gateway.session.verifyCode('ada@example.com', '123456');

  return opened;
}

describe('voice.loadLive', () => {
  it('shows a room that was already live at sign in, with how many are in it', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };

    routes['GET /api/communities'] = {
      status: 200,
      body: [{ ...community, rooms: [...community.rooms, voiceRoom] }],
    };

    routes['GET /api/voice-sessions/live'] = { status: 200, body: [{ ...live, people: 2 }] };

    const { store, gateway: g } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    await vi.waitFor(() =>
      expect(store.get().communities['gardeners']?.voice[0]).toMatchObject({
        live: true,
        listeners: 2,
      }),
    );
  });
});

describe('load.voice', () => {
  it('knows who is in a live room before joining it', async () => {
    const { store, gateway: g } = await joined();

    await g.load.voice('gardeners', 'office-hours');

    expect(store.get().communities['gardeners']?.voice[0]?.present).toEqual([me.id, 'u9']);
  });
});

describe('voice.end', () => {
  it('ends the room without also saying it ended, since the host already knows', async () => {
    routes['POST /api/voice-sessions/s1/end'] = { status: 204, body: undefined };

    const { gateway: g } = await joined();
    await g.voice.join('gardeners', 'office-hours', false);
    useUi.setState({ toasts: [] });

    expect((await g.voice.end('gardeners', 'office-hours')).ok).toBe(true);
    expect(useUi.getState().toasts.map((t) => t.msg)).not.toContain('The room ended.');
  });
});

describe('voice captions', () => {
  it('asks the server for captions on joining when they are on', async () => {
    const { store, gateway: g } = await joined();

    store.set((state) => {
      state.settings.captions = true;
      state.instance.transcription = true;
    });

    await g.voice.join('gardeners', 'office-hours', false);

    expect(channel.state.pushes).toContainEqual({ event: 'captions', payload: { on: true } });
  });

  it('adds what someone said to the live transcript', async () => {
    const { gateway: g } = await joined();
    await g.voice.join('gardeners', 'office-hours', false);

    channel.state.handlers.get('VoiceCaption')?.({
      session_id: 's1',
      user_id: 'u9',
      text: 'Hello',
    });

    expect(getRoomSession('gardeners/office-hours').captions).toMatchObject([
      { who: 'u9', text: 'Hello' },
    ]);
  });
});

describe('voice arrivals', () => {
  it('stays quiet for someone already in the room changing role', async () => {
    const { gateway: g } = await joined();
    await g.voice.join('gardeners', 'office-hours', false);
    sounds.played.length = 0;

    channel.state.handlers.get('VoiceParticipantChanged')?.({
      session_id: 's1',
      left: false,
      ...participant('u9', 'speaker'),
    });

    expect(sounds.played).not.toContain('arrive');
  });

  it('plays a sound for everyone in the room when someone joins', async () => {
    const { gateway: g } = await joined();
    await g.voice.join('gardeners', 'office-hours', false);
    sounds.played.length = 0;

    channel.state.handlers.get('VoiceParticipantChanged')?.({
      session_id: 's1',
      left: false,
      ...participant('u7', 'listener'),
    });

    expect(sounds.played).toEqual(['arrive']);
  });
});

describe('voice.join', () => {
  it('says plainly when the room is full', async () => {
    const { gateway: g } = await joined();
    channel.state.joinReply = { status: 'error', payload: { reason: 'full' } };

    expect(await g.voice.join('gardeners', 'office-hours', false)).toEqual({
      ok: false,
      error: 'This room is full. Try again in a bit.',
    });
  });

  it('says the room ended when nothing is live there', async () => {
    const { gateway: g } = await joined();
    routes['GET /api/rooms/v1/voice-session'] = { status: 404, body: { code: 'not_found' } };

    expect(await g.voice.join('gardeners', 'office-hours', false)).toEqual({
      ok: false,
      error: 'This room has ended.',
    });
  });

  it('puts everyone else on the stage and in the listeners, never you twice', async () => {
    const { store, gateway: g } = await joined();

    expect((await g.voice.join('gardeners', 'office-hours', false)).ok).toBe(true);

    expect(store.get().live).toMatchObject({ joined: true, role: 'listener', muted: true });

    expect(getRoomSession('gardeners/office-hours')).toMatchObject({
      speakers: ['u9'],
      listeners: [],
    });
  });

  it('keeps the room in step with what the server says', async () => {
    const { gateway: g } = await joined();

    await g.voice.join('gardeners', 'office-hours', false);

    channel.state.handlers.get('VoiceSpeakingChanged')?.({ session_id: 's1', user_ids: ['u9'] });

    channel.state.handlers.get('VoiceParticipantChanged')?.({
      session_id: 's1',
      left: false,
      ...participant('u7', 'listener'),
    });

    expect(getRoomSession('gardeners/office-hours')).toMatchObject({
      speaking: ['u9'],
      listeners: ['u7'],
    });
  });

  it('keeps a live room live when its community loads again', async () => {
    const { store, gateway: g } = await joined();

    await g.load.voice('gardeners', 'office-hours');

    await g.load.community('gardeners');

    expect(store.get().communities['gardeners']!.voice[0]).toMatchObject({
      id: 'office-hours',
      live: true,
      mode: 'stage',
      topic: 'Open floor',
    });
  });

  it('floats a reaction with who sent it', async () => {
    const { gateway: g } = await joined();

    await g.voice.join('gardeners', 'office-hours', false);

    channel.state.handlers.get('VoiceReaction')?.({
      session_id: 's1',
      user_id: 'u9',
      emoji: ':tada:',
    });

    expect(getRoomSession('gardeners/office-hours').floats).toEqual([
      expect.objectContaining({ emoji: ':tada:', by: 'u9' }),
    ]);
  });
});

describe('voice host tools', () => {
  it('says only a host or moderator can when the server forbids it', async () => {
    const { gateway: g } = await joined();

    await g.voice.join('gardeners', 'office-hours', false);

    routes['POST /api/voice-sessions/s1/participants/u9/invite'] = {
      status: 403,
      body: { code: 'forbidden' },
    };

    expect(await g.voice.invite('u9')).toEqual({
      ok: false,
      error: 'Only the host or a moderator can do that here.',
    });
  });

  it('turns a known refusal into its sentence', async () => {
    const { gateway: g } = await joined();

    await g.voice.join('gardeners', 'office-hours', false);

    routes['POST /api/voice-sessions/s1/participants/u9/invite'] = {
      status: 409,
      body: { code: 'on_stage' },
    };

    expect(await g.voice.invite('u9')).toEqual({ ok: false, error: "They're already on stage." });
  });

  it('server mutes someone through the session', async () => {
    const { gateway: g } = await joined();

    await g.voice.join('gardeners', 'office-hours', false);
    routes['PUT /api/voice-sessions/s1/participants/u9/server-mute'] = { status: 204 };

    expect(await g.voice.serverMute('u9', true)).toEqual({ ok: true, value: undefined });
    expect(sent.at(-1)).toMatchObject({ method: 'PUT', body: { muted: true } });
  });

  it('asks you to join first when you are not in the room', async () => {
    const { gateway: g } = await joined();

    expect(await g.voice.raiseHand(true)).toEqual({ ok: false, error: 'Join the room first.' });
  });
});

describe('voice.toggleMute', () => {
  it('fails for a listener, who has no microphone open', async () => {
    const { gateway: g } = await joined();
    await g.voice.join('gardeners', 'office-hours', false);

    expect(await g.voice.toggleMute()).toEqual({
      ok: false,
      error: 'Only people on stage can do that.',
    });
  });

  it('lets a listener in an open room talk', async () => {
    routes['PUT /api/voice-sessions/s1/mute'] = { status: 204, body: undefined };

    const { gateway: g } = await joined();
    channel.state.joinReply = { status: 'ok', payload: { ...joinReply, mode: 'open' } };
    await g.voice.join('gardeners', 'office-hours', false);

    expect((await g.voice.toggleMute()).ok).toBe(true);
    expect(sent.at(-1)).toMatchObject({
      path: '/api/voice-sessions/s1/mute',
      body: { muted: false },
    });
  });
});

describe('voice.react', () => {
  it('sends the reaction on the voice channel', async () => {
    const { gateway: g } = await joined();

    await g.voice.join('gardeners', 'office-hours', false);

    g.voice.react(':heart:');

    expect(channel.state.pushes).toContainEqual({ event: 'react', payload: { emoji: ':heart:' } });
  });
});

const recorded = {
  id: 'r1',
  session_id: 's1',
  room_id: 'v1',
  community_id: 'c1',
  started_by_id: 'u9',
  title: 'Supervisor trees',
  status: 'ready',
  failure: null,
  started_at: at,
  ended_at: at,
  duration_ms: 65_000,
  byte_size: 1000,
  width: 1280,
  height: 720,
  has_screen: true,
  video_url: 'https://files.example.test/video.mp4',
  poster_url: null,
  speakers: [],
};

describe('voice.record', () => {
  it('turns a known refusal into its sentence', async () => {
    const { gateway: g } = await joined();

    await g.voice.join('gardeners', 'office-hours', false);

    routes['POST /api/voice-sessions/s1/recording'] = {
      status: 400,
      body: { code: 'already_recording' },
    };

    expect(await g.voice.record(true)).toEqual({
      ok: false,
      error: 'This room is already being recorded.',
    });
  });

  it('starts and stops recording through the session', async () => {
    const { gateway: g } = await joined();

    await g.voice.join('gardeners', 'office-hours', false);
    routes['POST /api/voice-sessions/s1/recording'] = { status: 204 };
    routes['DELETE /api/voice-sessions/s1/recording'] = { status: 204 };

    expect(await g.voice.record(true)).toEqual({ ok: true, value: undefined });
    expect(await g.voice.record(false)).toEqual({ ok: true, value: undefined });
    expect(sent.at(-1)).toMatchObject({ method: 'DELETE' });
  });

  it('shows the banner to everyone once the server says it records', async () => {
    const { gateway: g } = await joined();

    await g.voice.join('gardeners', 'office-hours', false);

    channel.state.handlers.get('VoiceRecordingChanged')?.({
      session_id: 's1',
      community_id: 'c1',
      room_id: 'v1',
      recording_id: 'r1',
      status: 'recording',
      started_by_id: 'u9',
      started_at: at,
    });

    expect(getRoomSession('gardeners/office-hours').recording).toEqual({
      on: true,
      by: 'u9',
      startedAt: Date.parse(at),
    });

    channel.state.handlers.get('VoiceRecordingChanged')?.({
      session_id: 's1',
      community_id: 'c1',
      room_id: 'v1',
      recording_id: 'r1',
      status: 'processing',
      started_by_id: 'u9',
      started_at: at,
    });

    expect(getRoomSession('gardeners/office-hours').recording).toEqual({ on: false });
  });

  it("lists the room's recordings when the room loads", async () => {
    const { store, gateway: g } = await joined();

    routes['GET /api/rooms/v1/recordings'] = { status: 200, body: page([recorded]) };

    await g.load.voice('gardeners', 'office-hours');
    await vi.waitFor(() => expect(store.get().recordings['r1']).toBeDefined());

    expect(store.get().recordings['r1']).toMatchObject({
      rid: 'office-hours',
      status: 'ready',
      duration: '1:05',
      screen: true,
      url: 'https://files.example.test/video.mp4',
    });
  });

  it('drops a recording from the room when the person who made it deletes it', async () => {
    const { store, gateway: g } = await joined();

    routes['GET /api/rooms/v1/recordings'] = { status: 200, body: page([recorded]) };

    await g.load.voice('gardeners', 'office-hours');
    await vi.waitFor(() => expect(store.get().recordings['r1']).toBeDefined());

    channel.state.topics.get('community:c1 VoiceRecordingDeleted')?.({
      recording_id: 'r1',
      session_id: 's1',
      post_id: null,
      community_id: 'c1',
      room_id: 'v1',
    });

    expect(store.get().recordings['r1']).toBeUndefined();
  });

  it('names a recording after its event, and the room when it has none', async () => {
    const { store, gateway: g } = await joined();

    routes['GET /api/rooms/v1/recordings'] = {
      status: 200,
      body: page([recorded, { ...recorded, id: 'r2', title: null }]),
    };

    await g.load.voice('gardeners', 'office-hours');
    await vi.waitFor(() => expect(store.get().recordings['r2']).toBeDefined());

    expect(store.get().recordings['r1']?.title).toBe('Supervisor trees');
    expect(store.get().recordings['r2']?.title).toBe(store.get().recordings['r2']?.room);
  });

  it('shows a new title when the person who made it renames it', async () => {
    const { store, gateway: g } = await joined();

    routes['GET /api/rooms/v1/recordings'] = { status: 200, body: page([recorded]) };

    await g.load.voice('gardeners', 'office-hours');
    await vi.waitFor(() => expect(store.get().recordings['r1']).toBeDefined());

    channel.state.topics.get('community:c1 VoiceRecordingRenamed')?.({
      recording_id: 'r1',
      title: 'Links from the call',
      session_id: 's1',
      post_id: null,
      community_id: 'c1',
      room_id: 'v1',
    });

    expect(store.get().recordings['r1']?.title).toBe('Links from the call');
  });

  it('adds older recordings below the ones already shown', async () => {
    const { store, gateway: g } = await joined();
    const first = { ...page([recorded]), meta: { ...page([]).meta, has_next: true, after: 'r1' } };

    routes['GET /api/rooms/v1/recordings'] = [
      { status: 200, body: first },
      { status: 200, body: page([{ ...recorded, id: 'r0' }]) },
    ];

    await g.load.voice('gardeners', 'office-hours');
    await vi.waitFor(() => expect(store.get().recordings['r1']).toBeDefined());
    await g.voice.moreRecordings('gardeners', 'office-hours');

    expect(Object.keys(store.get().recordings)).toEqual(expect.arrayContaining(['r1', 'r0']));
    expect(
      store.get().communities['gardeners']?.voice.find((v) => v.id === 'office-hours')
        ?.recordingsAfter,
    ).toBeNull();
  });
});
