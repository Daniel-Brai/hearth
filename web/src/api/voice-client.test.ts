import type { Channel } from 'phoenix';
import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  SCREEN_LIMITS,
  VoiceClient,
  type JoinReply,
  type TrackInfo,
  type VoiceClientDeps,
  type VoiceClientEvents,
} from './voice-client';

type Reply = { status: string; payload: unknown };

class FakePush {
  private readonly callbacks = new Map<string, (payload: never) => void>();
  reply: Reply | null = null;

  receive(status: string, callback: (payload: never) => void) {
    this.callbacks.set(status, callback);
    if (this.reply?.status === status) callback(this.reply.payload as never);
    return this;
  }

  answer(status: string, payload: unknown = {}) {
    this.reply = { status, payload };
    this.callbacks.get(status)?.(payload as never);
  }
}

class FakeChannel {
  readonly handlers = new Map<string, (payload: never) => void>();
  readonly pushes: { event: string; payload: unknown; push: FakePush }[] = [];
  readonly joining = new FakePush();
  left = false;

  on(event: string, handler: (payload: never) => void) {
    this.handlers.set(event, handler);
    return 0;
  }

  join() {
    return this.joining;
  }

  push(event: string, payload: unknown) {
    const push = new FakePush();
    this.pushes.push({ event, payload, push });
    return push;
  }

  leave() {
    this.left = true;
  }

  emit(event: string, payload: unknown) {
    this.handlers.get(event)?.(payload as never);
  }

  sent(event: string) {
    return this.pushes.filter((p) => p.event === event);
  }
}

const track = (kind: 'audio' | 'video') => ({
  kind,
  enabled: true,
  contentHint: '',
  stopped: false,
  clone() {
    return track(kind);
  },
  stop() {
    this.stopped = true;
  },
  addEventListener: vi.fn(),
});

type FakeTrack = ReturnType<typeof track>;

const streamOf = (t: FakeTrack) =>
  ({
    getAudioTracks: () => (t.kind === 'audio' ? [t] : []),
    getVideoTracks: () => (t.kind === 'video' ? [t] : []),
    getTracks: () => [t],
  }) as unknown as MediaStream;

const sender = () => {
  const s = {
    track: null as FakeTrack | null,
    params: { encodings: [{ active: true }] } as RTCRtpSendParameters,
    replaceTrack: vi.fn(async (t: FakeTrack | null) => {
      s.track = t;
    }),
    getParameters: () => s.params,
    setParameters: vi.fn(async (p: RTCRtpSendParameters) => {
      s.params = p;
    }),
  };
  return s;
};

const transceiver = (mid: string) => ({
  mid,
  direction: 'sendrecv',
  currentDirection: null,
  sender: sender(),
});

class FakePeer {
  transceivers: ReturnType<typeof transceiver>[] = [];
  connectionState = 'new';
  closed = false;
  config: RTCConfiguration | null = null;
  readonly candidates: unknown[] = [];
  onicecandidate: ((e: { candidate: { toJSON(): unknown } | null }) => void) | null = null;
  ontrack: ((e: unknown) => void) | null = null;
  onconnectionstatechange: (() => void) | null = null;

  getTransceivers() {
    return this.transceivers;
  }
  async setRemoteDescription() {}
  async createAnswer() {
    return { type: 'answer', sdp: 'v=0 answer' };
  }
  async setLocalDescription() {}
  async addIceCandidate(c: unknown) {
    this.candidates.push(c);
  }
  setConfiguration(c: RTCConfiguration) {
    this.config = c;
  }
  close() {
    this.closed = true;
  }
  becomes(state: string) {
    this.connectionState = state;
    this.onconnectionstatechange?.();
  }
}

const reply: JoinReply = {
  ice_servers: [{ urls: 'stun:example.test' }],
  me: { role: 'listener', server_muted: false },
  mode: 'stage',
  share: null,
  recording: null,
  hands: [],
  speaking: [],
  participants: [],
};

const settle = () => new Promise((resolve) => setTimeout(resolve, 0));

