import { Socket } from 'phoenix';
import type { Channel } from 'phoenix';
import type {
  AnswerMarked,
  ContentRemoved,
  ContentRestored,
  EventCancelled,
  EventScheduled,
  EventUpdated,
  MediaFailed,
  MediaReady,
  MemberJoined,
  MemberLeft,
  MessageCreated,
  MessageEdited,
  MessageReacted,
  MessageRemoved,
  NotificationCreated,
  PostCreated,
  PostReacted,
  ReplyCreated,
  RoomActivity,
  RoomChanged,
  TranscriptReady,
  VoiceAttendance,
  VoiceCaption,
  VoiceParticipantChanged,
  VoiceSessionEnded,
  VoiceSessionStarted,
  VoiceShareChanged,
  VoiceSpeakingChanged,
  VoiceReaction,
  VoiceRecordingChanged,
  VoiceRecordingDeleted,
  VoiceRecordingRenamed,
} from '@/generated/schemas';
import { apiBaseUrl } from './custom-fetch';
import { accessToken, onAccessToken } from './session-token';

export type ChannelEvents = {
  MessageCreated: MessageCreated;
  MessageEdited: MessageEdited;
  MessageReacted: MessageReacted;
  MessageRemoved: MessageRemoved;
  ContentRemoved: ContentRemoved;
  ContentRestored: ContentRestored;
  PostCreated: PostCreated;
  PostReacted: PostReacted;
  ReplyCreated: ReplyCreated;
  AnswerMarked: AnswerMarked;
  MemberJoined: MemberJoined;
  MemberLeft: MemberLeft;
  RoomChanged: RoomChanged;
  RoomActivity: RoomActivity;
  MediaReady: MediaReady;
  MediaFailed: MediaFailed;
  EventScheduled: EventScheduled;
  EventUpdated: EventUpdated;
  EventCancelled: EventCancelled;
  NotificationCreated: NotificationCreated;
  VoiceSessionStarted: VoiceSessionStarted;
  VoiceSessionEnded: VoiceSessionEnded;
  VoiceAttendance: VoiceAttendance;
  VoiceRecordingChanged: VoiceRecordingChanged;
  VoiceRecordingDeleted: VoiceRecordingDeleted;
  VoiceRecordingRenamed: VoiceRecordingRenamed;
  TranscriptReady: TranscriptReady;
};

export type VoiceEvents = {
  VoiceParticipantChanged: VoiceParticipantChanged;
  VoiceShareChanged: VoiceShareChanged;
  VoiceSpeakingChanged: VoiceSpeakingChanged;
  VoiceSessionEnded: VoiceSessionEnded;
  VoiceReaction: VoiceReaction;
  VoiceCaption: VoiceCaption;
  VoiceRecordingChanged: VoiceRecordingChanged;
};

export type ChannelEvent = keyof ChannelEvents;

export type Topic =
  | `user:${string}`
  | `community:${string}`
  | `room:${string}`
  | `conversation:${string}`
  | `post:${string}`;

type Joined = { channel: Channel; count: number };

const socketUrl = () => {
  const url = new URL('/socket', apiBaseUrl());
  url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';

  return url.toString();
};

// The token goes as the socket's auth so it never appears in a URL
export class Realtime {
  private readonly socket = new Socket(socketUrl(), { authToken: () => accessToken() ?? '' });
  private readonly joined = new Map<Topic, Joined>();

  constructor() {
    onAccessToken((token) => (token ? this.socket.connect() : this.close()));
    if (accessToken()) this.socket.connect();
  }

  onPush<E extends ChannelEvent>(
    topic: Topic,
    event: E,
    handler: (payload: ChannelEvents[E]) => void,
  ): () => void {
    const entry = this.join(topic);
    const ref = entry.channel.on(event, handler);

    return () => {
      entry.channel.off(event, ref);
      this.release(topic);
    };
  }

  private join(topic: Topic): Joined {
    const existing = this.joined.get(topic);

    if (existing) {
      existing.count += 1;
      return existing;
    }

    const entry = { channel: this.socket.channel(topic), count: 1 };

    entry.channel.join();
    this.joined.set(topic, entry);

    return entry;
  }

  private release(topic: Topic) {
    const entry = this.joined.get(topic);

    if (!entry) return;

    entry.count -= 1;
    if (entry.count > 0) return;

    entry.channel.leave();
    this.joined.delete(topic);
  }

  // Joining one topic twice on a socket closes the first so a voice session gets its own channel
  open(topic: `voice:${string}`, params: Record<string, unknown>): Channel {
    return this.socket.channel(topic, params);
  }

  private close() {
    for (const { channel } of this.joined.values()) channel.leave();
    this.joined.clear();
    this.socket.disconnect();
  }
}

let realtime: Realtime | null = null;

export const getRealtime = (): Realtime => (realtime ??= new Realtime());
