import type { HearthGateway, Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import { floatReaction, useVoiceSession, type ServerSnapshot } from '@/data/voice-session';
import type { AppState } from '@/domain/app-state';
import type { VoiceMode } from '@/domain/types';
import { nowTime } from '@/domain/format';
import { mayTalk } from '@/domain/selectors';
import {
  recordingDelete,
  recordingUpdate,
  recordingRoomIndex,
  voiceCreate,
  voiceDemote,
  voiceDisconnect,
  voiceEndSession,
  voiceHand,
  voiceInvite,
  voiceLive,
  voiceLiveIndex,
  voiceMute,
  voiceServerMute,
  voiceShow,
  voiceStartRecording,
  voiceStartShare,
  voiceStopRecording,
  voiceStopShare,
} from '@/generated/api/voice/voice';
import type {
  VoiceParticipant,
  VoiceRecordingNow,
  VoiceSession,
  VoiceState,
} from '@/generated/schemas';
import { sfx } from '@/runtime/sounds';
import { useUi } from '@/runtime/ui-store';
import { setVoiceStream } from '@/runtime/voice-streams';
import type { VoiceEvents } from '../realtime';
import { getRealtime } from '../realtime';
import {
  JOIN_REFUSALS,
  VoiceClient,
  type AudioOut,
  type DisconnectReason,
  type JoinReply,
  type LevelMeter,
  type VoiceClientDeps,
} from '../voice-client';
import { toRecording } from '../mappers';
import type { GatewayContext } from './context';
import { call, errorCode, failed } from './context';

const REFUSALS: Record<string, string> = {
  not_here: 'Join the room first.',
  on_stage: "They're already on stage.",
  open_mode: 'Everyone can talk in an open room, so there is no stage to invite to.',
  share_taken: 'Someone else is sharing. They need to stop first.',
  already_recording: 'This room is already being recorded.',
  not_recording: 'Nothing is being recorded.',
  not_on_stage: 'Only people on stage can do that.',
  same_mode: 'The room is already like that.',
  invalid_transition: "That can't change right now.",
  not_live: 'This room has ended.',
  unavailable: 'Voice rooms are not available right now. Try again in a bit.',
  full: 'This room is full. Try again in a bit.',
};

const refused = (answer: { status: number; data: unknown }): Result<never> => {
  const code = errorCode(answer);
  const sentence = code ? REFUSALS[code] : undefined;

  if (sentence) return fail(sentence);
  if (answer.status === 403) return fail('Only the host or a moderator can do that here.');
  if (answer.status === 404) return fail(REFUSALS['not_live']!);

  return failed(answer);
};

const done = (answer: { status: number; data: unknown }): Result =>
  answer.status >= 200 && answer.status < 300 ? ok(undefined) : refused(answer);

const DISCONNECT_TEXT: Partial<Record<DisconnectReason, string>> = {
  disconnected: 'A host disconnected you from the room.',
  ended: 'The room ended.',
  replaced: 'You joined this room somewhere else, so it closed here.',
};

const GAVE_UP =
  'The call kept dropping, so Hearth left the room. Join again when your connection settles.';

const REJOIN_DELAYS_MS = [500, 2000, 5000];

// Losses further apart than this start a fresh run of tries
const REJOIN_WINDOW_MS = 60_000;

const browserDeps = (): VoiceClientDeps => ({
  openChannel: (topic, params) => getRealtime().open(topic, params),
  createPeer: (config) => new RTCPeerConnection(config),
  getMic: () =>
    navigator.mediaDevices.getUserMedia({
      audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
    }),
  playAudio: (stream): AudioOut => {
    const el = new Audio();

    el.autoplay = true;
    el.srcObject = stream;

    return {
      play: () => el.play(),
      stop: () => {
        el.pause();
        el.srcObject = null;
      },
    };
  },
  setScreen: (stream) => setVoiceStream('remoteScreen', stream),
  meter: (source): LevelMeter => {
    const stream = source instanceof MediaStream ? source : new MediaStream([source]);
    const audio = new AudioContext();
    const analyser = audio.createAnalyser();

    analyser.fftSize = 512;
    audio.createMediaStreamSource(stream).connect(analyser);

    const data = new Uint8Array(analyser.fftSize);

    return {
      level: () => {
        analyser.getByteTimeDomainData(data);

        let peak = 0;

        for (const v of data) peak = Math.max(peak, Math.abs(v - 128) / 128);

        return peak;
      },
      stop: () => void audio.close(),
    };
  },
});

type RunningRecording = { id: string; by: string; startedAt: number };

const running = (r: VoiceRecordingNow | null | undefined): RunningRecording | null =>
  r ? { id: r.id, by: r.started_by_id ?? '', startedAt: Date.parse(r.started_at) } : null;

type Joined = {
  key: string;
  cid: string;
  rid: string;
  session: string;
  client: VoiceClient;
  participants: Map<string, VoiceParticipant>;
  hands: string[];
  speaking: string[];
  share: string | null;
  recording: RunningRecording | null;
};

export function createVoiceGateway(
  ctx: GatewayContext,
  loadCommunity: (cid: string) => Promise<Result>,
  deps: () => VoiceClientDeps = browserDeps,
) {
  const sessions = new Map<string, string>();
  let joined: Joined | null = null;
  // The room this tab is ending itself, so its own ended event says nothing
  let ending: string | null = null;
  let losses: number[] = [];
  let rejoining: ReturnType<typeof setTimeout> | null = null;

  const cancelRejoin = () => {
    if (rejoining) clearTimeout(rejoining);
    rejoining = null;
  };

  const roomId = async (cid: string, rid: string): Promise<string | null> => {
    const key = `${cid}/${rid}`;
    if (!ctx.roomIds.has(key)) await loadCommunity(cid);
    return ctx.roomIds.get(key) ?? null;
  };

  const setRoom = (cid: string, rid: string, change: (room: VoiceRoomDraft) => void) =>
    ctx.store.set((state) => {
      const room = state.communities[cid]?.voice.find((v) => v.id === rid);
      if (room) change(room);
    });

  const markLive = (
    cid: string,
    rid: string,
    session: VoiceSession,
    people: number,
    present?: readonly string[],
  ) => {
    sessions.set(`${cid}/${rid}`, session.id);
    setRoom(cid, rid, (room) => {
      room.live = true;
      room.mode = session.mode;
      room.topic = session.topic;
      room.host = session.host_id ?? '';
      room.listeners = people;
      if (present) room.present = [...present];
      room.recording = session.recording;
      room.postId = session.post_id;
    });
  };

  const loadRecordings = async (cid: string, rid: string, id: string, after?: string) => {
    const answer = await call(() => recordingRoomIndex(id, after ? { after } : undefined));
    if (answer.status !== 200) return;

    const { data, meta } = answer.data;

    ctx.store.set((state) => {
      const name = state.communities[cid]?.voice.find((v) => v.id === rid)?.name ?? '';

      // A recording keeps the post or event it was for, which a room's list doesn't say
      const links = new Map(
        Object.values(state.recordings).map((r) => [
          r.id,
          { postId: r.postId, eventId: r.eventId },
        ]),
      );

      if (!after)
        for (const [key, r] of Object.entries(state.recordings))
          if (r.c === cid && r.rid === rid) delete state.recordings[key];

      for (const r of data)
        state.recordings[r.id] = toRecording(r, cid, rid, name, links.get(r.id));

      const room = state.communities[cid]?.voice.find((v) => v.id === rid);
      if (room) room.recordingsAfter = meta.has_next ? meta.after : null;
    });
  };

  const dropRecording = (id: string) =>
    ctx.store.set((state) => {
      delete state.recordings[id];
    });

  const retitle = (id: string, title: string) =>
    ctx.store.set((state) => {
      const r = state.recordings[id];
      if (r) r.title = title;
    });

  const markEnded = (cid: string, rid: string) => {
    sessions.delete(`${cid}/${rid}`);
    setRoom(cid, rid, (room) => {
      room.live = false;
      room.listeners = 0;
      room.present = [];
      room.host = '';
      room.recording = false;
      room.postId = null;
    });
  };

  const sync = () => {
    const j = joined;

    if (!j) return;

    const me = ctx.store.get().me;
    const people = [...j.participants.values()];

    const ids = (pick: (p: VoiceParticipant) => boolean) =>
      people.filter(pick).map((p) => p.user_id);

    // The room draws you on your own so the stage and the listeners hold everyone else
    const others = (pick: (p: VoiceParticipant) => boolean) =>
      ids((p) => p.user_id !== me && pick(p));

    const snapshot: ServerSnapshot = {
      speakers: others((p) => p.role !== 'listener'),
      listeners: others((p) => p.role === 'listener'),
      hands: j.hands,
      muted: ids((p) => p.self_muted),
      locked: ids((p) => p.server_muted),
      speaking: j.speaking,
      share: j.share ? { by: j.share } : null,
      handUp: me !== null && j.hands.includes(me),
      recording: j.recording
        ? { on: true, by: j.recording.by, startedAt: j.recording.startedAt }
        : { on: false },
    };

    useVoiceSession.getState().dispatch(j.key, { type: 'synced', snapshot });

    const mine = me ? j.participants.get(me) : undefined;

    ctx.store.set((state) => {
      if (state.live.key !== j.key) return;
      if (mine) {
        state.live.role = mine.role;
        state.live.muted = mine.self_muted || mine.server_muted;
      }
    });

    setRoom(j.cid, j.rid, (room) => {
      room.listeners = people.length;
      room.present = people.map((p) => p.user_id);
    });
  };

  const applyState = (
    j: Joined,
    state: Pick<VoiceState, 'hands' | 'speaking' | 'share'> & {
      participants: VoiceParticipant[];
      recording?: VoiceRecordingNow | null;
    },
  ) => {
    j.participants = new Map(state.participants.map((p) => [p.user_id, p]));
    j.hands = state.hands;
    j.speaking = state.speaking;
    j.share = state.share;
    j.recording = running(state.recording);
  };

  // The reason is shown unless whoever ended it here says so already
  const teardown = (reason: DisconnectReason | null, quiet = false) => {
    const j = joined;

    if (!j) return;
    joined = null;

    if (reason === null) j.client.leave();
    else j.client.close();

    useVoiceSession.getState().dispatch(j.key, { type: 'left' });

    ctx.store.set((state) => {
      if (state.live.key === j.key)
        state.live = { joined: false, key: null, role: 'listener', muted: true };
    });

    if (reason === 'ended') {
      markEnded(j.cid, j.rid);
      useVoiceSession.getState().drop(j.key);
    }

    if (reason === 'hidden') {
      useVoiceSession.getState().drop(j.key);
      ctx.dropRoom(j.cid, j.rid);
    }

    const text = reason && !quiet ? DISCONNECT_TEXT[reason] : undefined;

    if (text) useUi.getState().flash(text);
  };

  const onEvent = <E extends keyof VoiceEvents>(name: E, payload: VoiceEvents[E]) => {
    const j = joined;

    if (!j) return;

    switch (name) {
      case 'VoiceParticipantChanged': {
        const p = payload as VoiceEvents['VoiceParticipantChanged'];
        const arrived = !p.left && !!p.role && !j.participants.has(p.user_id);

        if (arrived && p.user_id !== ctx.store.get().me) sfx('arrive');

        if (p.left || !p.role) j.participants.delete(p.user_id);
        else
          j.participants.set(p.user_id, {
            user_id: p.user_id,
            role: p.role,
            hand_raised_at: p.hand_raised_at,
            self_muted: p.self_muted,
            server_muted: p.server_muted,
          });

        const hands = j.hands.filter((id) => id !== p.user_id);

        j.hands = !p.left && p.hand_raised_at ? [...hands, p.user_id] : hands;
        break;
      }
      case 'VoiceShareChanged':
        j.share = (payload as VoiceEvents['VoiceShareChanged']).user_id;
        break;
      case 'VoiceSpeakingChanged':
        j.speaking = (payload as VoiceEvents['VoiceSpeakingChanged']).user_ids;
        break;
      case 'VoiceRecordingChanged': {
        const r = payload as VoiceEvents['VoiceRecordingChanged'];
        const me = ctx.store.get().me;

        if (r.status === 'recording' && !j.recording) {
          j.recording = running({
            id: r.recording_id,
            started_by_id: r.started_by_id,
            started_at: r.started_at,
          });
          sfx('recordStart');
          if (r.started_by_id !== me) useUi.getState().flash('This room is being recorded');
        } else if (r.status !== 'recording' && j.recording?.id === r.recording_id) {
          j.recording = null;
          sfx('recordStop');
          if (r.started_by_id !== me) useUi.getState().flash('Recording stopped');
        }

        break;
      }
      case 'VoiceSessionEnded':
        teardown('ended', ending === j.key);
        return;
      case 'VoiceReaction': {
        const r = payload as VoiceEvents['VoiceReaction'];
        floatReaction(j.key, r.user_id, r.emoji);
        return;
      }
      case 'VoiceCaption': {
        const c = payload as VoiceEvents['VoiceCaption'];
        const caption = { id: ctx.store.nextId('cap'), who: c.user_id, t: nowTime(), text: c.text };
        useVoiceSession.getState().dispatch(j.key, { type: 'caption', caption });
        return;
      }
    }

    sync();
  };

  const refresh = async (j: Joined) => {
    const shown = await call(() => voiceShow(j.session));

    if (shown.status !== 200 || joined !== j) return;

    applyState(j, shown.data);

    ctx.store.set((state) => {
      if (state.live.key === j.key) state.live.hostTools = shown.data.host_tools;
    });

    sync();
  };

  const join = async (
    cid: string,
    rid: string,
    asSpeaker: boolean,
    fresh = false,
  ): Promise<Result> => {
    cancelRejoin();

    const key = `${cid}/${rid}`;
    const cached = fresh ? undefined : sessions.get(key);
    const session = cached ?? (await findSession(cid, rid));

    if (!session) return fail(REFUSALS['not_live']!);

    if (joined && joined.key !== key) teardown(null);
    if (joined?.key === key) return ok(undefined);

    const j: Joined = {
      key,
      cid,
      rid,
      session,
      client: null as unknown as VoiceClient,
      participants: new Map(),
      hands: [],
      speaking: [],
      share: null,
      recording: null,
    };

    j.client = new VoiceClient(session, deps(), {
      onEvent,
      onConnection: (connection) =>
        ctx.store.set((state) => {
          if (state.live.key === key) state.live.connection = connection;
        }),
      onAudioBlocked: (blocked) =>
        ctx.store.set((state) => {
          if (state.live.key === key) state.live.audioBlocked = blocked;
        }),
      onDisconnected: (reason) => {
        if (reason === 'lost' && joined === j) {
          const stage = ctx.store.get().live.role !== 'listener';
          const now = Date.now();

          losses = [...losses.filter((at) => now - at < REJOIN_WINDOW_MS), now];

          const delay = REJOIN_DELAYS_MS[losses.length - 1];

          teardown('lost');

          if (delay === undefined) {
            losses = [];
            useUi.getState().flash(GAVE_UP);
            return;
          }

          // The server lost the peer so join again to build a new one
          rejoining = setTimeout(() => {
            rejoining = null;
            void join(cid, rid, stage);
          }, delay);

          return;
        }
        if (joined === j) teardown(reason);
      },
      onRejoined: (reply) => {
        applyReply(j, reply);
        sync();
      },
      onSpeaking: (ids) => {
        j.speaking = ids;
        sync();
      },
      onSelfTalking: (talking) =>
        useVoiceSession.getState().dispatch(j.key, { type: 'self-talking', talking }),
      onError: (message) => useUi.getState().flash(message),
    });

    joined = j;

    ctx.store.set((state) => {
      state.live = {
        joined: true,
        key,
        role: 'listener',
        muted: true,
        session,
        hostTools: false,
        audioBlocked: false,
        connection: 'connecting',
      };
    });

    const answer = await j.client.connect(asSpeaker);

    if (!answer.ok) {
      joined = null;

      ctx.store.set((state) => {
        if (state.live.key === key)
          state.live = { joined: false, key: null, role: 'listener', muted: true };
      });

      // A remembered session can end without this tab hearing so ask which one is live now
      if (cached && answer.error === JOIN_REFUSALS['not_found']) {
        sessions.delete(key);
        return join(cid, rid, asSpeaker, true);
      }

      return answer;
    }

    applyReply(j, answer.value);
    sync();
    void refresh(j);

    const { settings, instance } = ctx.store.get();
    if (settings.captions && instance.transcription) j.client.captions(true);

    return ok(undefined);
  };

  const applyReply = (j: Joined, reply: JoinReply) => {
    applyState(j, reply);
    setRoom(j.cid, j.rid, (room) => {
      room.mode = reply.mode;
    });
    j.client.setMuted(true);
  };

  const findSession = async (cid: string, rid: string): Promise<string | null> => {
    const id = await roomId(cid, rid);

    if (!id) return null;

    const answer = await call(() => voiceLive(id));

    if (answer.status !== 200) {
      markEnded(cid, rid);
      return null;
    }

    const shown = await call(() => voiceShow(answer.data.id));
    const present = shown.status === 200 ? shown.data.participants.map((p) => p.user_id) : [];

    markLive(cid, rid, answer.data, present.length, present);

    return answer.data.id;
  };

  const inSession = async (
    request: (session: string, me: string) => Promise<{ status: number; data: unknown }>,
  ): Promise<Result> => {
    const me = ctx.store.get().me;

    if (!joined || !me) return fail(REFUSALS['not_here']!);

    const session = joined.session;

    return done(await call(() => request(session, me)));
  };

  // Which voice rooms are on air, so the sidebar and the bar show it without opening the room
  const follow = (communityId: string) =>
    ctx.watch(
      `community:${communityId}`,
      (realtime, topic) => {
        const slugs = (roomId: string) => {
          const cid = ctx.communitySlugs.get(communityId);
          const rid = ctx.roomsById.get(roomId)?.slug;
          return cid && rid ? { cid, rid } : null;
        };

        const started = realtime.onPush(topic, 'VoiceSessionStarted', (e) => {
          const at = slugs(e.room_id);
          if (!at) return;
          markLive(
            at.cid,
            at.rid,
            {
              id: e.session_id,
              community_id: e.community_id,
              room_id: e.room_id,
              mode: e.mode,
              topic: e.topic,
              host_id: e.host_id,
              started_at: new Date().toISOString(),
              ended_at: null,
              event_id: null,
              post_id: e.post_id,
              recording: false,
            },
            // Nobody is in it until someone joins, which VoiceAttendance then says
            0,
          );
        });

        // Being in the room when it ends takes you out too, so the bar never says you're on air
        const ended = realtime.onPush(topic, 'VoiceSessionEnded', (e) => {
          const at = slugs(e.room_id);
          if (!at) return;
          if (joined?.key === `${at.cid}/${at.rid}`) teardown('ended');
          else markEnded(at.cid, at.rid);
        });

        const counted = realtime.onPush(topic, 'VoiceAttendance', (e) => {
          const at = slugs(e.room_id);
          if (!at) return;

          setRoom(at.cid, at.rid, (room) => {
            room.listeners = e.people;
            room.present = [...e.user_ids];
          });
        });

        const recorded = realtime.onPush(topic, 'VoiceRecordingChanged', (e) => {
          const at = slugs(e.room_id);
          if (!at) return;

          setRoom(at.cid, at.rid, (room) => {
            room.recording = e.status === 'recording';
          });

          void loadRecordings(at.cid, at.rid, e.room_id);
        });

        const deleted = realtime.onPush(topic, 'VoiceRecordingDeleted', (e) =>
          dropRecording(e.recording_id),
        );

        const renamed = realtime.onPush(topic, 'VoiceRecordingRenamed', (e) =>
          retitle(e.recording_id, e.title),
        );

        return () => {
          started();
          ended();
          counted();
          recorded();
          deleted();
          renamed();
        };
      },
      'voice',
    );

  // After sign in, every live session in the communities joined, and their rooms followed from then on
  const loadLive = async (): Promise<Result> => {
    const answer = await call(() => voiceLiveIndex());

    if (answer.status !== 200) return failed(answer);

    for (const session of answer.data) {
      const cid = ctx.communitySlugs.get(session.community_id);
      const rid = ctx.roomsById.get(session.room_id)?.slug;
      if (cid && rid) markLive(cid, rid, session, session.people ?? 0);
    }

    for (const communityId of ctx.communitySlugs.keys()) follow(communityId);

    return ok(undefined);
  };

  const load = {
    voice: async (cid: string, rid: string): Promise<Result> => {
      await ctx.sessionLoaded;

      const id = await roomId(cid, rid);

      if (!id) return fail('That room does not exist.');

      if (ctx.needsDetail(cid)) await loadCommunity(cid);

      const communityId = ctx.communityIds.get(cid);

      if (communityId) follow(communityId);

      void loadRecordings(cid, rid, id);
      if (joined?.key === `${cid}/${rid}`) return ok(undefined);
      await findSession(cid, rid);

      return ok(undefined);
    },
  } satisfies Partial<HearthGateway['load']>;

  const voice: Omit<HearthGateway['voice'], 'editTranscriptLine'> = {
    join,

    renameRecording: async (id: string, title: string) => {
      const answer = await call(() => recordingUpdate(id, { title }));

      if (answer.status !== 200) return failed(answer);

      retitle(id, answer.data.title ?? title);

      return ok(undefined);
    },

    deleteRecording: async (id: string) => {
      const answer = await call(() => recordingDelete(id));

      if (answer.status !== 204) return failed(answer);

      dropRecording(id);

      return ok(undefined);
    },

    moreRecordings: async (cid: string, rid: string) => {
      const id = await roomId(cid, rid);
      const after = ctx.store
        .get()
        .communities[cid]?.voice.find((v) => v.id === rid)?.recordingsAfter;

      if (id && after) await loadRecordings(cid, rid, id, after);
    },

    start: async (cid: string, rid: string, mode: VoiceMode, topic: string) => {
      const id = await roomId(cid, rid);

      if (!id) return fail('That room does not exist.');

      const answer = await call(() => voiceCreate(id, { mode, topic: topic.trim() || null }));

      if (answer.status !== 200 && answer.status !== 201) return refused(answer);

      markLive(cid, rid, answer.data, 0);

      return join(cid, rid, true);
    },

    leave: async () => {
      cancelRejoin();
      teardown(null);
    },

    end: async (cid: string, rid: string) => {
      const session = sessions.get(`${cid}/${rid}`);

      if (!session) return fail(REFUSALS['not_live']!);

      // The ended event can come back before the answer, and the one ending it already knows
      ending = `${cid}/${rid}`;
      const result = done(await call(() => voiceEndSession(session)));
      ending = null;

      if (!result.ok) return result;

      if (joined?.key === `${cid}/${rid}`) teardown('ended', true);
      else markEnded(cid, rid);

      useVoiceSession.getState().drop(`${cid}/${rid}`);

      return ok(undefined);
    },

    toggleMute: async () => {
      const live = ctx.store.get().live;

      if (!joined || !mayTalk(ctx.store.get())) return fail(REFUSALS['not_on_stage']!);

      const muted = !live.muted;

      joined.client.setMuted(muted);

      ctx.store.set((state) => {
        state.live.muted = muted;
      });

      const result = await inSession((session) => voiceMute(session, { muted }));

      if (!result.ok) {
        joined?.client.setMuted(!muted);
        ctx.store.set((state) => {
          state.live.muted = !muted;
        });
      }

      return result;
    },

    setRole: async (role: AppState['live']['role']) =>
      role === 'listener'
        ? inSession((session, me) => voiceDemote(session, me))
        : Promise.resolve(ok(undefined)),

    raiseHand: (raised: boolean) => inSession((session) => voiceHand(session, { raised })),
    invite: (who: string) => inSession((session) => voiceInvite(session, who)),
    demote: (who: string) => inSession((session) => voiceDemote(session, who)),
    serverMute: (who: string, muted: boolean) =>
      inSession((session) => voiceServerMute(session, who, { muted })),
    disconnect: (who: string) => inSession((session) => voiceDisconnect(session, who)),

    share: async (screen: MediaStream | null) => {
      if (!joined) return fail(REFUSALS['not_here']!);

      const client = joined.client;

      if (!screen) {
        await client.setScreen(null);
        return inSession((session) => voiceStopShare(session));
      }

      await client.setScreen(screen);

      const result = await inSession((session) => voiceStartShare(session));

      if (!result.ok) await client.setScreen(null);

      return result;
    },

    record: (on: boolean) =>
      inSession((session) => (on ? voiceStartRecording(session) : voiceStopRecording(session))),

    react: (emoji) => joined?.client.react(emoji),
    setCaptions: (on) => joined?.client.captions(on),
    resumeAudio: () => void joined?.client.resumeAudio(),
  };

  return { load, voice, loadLive };
}

type VoiceRoomDraft = AppState['communities'][string]['voice'][number];