function setup(overrides: Partial<VoiceClientDeps> = {}) {
  const channel = new FakeChannel();
  const peers: FakePeer[] = [];
  const mic = track('audio');
  const outs: { play: ReturnType<typeof vi.fn>; stop: ReturnType<typeof vi.fn> }[] = [];

  const deps: VoiceClientDeps = {
    openChannel: () => channel as unknown as Channel,
    createPeer: () => {
      const pc = new FakePeer();
      peers.push(pc);
      return pc as unknown as RTCPeerConnection;
    },
    getMic: vi.fn(async () => streamOf(mic)),
    playAudio: () => {
      const out = { play: vi.fn(async () => undefined), stop: vi.fn() };
      outs.push(out);
      return out;
    },
    setScreen: vi.fn(),
    ...overrides,
  };

  const on: VoiceClientEvents = {
    onEvent: vi.fn(),
    onConnection: vi.fn(),
    onAudioBlocked: vi.fn(),
    onDisconnected: vi.fn(),
    onRejoined: vi.fn(),
    onSpeaking: vi.fn(),
    onSelfTalking: vi.fn(),
    onError: vi.fn(),
  };

  const client = new VoiceClient('s1', deps, on);
  const peer = () => peers.at(-1)!;

  const join = async (stage = false) => {
    const joined = client.connect(stage);
    channel.joining.answer('ok', reply);
    return joined;
  };

  const offer = async (tracks: Record<string, TrackInfo>) => {
    peer().transceivers = Object.keys(tracks).map(transceiver);
    channel.emit('offer', { sdp: 'v=0 offer', tracks });
    await settle();
  };

  return { client, channel, peers, peer, mic, outs, deps, on, join, offer };
}

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

describe('VoiceClient.connect/1', () => {
  it('says plainly why the server turned the join down', async () => {
    const { client, channel } = setup();

    const joined = client.connect(false);

    channel.joining.answer('error', { reason: 'full' });

    expect(await joined).toEqual({ ok: false, error: 'This room is full. Try again in a bit.' });
    expect(channel.left).toBe(true);
  });

  it('says the room did not answer on a timeout', async () => {
    const { client, channel } = setup();

    const joined = client.connect(false);

    channel.joining.answer('timeout');

    expect(await joined).toMatchObject({ ok: false });
  });

  it('starts a peer with the ICE servers from the join', async () => {
    const { join, peer, on } = setup();

    expect(await join()).toEqual({ ok: true, value: reply });
    expect(on.onConnection).toHaveBeenCalledWith('connecting');

    peer().becomes('connected');
    expect(on.onConnection).toHaveBeenLastCalledWith('connected');
  });
});

describe('VoiceClient offers', () => {
  it('answers a listener without opening the microphone', async () => {
    const { join, offer, peer, channel, deps } = setup();

    await join();

    await offer({ '0': { kind: 'audio', direction: 'receive', user_id: 'u2' } });

    expect(channel.sent('answer')).toEqual([
      expect.objectContaining({ payload: { sdp: 'v=0 answer' } }),
    ]);

    expect(peer().transceivers[0]!.direction).toBe('recvonly');
    expect(deps.getMic).not.toHaveBeenCalled();
  });

  it('sends the microphone, muted, once the server opens a send mid', async () => {
    const { join, offer, peer, mic } = setup();

    await join(true);

    await offer({ '0': { kind: 'audio', direction: 'send', user_id: 'me' } });

    expect(peer().transceivers[0]!.direction).toBe('sendonly');
    expect(peer().transceivers[0]!.sender.track).toBe(mic);
    expect(mic.enabled).toBe(false);
  });

  it('caps a shared screen for sharp text at one upload', async () => {
    const { client, join, offer, peer } = setup();
    const screen = track('video');

    await join(true);
    await client.setScreen(streamOf(screen));

    await offer({ '1': { kind: 'video', direction: 'send', user_id: 'me' } });

    const s = peer().transceivers[0]!.sender;

    expect(s.track).toBe(screen);
    expect(screen.contentHint).toBe('detail');
    expect(s.params.encodings[0]).toMatchObject(SCREEN_LIMITS);
    expect(SCREEN_LIMITS).toEqual({ maxBitrate: 1_500_000, maxFramerate: 15 });
  });

  it('trickles candidates both ways', async () => {
    const { join, peer, channel } = setup();

    await join();

    channel.emit('candidate', { candidate: { candidate: 'a=1' } });
    channel.emit('candidate', { candidate: null });
    await settle();
    peer().onicecandidate?.({ candidate: { toJSON: () => ({ candidate: 'b=2' }) } });
    peer().onicecandidate?.({ candidate: null });

    expect(peer().candidates).toEqual([{ candidate: 'a=1' }, undefined]);

    expect(channel.sent('candidate').map((p) => p.payload)).toEqual([
      { candidate: { candidate: 'b=2' } },
      { candidate: null },
    ]);
  });
});

