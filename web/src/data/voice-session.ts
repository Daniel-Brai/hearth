import { create } from 'zustand';

const CAPTIONS_KEPT = 200;

type Caption = {
  readonly id: string;
  readonly who: string;
  readonly t: string;
  readonly text: string;
};

type Float = {
  readonly id: string;
  readonly emoji: string;
  readonly x: number;
  readonly by: string | null;
};

const MAX_FLOATS = 8;
const FLOAT_MS = 1900;

type Share = { readonly by: string };

type RecordingState =
  { readonly on: false } | { readonly on: true; readonly by: string; readonly startedAt: number };

export type RoomSession = {
  readonly speakers: readonly string[];
  readonly muted: readonly string[];
  readonly locked: readonly string[];
  readonly speaking: readonly string[];
  readonly selfTalking: boolean;
  readonly listeners: readonly string[];
  readonly hands: readonly string[];
  readonly handUp: boolean;
  readonly captions: readonly Caption[];
  readonly floats: readonly Float[];
  readonly share: Share | null;
  readonly recording: RecordingState;
};

export type SessionAction =
  | { readonly type: 'seed'; readonly host: string | null }
  | { readonly type: 'hand-toggled' }
  | { readonly type: 'hand-raised'; readonly id: string }
  | { readonly type: 'hand-lowered'; readonly id: string }
  | { readonly type: 'invited'; readonly id: string }
  | { readonly type: 'demoted'; readonly id: string }
  | { readonly type: 'disconnected'; readonly id: string }
  | { readonly type: 'server-muted'; readonly id: string }
  | { readonly type: 'server-mute-lifted'; readonly id: string }
  | { readonly type: 'opened-up' }
  | { readonly type: 'speaking'; readonly ids: readonly string[] }
  | { readonly type: 'self-talking'; readonly talking: boolean }
  | { readonly type: 'caption'; readonly caption: Caption }
  | { readonly type: 'float-added'; readonly float: Float }
  | { readonly type: 'float-removed'; readonly id: string }
  | { readonly type: 'share-started'; readonly by: string }
  | { readonly type: 'share-stopped' }
  | { readonly type: 'recording-started'; readonly by: string; readonly startedAt: number }
  | { readonly type: 'recording-stopped' }
  | { readonly type: 'left' }
  | { readonly type: 'synced'; readonly snapshot: ServerSnapshot };

export type ServerSnapshot = Pick<
  RoomSession,
  | 'speakers'
  | 'listeners'
  | 'hands'
  | 'muted'
  | 'locked'
  | 'speaking'
  | 'share'
  | 'handUp'
  | 'recording'
>;

const EMPTY_SESSION: RoomSession = {
  speakers: [],
  muted: [],
  locked: [],
  speaking: [],
  selfTalking: false,
  listeners: [],
  hands: [],
  handUp: false,
  captions: [],
  floats: [],
  share: null,
  recording: { on: false },
};

const without = (list: readonly string[], id: string) => list.filter((x) => x !== id);

const withId = (list: readonly string[], id: string) => (list.includes(id) ? list : [...list, id]);

function reduceSession(s: RoomSession, a: SessionAction): RoomSession {
  switch (a.type) {
    case 'seed':
      return a.host ? { ...s, speakers: withId(s.speakers, a.host) } : s;

    case 'hand-toggled':
      return { ...s, handUp: !s.handUp };

    case 'hand-raised':
      return { ...s, hands: withId(s.hands, a.id) };

    case 'hand-lowered':
      return { ...s, hands: without(s.hands, a.id) };

    case 'invited':
      return {
        ...s,
        hands: without(s.hands, a.id),
        listeners: without(s.listeners, a.id),
        speakers: withId(s.speakers, a.id),
        muted: without(s.muted, a.id),
      };

    case 'demoted':
      return {
        ...s,
        speakers: without(s.speakers, a.id),
        speaking: without(s.speaking, a.id),
        listeners: [a.id, ...without(s.listeners, a.id)],
      };

    case 'disconnected':
      return {
        ...s,
        speakers: without(s.speakers, a.id),
        listeners: without(s.listeners, a.id),
        hands: without(s.hands, a.id),
        speaking: without(s.speaking, a.id),
        locked: without(s.locked, a.id),
        muted: without(s.muted, a.id),
      };

    case 'server-muted':
      return {
        ...s,
        locked: withId(s.locked, a.id),
        muted: withId(s.muted, a.id),
        speaking: without(s.speaking, a.id),
      };

    case 'server-mute-lifted':
      return { ...s, locked: without(s.locked, a.id) };

    case 'opened-up':
      return {
        ...s,
        speakers: s.listeners.reduce((all, id) => withId(all, id), s.speakers),
        muted: s.listeners.reduce((all, id) => withId(all, id), s.muted),
        listeners: [],
        hands: [],
        handUp: false,
      };

    case 'speaking':
      return { ...s, speaking: a.ids };
    case 'self-talking':
      return { ...s, selfTalking: a.talking };

    // Only the latest lines are kept, so a long room never grows the list without end
    case 'caption':
      return { ...s, captions: [...s.captions, a.caption].slice(-CAPTIONS_KEPT) };

    case 'float-added':
      return { ...s, floats: [...s.floats, a.float].slice(-MAX_FLOATS) };

    case 'float-removed':
      return { ...s, floats: s.floats.filter((f) => f.id !== a.id) };

    case 'share-started':
      return { ...s, share: { by: a.by } };

    case 'share-stopped':
      return { ...s, share: null };

    case 'recording-started':
      return { ...s, recording: { on: true, by: a.by, startedAt: a.startedAt } };

    case 'recording-stopped':
      return { ...s, recording: { on: false } };

    case 'left':
      return { ...s, handUp: false, share: null, recording: { on: false } };

    case 'synced':
      return { ...s, ...a.snapshot };
  }
}

type SessionsState = {
  readonly rooms: Readonly<Record<string, RoomSession>>;
  readonly dispatch: (key: string, action: SessionAction) => void;
  readonly drop: (key: string) => void;
};

export const useVoiceSession = create<SessionsState>((set) => ({
  rooms: {},

  dispatch: (key, action) =>
    set((state) => ({
      rooms: { ...state.rooms, [key]: reduceSession(state.rooms[key] ?? EMPTY_SESSION, action) },
    })),

  drop: (key) =>
    set((state) => {
      const rooms = { ...state.rooms };

      delete rooms[key];

      return { rooms };
    }),
}));

export const useRoomSession = (key: string): RoomSession =>
  useVoiceSession((s) => s.rooms[key] ?? EMPTY_SESSION);

export const getRoomSession = (key: string): RoomSession =>
  useVoiceSession.getState().rooms[key] ?? EMPTY_SESSION;

export function floatReaction(key: string, by: string | null, emoji: string) {
  const { dispatch } = useVoiceSession.getState();
  const id = crypto.randomUUID();

  dispatch(key, { type: 'float-added', float: { id, emoji, by, x: 10 + Math.random() * 80 } });
  setTimeout(() => dispatch(key, { type: 'float-removed', id }), FLOAT_MS);
}
