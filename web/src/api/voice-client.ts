import type { Channel } from 'phoenix';
import type { Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import type {
  VoiceParticipant,
  VoiceParticipantRole,
  VoiceRecordingNow,
} from '@/generated/schemas';
import type { VoiceEvents } from './realtime';

export type TrackInfo = {
  readonly kind: 'audio' | 'video';
  readonly direction: 'send' | 'receive';
  readonly user_id: string;
};

export type JoinReply = {
  readonly ice_servers: RTCIceServer[];
  readonly me: { readonly role: VoiceParticipantRole; readonly server_muted: boolean };
  readonly mode: 'stage' | 'open';
  readonly share: string | null;
  readonly recording: VoiceRecordingNow | null;
  readonly hands: string[];
  readonly speaking: string[];
  readonly participants: VoiceParticipant[];
};

export type DisconnectReason = 'disconnected' | 'ended' | 'lost' | 'left' | 'replaced';

export type AudioOut = {
  play(): Promise<void>;
  stop(): void;
};

export type LevelMeter = { level(): number; stop(): void };

export type VoiceClientDeps = {
  readonly openChannel: (topic: `voice:${string}`, params: Record<string, unknown>) => Channel;
  readonly createPeer: (config: RTCConfiguration) => RTCPeerConnection;
  readonly getMic: () => Promise<MediaStream>;
  readonly playAudio: (stream: MediaStream) => AudioOut;
  readonly setScreen: (stream: MediaStream | null) => void;
  readonly meter?: ((source: MediaStream | MediaStreamTrack) => LevelMeter) | undefined;
};

export type VoiceClientEvents = {
  readonly onEvent: <E extends keyof VoiceEvents>(name: E, payload: VoiceEvents[E]) => void;
  readonly onConnection: (state: 'connecting' | 'connected' | 'reconnecting') => void;
  readonly onAudioBlocked: (blocked: boolean) => void;
  readonly onDisconnected: (reason: DisconnectReason) => void;
  readonly onRejoined: (reply: JoinReply) => void;
  readonly onSpeaking: (userIds: string[]) => void;
  readonly onSelfTalking: (talking: boolean) => void;
  readonly onError: (message: string) => void;
};

const VOICE_EVENTS = [
  'VoiceParticipantChanged',
  'VoiceShareChanged',
  'VoiceSpeakingChanged',
  'VoiceSessionEnded',
  'VoiceReaction',
  'VoiceCaption',
  'VoiceRecordingChanged',
] as const satisfies readonly (keyof VoiceEvents)[];

export const SCREEN_LIMITS = { maxBitrate: 1_500_000, maxFramerate: 15 } as const;

const FALLBACK_AFTER_MS = 5000;
const METER_EVERY_MS = 250;
const SPEAKING_LEVEL = 0.04;

// Holds a moment so the ring doesn't flicker between words
const SELF_EVERY_MS = 100;
const SELF_HOLD_MS = 400;

export const JOIN_REFUSALS: Record<string, string> = {
  full: 'This room is full. Try again in a bit.',
  not_found: 'This room has ended.',
  not_live: 'This room has ended.',
  forbidden: "You can't join this room.",
  banned: "You can't join this room.",
  unavailable: 'Voice rooms are not available right now. Try again in a bit.',
  timeout: "The room didn't answer. Check your connection and try again.",
};

const MIC_FAILED =
  "Hearth couldn't use your microphone. Check this site's microphone permission, then try again.";

const CALL_FAILED = "The call couldn't connect. Leave and join again.";

// An answer must finish before the next offer is applied so offers and candidates run one at a time
export class VoiceClient {
  private channel: Channel | null = null;
  private pc: RTCPeerConnection | null = null;
  private tracks: Record<string, TrackInfo> = {};
  private readonly outs = new Map<string, { out: AudioOut; user: string; stream: MediaStream }>();
  private chain: Promise<void> = Promise.resolve();
  private mic: MediaStream | null = null;
  private screen: MediaStream | null = null;
  private muted = true;
  private blocked = false;
  private restarting = false;
  private toldFailed = false;
  private closed = false;

  private serverSpeaking = false;
  private firstAudioAt: number | null = null;
  private meters = new Map<string, LevelMeter>();
  private meterTimer: ReturnType<typeof setInterval> | null = null;
  private lastFallback = '';

  private selfMeter: { meter: LevelMeter; probe: MediaStreamTrack } | null = null;
  private selfTimer: ReturnType<typeof setInterval> | null = null;
  private selfTalking = false;
  private selfHeardAt = 0;

  private readonly sessionId: string;
  private readonly deps: VoiceClientDeps;
  private readonly on: VoiceClientEvents;

  constructor(sessionId: string, deps: VoiceClientDeps, on: VoiceClientEvents) {
    this.sessionId = sessionId;
    this.deps = deps;
    this.on = on;
  }

  connect(stage: boolean): Promise<Result<JoinReply>> {
    const channel = this.deps.openChannel(`voice:${this.sessionId}`, { stage });

    this.channel = channel;

    channel.on('offer', (offer: { sdp: string; tracks: Record<string, TrackInfo> }) =>
      this.enqueue(() => this.answer(offer)),
    );

    channel.on('candidate', ({ candidate }: { candidate: RTCIceCandidateInit | null }) =>
      this.enqueue(() => this.addCandidate(candidate)),
    );

    channel.on('Disconnected', ({ reason }: { reason: DisconnectReason }) => {
      this.close();
      this.on.onDisconnected(reason);
    });

    for (const name of VOICE_EVENTS)
      channel.on(name, (payload: VoiceEvents[typeof name]) => {
        if (name === 'VoiceSpeakingChanged') this.serverSpeaking = true;
        this.on.onEvent(name, payload);
      });

    this.on.onConnection('connecting');

    return new Promise((resolve) => {
      let first = true;

      channel
        .join()
        .receive('ok', (reply: JoinReply) => {
          // Phoenix joins again on its own after the socket drops, and the
          // server then starts a fresh peer so the old connection goes
          this.startPeer(reply.ice_servers);
          if (first) {
            first = false;
            resolve(ok(reply));
          } else {
            this.on.onRejoined(reply);
          }
        })
        .receive('error', ({ reason }: { reason?: string }) => {
          if (!first) return;
          first = false;
          channel.leave();
          resolve(fail(JOIN_REFUSALS[reason ?? ''] ?? CALL_FAILED));
        })
        .receive('timeout', () => {
          if (!first) return;
          first = false;
          channel.leave();
          resolve(fail(JOIN_REFUSALS['timeout']!));
        });
    });
  }

  setMuted(muted: boolean) {
    this.muted = muted;
    this.mic?.getAudioTracks().forEach((track) => (track.enabled = !muted));
  }

  async setScreen(screen: MediaStream | null) {
    this.screen = screen;
    const sender = this.sendingSender('video');
    if (sender) await sender.replaceTrack(screen?.getVideoTracks()[0] ?? null);
  }

  react(emoji: string) {
    this.channel?.push('react', { emoji });
  }

  // The server turns speech into captions only while someone in the room wants them
  captions(on: boolean) {
    this.channel?.push('captions', { on });
  }

  async resumeAudio() {
    const results = await Promise.allSettled([...this.outs.values()].map(({ out }) => out.play()));
    const stillBlocked = results.some((r) => r.status === 'rejected');
    this.setBlocked(stillBlocked);
  }

  leave() {
    this.channel?.leave();
    this.close();
  }

  close() {
    if (this.closed) return;
    this.closed = true;

    this.mic?.getTracks().forEach((track) => track.stop());
    this.mic = null;
    this.stopSelfMeter();
    this.stopOuts();
    this.stopMeters();
    this.deps.setScreen(null);
    this.pc?.close();
    this.pc = null;
    this.channel = null;
  }

  // One failure is enough to tell, so later ones stay quiet until the call connects again
  private enqueue(step: () => Promise<void>) {
    this.chain = this.chain.then(step).catch((error: unknown) => {
      console.warn('Hearth voice signalling failed.', error);
      if (this.toldFailed) return;
      this.toldFailed = true;
      this.on.onError(CALL_FAILED);
    });
  }

  private startPeer(iceServers: RTCIceServer[]) {
    this.stopOuts();
    this.pc?.close();
    this.tracks = {};

    const pc = this.deps.createPeer({ iceServers });

    this.pc = pc;

    pc.onicecandidate = (e) =>
      this.channel?.push('candidate', { candidate: e.candidate ? e.candidate.toJSON() : null });

    pc.ontrack = (e) => this.receive(e);

    pc.onconnectionstatechange = () => {
      if (pc !== this.pc) return;

      switch (pc.connectionState) {
        case 'connected':
          this.restarting = false;
          this.toldFailed = false;
          this.on.onConnection('connected');
          return;
        case 'disconnected':
          this.on.onConnection('reconnecting');
          return;
        case 'failed':
          this.on.onConnection('reconnecting');
          this.restartIce();
          return;
        default:
          return;
      }
    };
  }

  private restartIce() {
    if (this.restarting || !this.channel) return;
    this.restarting = true;

    this.channel
      .push('ice_restart', {})
      .receive('ok', ({ ice_servers }: { ice_servers: RTCIceServer[] }) =>
        this.pc?.setConfiguration({ iceServers: ice_servers }),
      )
      .receive('error', () => {
        // The server lost the peer so rejoining builds a new one
        this.close();
        this.on.onDisconnected('lost');
      });
  }

  private async answer({ sdp, tracks }: { sdp: string; tracks: Record<string, TrackInfo> }) {
    const pc = this.pc;

    if (!pc) return;

    this.tracks = tracks;
    await pc.setRemoteDescription({ type: 'offer', sdp });

    // The microphone opens only when the server gives this person a mid to send it on
    const sends = Object.values(tracks).some((t) => t.direction === 'send' && t.kind === 'audio');
    const mic = sends ? await this.micTrack() : null;
    const screen = this.screen?.getVideoTracks()[0] ?? null;

    const swaps = pc.getTransceivers().map((transceiver) => {
      const info = transceiver.mid ? tracks[transceiver.mid] : undefined;

      if (!info || transceiver.currentDirection === 'stopped') return null;

      if (info.direction === 'receive') {
        transceiver.direction = 'recvonly';
        return null;
      }

      transceiver.direction = 'sendonly';

      const track = info.kind === 'audio' ? mic : screen;

      return transceiver.sender.track === track ? null : transceiver.sender.replaceTrack(track);
    });

    await Promise.all(swaps);

    this.dropGone();

    const answer = await pc.createAnswer();

    await pc.setLocalDescription(answer);
    this.channel?.push('answer', { sdp: answer.sdp });

    await this.limitScreen();
  }

  // A candidate meant for a connection that was just replaced is dropped, since the others still connect
  private async addCandidate(candidate: RTCIceCandidateInit | null) {
    try {
      await this.pc?.addIceCandidate(candidate ?? undefined);
    } catch (error) {
      console.warn('Hearth skipped a network candidate.', error);
    }
  }

  private async micTrack(): Promise<MediaStreamTrack | null> {
    if (!this.mic) {
      try {
        this.mic = await this.deps.getMic();
      } catch (error) {
        console.warn('Hearth could not open the microphone.', error);
        this.on.onError(MIC_FAILED);
        return null;
      }
    }

    const track = this.mic.getAudioTracks()[0] ?? null;

    if (track) {
      track.enabled = !this.muted;
      this.startSelfMeter(track);
    }

    return track;
  }

  // The copy stays on while muted so the room can say you're talking muted
  private startSelfMeter(track: MediaStreamTrack) {
    if (this.selfMeter || !this.deps.meter) return;

    const probe = track.clone();

    probe.enabled = true;
    this.selfMeter = { meter: this.deps.meter(probe), probe };

    this.selfTimer = setInterval(() => {
      const now = Date.now();

      if ((this.selfMeter?.meter.level() ?? 0) > SPEAKING_LEVEL) this.selfHeardAt = now;

      const talking = now - this.selfHeardAt < SELF_HOLD_MS;

      if (talking === this.selfTalking) return;
      this.selfTalking = talking;
      this.on.onSelfTalking(talking);
    }, SELF_EVERY_MS);
  }

  private stopSelfMeter() {
    if (this.selfTimer) clearInterval(this.selfTimer);
    this.selfTimer = null;
    this.selfMeter?.meter.stop();
    this.selfMeter?.probe.stop();
    this.selfMeter = null;
    if (this.selfTalking) this.on.onSelfTalking(false);
    this.selfTalking = false;
  }

  private sendingSender(kind: 'audio' | 'video'): RTCRtpSender | null {
    const transceiver = this.pc
      ?.getTransceivers()
      .find(
        (t) =>
          t.mid !== null &&
          this.tracks[t.mid]?.direction === 'send' &&
          this.tracks[t.mid]?.kind === kind,
      );
    return transceiver?.sender ?? null;
  }

  private async limitScreen() {
    const sender = this.sendingSender('video');

    if (!sender?.track) return;

    sender.track.contentHint = 'detail';

    const params = sender.getParameters();

    if (!params.encodings?.length) return;

    params.encodings = params.encodings.map((e) => ({ ...e, ...SCREEN_LIMITS }));
    await sender.setParameters(params);
  }

  private receive(e: RTCTrackEvent) {
    const mid = e.transceiver.mid;
    const info = mid ? this.tracks[mid] : undefined;

    if (!mid || !info || info.direction !== 'receive') return;

    const stream = e.streams[0] ?? new MediaStream([e.track]);

    if (info.kind === 'video') {
      this.deps.setScreen(stream);
      e.track.addEventListener('ended', () => this.deps.setScreen(null));
      return;
    }

    this.outs.get(mid)?.out.stop();

    const out = this.deps.playAudio(stream);

    this.outs.set(mid, { out, user: info.user_id, stream });
    this.firstAudioAt ??= Date.now();
    this.startMeters();

    out.play().then(
      () => this.setBlocked(false),
      () => this.setBlocked(true),
    );
  }

  private dropGone() {
    for (const [mid, { out }] of this.outs) {
      if (this.tracks[mid]?.direction === 'receive') continue;
      out.stop();
      this.outs.delete(mid);
      this.meters.get(mid)?.stop();
      this.meters.delete(mid);
    }

    const watching = Object.values(this.tracks).some(
      (t) => t.direction === 'receive' && t.kind === 'video',
    );

    if (!watching) this.deps.setScreen(null);
  }

  private setBlocked(blocked: boolean) {
    if (this.blocked === blocked) return;
    this.blocked = blocked;
    this.on.onAudioBlocked(blocked);
  }

  private stopOuts() {
    for (const { out } of this.outs.values()) out.stop();
    this.outs.clear();
  }

  // Used when the browser leaves out the audio level header
  private startMeters() {
    if (this.meterTimer || !this.deps.meter) return;

    this.meterTimer = setInterval(() => {
      if (this.serverSpeaking) {
        this.stopMeters();
        return;
      }

      if (this.firstAudioAt === null || Date.now() - this.firstAudioAt < FALLBACK_AFTER_MS) return;

      const speaking: string[] = [];

      for (const [mid, { user, stream }] of this.outs) {
        let meter = this.meters.get(mid);

        if (!meter && this.deps.meter) {
          meter = this.deps.meter(stream);
          this.meters.set(mid, meter);
        }

        if (meter && meter.level() > SPEAKING_LEVEL) speaking.push(user);
      }

      const key = speaking.sort().join(',');

      if (key === this.lastFallback) return;
      this.lastFallback = key;
      this.on.onSpeaking(speaking);
    }, METER_EVERY_MS);
  }

  private stopMeters() {
    if (this.meterTimer) clearInterval(this.meterTimer);
    this.meterTimer = null;
    for (const meter of this.meters.values()) meter.stop();
    this.meters.clear();
  }
}