describe('VoiceClient signalling failures', () => {
  it('drops a candidate the connection turns down without telling you', async () => {
    const { join, peer, channel, on } = setup();
    const logged = vi.spyOn(console, 'warn').mockImplementation(() => undefined);

    await join();
    peer().addIceCandidate = () => Promise.reject(new Error('no remote description'));

    channel.emit('candidate', { candidate: { candidate: 'a=1' } });
    channel.emit('candidate', { candidate: { candidate: 'a=2' } });
    await settle();

    expect(on.onError).not.toHaveBeenCalled();
    expect(logged).toHaveBeenCalledTimes(2);
  });

  it('tells you once when offers keep failing, until the call connects again', async () => {
    const { join, peer, offer, on } = setup();
    const logged = vi.spyOn(console, 'warn').mockImplementation(() => undefined);

    await join();
    peer().setRemoteDescription = () => Promise.reject(new Error('bad offer'));

    await offer({ a0: { kind: 'audio', direction: 'receive', user_id: 'u9' } });
    await offer({ a0: { kind: 'audio', direction: 'receive', user_id: 'u9' } });
    await offer({ a0: { kind: 'audio', direction: 'receive', user_id: 'u9' } });

    expect(on.onError).toHaveBeenCalledOnce();

    peer().becomes('connected');
    await offer({ a0: { kind: 'audio', direction: 'receive', user_id: 'u9' } });

    expect(on.onError).toHaveBeenCalledTimes(2);
    expect(logged).toHaveBeenCalledTimes(4);
  });
});

describe('VoiceClient audio', () => {
  it('plays each remote speaker and asks for a tap when autoplay is blocked', async () => {
    const { join, offer, peer, outs, on } = setup({
      playAudio: () => ({ play: () => Promise.reject(new Error('blocked')), stop: vi.fn() }),
    });

    await join();
    await offer({ '0': { kind: 'audio', direction: 'receive', user_id: 'u2' } });

    peer().ontrack?.({
      transceiver: { mid: '0' },
      track: track('audio'),
      streams: [streamOf(track('audio'))],
    });

    await settle();

    expect(outs).toEqual([]);
    expect(on.onAudioBlocked).toHaveBeenCalledWith(true);
  });

  it('mutes and unmutes the microphone track here', async () => {
    const { client, join, offer, mic } = setup();

    await join(true);
    await offer({ '0': { kind: 'audio', direction: 'send', user_id: 'me' } });

    client.setMuted(false);
    expect(mic.enabled).toBe(true);

    client.setMuted(true);
    expect(mic.enabled).toBe(false);
  });

  it('tells you that you are talking, muted or not, from your own microphone', async () => {
    vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval', 'Date'] });

    let level = 0;
    const { join, offer, on } = setup({ meter: () => ({ level: () => level, stop: vi.fn() }) });

    await join(true);
    await offer({ '0': { kind: 'audio', direction: 'send', user_id: 'me' } });

    level = 0.3;
    await vi.advanceTimersByTimeAsync(150);
    expect(on.onSelfTalking).toHaveBeenLastCalledWith(true);

    level = 0;
    await vi.advanceTimersByTimeAsync(600);
    expect(on.onSelfTalking).toHaveBeenLastCalledWith(false);
  });
});

describe('VoiceClient recovery', () => {
  it('restarts ICE with fresh servers when the connection fails', async () => {
    const { join, peer, channel, on } = setup();

    await join();

    peer().becomes('failed');

    const [restart] = channel.sent('ice_restart');

    restart!.push.answer('ok', { ice_servers: [{ urls: 'turn:example.test' }] });

    expect(on.onConnection).toHaveBeenLastCalledWith('reconnecting');
    expect(peer().config).toEqual({ iceServers: [{ urls: 'turn:example.test' }] });
  });

  it('reports the call lost when the server cannot restart it', async () => {
    const { join, peer, channel, on } = setup();

    await join();

    peer().becomes('failed');
    channel.sent('ice_restart')[0]!.push.answer('error');

    expect(on.onDisconnected).toHaveBeenCalledWith('lost');
    expect(peer().closed).toBe(true);
  });

  it('tears everything down when it leaves', async () => {
    const { client, join, offer, peer, mic, channel, deps } = setup();

    await join(true);
    await offer({ '0': { kind: 'audio', direction: 'send', user_id: 'me' } });

    client.leave();

    expect(channel.left).toBe(true);
    expect(mic.stopped).toBe(true);
    expect(peer().closed).toBe(true);
    expect(deps.setScreen).toHaveBeenCalledWith(null);
  });
});

describe('VoiceClient.react/1', () => {
  it('sends the reaction on the session channel', async () => {
    const { client, join, channel } = setup();

    await join();

    client.react(':tada:');

    expect(channel.sent('react').map((p) => p.payload)).toEqual([{ emoji: ':tada:' }]);
  });
});
