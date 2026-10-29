import type { Audience } from './audience';
export type Hue =
  'ink' | 'blue' | 'violet' | 'purple' | 'pink' | 'red' | 'orange' | 'yellow' | 'green' | 'aqua';

type Tint = Hue | (string & {});

export type Visibility = 'everyone' | 'members' | 'nobody';
export type CommunitiesVisibility = 'common' | 'everyone' | 'nobody';

export type PersonLink = { url: string; label: string | null };

export type Person = {
  name: string;
  username: string;
  email?: string;
  hue: Hue;
  private: boolean;
  bio: string | null;
  pronouns?: string | null;
  helped: number;
  posts: number;
  answers: number;
  joined: string | null;
  location: string | null;
  links?: PersonLink[];
  lastSeen?: string;
  photo?: string | null;
  show?: { presence?: Visibility; photo?: Visibility; communities?: CommunitiesVisibility };
};

export type { Permission } from './permissions';

import type { Permission } from './permissions';

export type PostKind = {
  // The server's name for it, which stays when the kind is renamed. A new kind has none yet
  key?: string;
  name: string;
  icon: string;
  hue: Tint;
  hint: string;
  body: string;
  answers: boolean;
  mods: boolean;
  desc: string | null;
};

// A room for some roles lists them as role ids, sent only to people who manage rooms
export type RoomAccess = 'everyone' | 'roles';

export type Room = {
  id: string;
  name: string;
  unread: number;
  access?: RoomAccess;
  roleIds?: string[];
};

export type ArchivedRoom = {
  id: string;
  name: string;
  type: 'text' | 'voice';
  archivedAt: string;
};

export type VoiceMode = 'stage' | 'open';

export type VoiceRoom = {
  id: string;
  name: string;
  live: boolean;
  listeners: number;
  // Who is in the room, for the faces shown to someone outside it
  present?: string[];
  topic: string | null;
  host: string;
  postId: string | null;
  mode?: VoiceMode;
  recording?: boolean;
  access?: RoomAccess;
  roleIds?: string[];
  // Where the next page of the room's recordings starts, missing when there are no more
  recordingsAfter?: string | null;
};

export type ModerationLevel = 'full' | 'reports' | 'none';
export type CommunityVisibility = 'public' | 'invite';

export type Community = {
  name: string;
  hue: Hue;
  letter: string;
  logo: string | null;
  banner: string | null;
  tagline: string;
  intro: string | null;
  links: { label: string; url: string }[];
  members: number;
  online: number;
  joined: boolean;
  permissions: Permission[];
  visibility: CommunityVisibility;
  // Public means indexed when absent
  indexed?: boolean;
  // The exact value the server keeps, see domain/audience
  audience?: Audience;
  maintainer: string;
  welcome: string;
  rooms: Room[];
  voice: VoiceRoom[];
  summary: string | null;
  kinds: PostKind[];
  categories: string[];
  place: string | null;
  listed: boolean;
  verified: { type: string; label: string } | null;
  stats: { helpedWeek: number; answered: number; replyMins: number; ageDays: number };
  moderation?: ModerationLevel;
};

export type Boost = { e: string; n: number; mine: boolean };

export type AttachmentKind = 'image' | 'video' | 'file';

export type Attachment = {
  id: string;
  name: string;
  kind: AttachmentKind;
  size: number;
  width?: number | undefined;
  height?: number | undefined;
  durationMs?: number | undefined;
  // Saves the file under its name, where `url` would open it in the browser
  download?: string | undefined;
} & ({ url: string; data?: undefined } | { data: string; url?: undefined });

export const attachmentSrc = (f: Attachment): string => f.data ?? f.url;

export const attachmentDownload = (f: Attachment): string => f.download ?? attachmentSrc(f);

export type Reply = {
  id: string;
  parent: string | null;
  who: string;
  age: string;
  at?: string;
  helpful: number;
  helpfulMine: boolean;
  body: string[];
  files?: Attachment[];
  edited?: boolean;
  removed?: boolean;
  moderated?: boolean;
  answerCounts?: AnswerCounts;
};

type AnswerCounts = { direct: number; total: number };

export type Post = {
  id: string;
  c: string;
  kind: string;
  title: string;
  author: string;
  age: string;
  at?: string;
  seen: boolean;
  pinned: boolean;
  watching: boolean;
  tags: string[];
  body: string[];
  helpful: number;
  helpfulMine: boolean;
  boosts: Boost[];
  answer: string | null;
  fromChat: { room: string; count: number } | null;
  transcript: string | null;
  replies: Reply[];
  files?: Attachment[];
  locked?: boolean;
  removed?: boolean;
  moderated?: boolean;
  pending?: boolean;
  reported?: boolean;
  inReview?: boolean;
  replyCount?: number;
  editedAt?: string | null | undefined;
};

// A page's own Open Graph data, with its image loaded straight from that site
export type LinkPreview = {
  url: string;
  site: string;
  title: string;
  desc: string | null;
  image: string | null;
};

export type Message = {
  id: string;
  who: string;
  text: string;
  time: string;
  day?: string;
  boosts: Boost[];
  files?: Attachment[];
  parent?: string | null;
  answerCounts?: AnswerCounts;
  edited?: boolean;
  previewHidden?: boolean;
  // Its @all came from someone allowed to ping everyone in the room
  mentionsAll?: boolean;
  system?: boolean;
  moderated?: boolean;
  promoted?: { id: string; title: string };
};

export type RoomSoundMode = 'everyone' | 'roles' | 'people';

export type RoomSettings = {
  topic: string | null;
  previews: boolean;
  moderation?: ModerationLevel;
  sounds: { enabled: boolean; mode: RoomSoundMode; roles: string[]; people: string[] };
};

export type EventRepeat = 'none' | 'daily' | 'weekly' | 'biweekly' | 'monthly';

export type EventWhere =
  | { type: 'voice'; room: string }
  | { type: 'chat'; room: string }
  | { type: 'link'; url: string; label?: string };

export type CommunityEvent = {
  id: string;
  c: string;
  title: string;
  start: string;
  mins: number;
  repeat: EventRepeat;
  where: EventWhere;
  talk?: VoiceMode;
  host: string;
  interested: string[];
  cancelled: boolean;
  desc: string | null;
};

export type NotificationKind =
  | 'reply'
  | 'mention'
  | 'live'
  | 'mod'
  | 'helpful'
  | 'dm'
  | 'answer'
  | 'event_scheduled'
  | 'event_reminder'
  | 'transcript'
  | 'invite';

type AuthoredReply = {
  id: string;
  postId: string;
  c: string;
  title: string;
  excerpt: string | null;
  helpful: number;
  age: string;
  answer: boolean;
};

export type ProfileActivity = {
  posts: string[];
  postsAfter: string | null;
  replies: AuthoredReply[];
  repliesAfter: string | null;
};

export type Notification = {
  id: string;
  kind: NotificationKind;
  who: string;
  text: string;
  target: string;
  href: string;
  age: string;
  read: boolean;
  dm?: boolean;
};

export type ReportReason =
  'spam' | 'harassment' | 'hate' | 'sexual' | 'violence' | 'off_topic' | 'other';

export type QueueReport = { reason: ReportReason; note: string | null; age: string };

export type QueueItem = {
  id: string;
  c: string;
  r?: string;
  kind: 'Post' | 'Reply' | 'Message';
  who: string;
  where: string;
  text: string;
  reason: string;
  score: number;
  status: 'pending' | 'kept' | 'removed' | 'dismissed';
  age: string;
  reported?: boolean;
  source?: 'automatic' | 'report' | 'instance';
  reports?: QueueReport[];
  subject?: { type: 'post' | 'reply' | 'message'; id: string; postId: string | null };
};

export type ModLogAction =
  | 'removed'
  | 'restored'
  | 'kept'
  | 'banned'
  | 'unbanned'
  | 'queued'
  | 'pinned'
  | 'locked'
  | 'changed'
  | 'server_muted'
  | 'server_mute_lifted'
  | 'disconnected'
  | 'moved_to_listeners';

export type ModLogEntry = {
  id: string;
  who: string;
  action: ModLogAction;
  text: string;
  reason: string | null;
  c: string;
  age: string;
};

export type Ban = {
  id: string;
  name: string;
  c: string;
  reason: string;
  by: string;
  age: string;
  until: string;
};

export type Role = {
  c: string;
  id: string;
  // The server's id for the role, which rooms use. Roles made without a server have none
  uid?: string;
  name: string;
  hue: Hue;
  members: string[];
  locked?: boolean;
  // A locked role like the owner may do everything
  permissions: Permission[];
};

export type InviteLink = {
  code: string;
  c: string;
  expires: string;
  max: string;
  role: string;
  uses: number;
  created: string;
  by: string;
  revoked: boolean;
};

export type MyInvite = {
  id: string;
  code: string;
  c: string;
  by: string | null;
  role: string;
  age: string;
};

export type InviteEmail = {
  id: string;
  email: string;
  c: string;
  role: string;
  age: string;
  status: 'pending' | 'joined' | 'declined' | 'revoked';
};

export type CommunityRequest = {
  id: string;
  by: string;
  name: string;
  tagline: string | null;
  hue: Hue;
  visibility: CommunityVisibility;
  template: string;
  note: string | null;
  status: 'pending' | 'approved' | 'declined';
  age: string;
  decided?: string;
  communityId?: string;
};

type TranscriptLine = {
  who: string;
  t: string;
  text: string;
  filler?: boolean;
  id?: string;
  editable?: boolean;
};

export type TranscriptStatus = 'queued' | 'transcribing' | 'ready' | 'failed';

export type Transcript = {
  id: string;
  postId: string;
  c: string;
  room: string;
  title: string;
  date: string;
  duration: string;
  speakers: string[];
  recording: string | null;
  lines: TranscriptLine[];
  status?: TranscriptStatus;
};

export type RecordingStatus = 'recording' | 'processing' | 'ready' | 'failed';

export type Recording = {
  id: string;
  postId: string;
  c: string;
  room: string;
  title: string;
  duration: string;
  date: string;
  by: string;
  screen: boolean;
  real: boolean;
  url?: string;
  download?: string;
  // Missing means ready
  status?: RecordingStatus;
  failure?: string | null;
  poster?: string | null;
  seconds?: number;
  rid?: string;
  eventId?: string;
  startedAt?: string;
  speakers?: { who: string; url: string }[];
};

export type Direct = { who: string; unread: number | boolean; age?: string };

export type ThemePreference = 'light' | 'dark' | 'system';
export type DigestChoice = 'daily' | 'weekly' | 'never';

export type UserSettings = {
  theme: ThemePreference;
  sounds: boolean;
  uiSounds: boolean;
  haptics: boolean;
  notifyReplies: boolean;
  notifyMentions: boolean;
  notifyLive: boolean;
  digest: DigestChoice;
  compact: boolean;
  sidebarCollapsed: boolean;
  captions: boolean;
  keys: Record<string, string>;
  tourDone: boolean;
};

export type CommunityCreation = 'admins' | 'request' | 'anyone';

type SignInMethod = 'email' | 'google' | 'github';

export type InstanceUpdate = {
  current: string;
  latest: string | null;
  available: boolean;
  enabled: boolean;
  releaseName: string | null;
  releaseUrl: string | null;
  publishedAt: string | null;
  notes: string | null;
  checkedAt: string | null;
};

export type Instance = {
  name: string;
  signIn: SignInMethod[];
  logo?: string | null;
  icon?: string | null;
  isAdmin: boolean;
  communityCreation: CommunityCreation;
  aiScreening: boolean;
  transcription: boolean;
  voice: boolean;
  recording: boolean;
  maxAttachments: number;
  // The VAPID key devices subscribe with, null when the server sends no pushes
  pushKey: string | null;
  // Null until loaded, and for anyone who isn't an instance admin
  update: InstanceUpdate | null;
  screening: ScreeningSummary | null;
};

export type ScreeningDay = {
  day: string;
  screened: number;
  held: number;
  kept: number;
  removed: number;
};

// Covers the last `period` days. Days with no screening are left out, newest first
export type ScreeningSummary = { period: number; threshold: number; days: ScreeningDay[] };

export type LiveState = {
  joined: boolean;
  key: string | null;
  role: 'host' | 'speaker' | 'listener';
  muted: boolean;
  session?: string | null;
  hostTools?: boolean;
  audioBlocked?: boolean;
  connection?: 'connecting' | 'connected' | 'reconnecting';
};

export type Draft = { title: string; body: string; kind: string; updatedAt: string };

export type Category = { id: string; label: string; icon: string };

export type Template = {
  id: string;
  label: string;
  icon: string;
  desc: string;
  category: string;
  kinds: string[];
  rooms: string[];
  voice: string | null;
  event: { title: string; days: number; mins: number; repeat: EventRepeat } | null;
  visibility?: CommunityVisibility;
  ph: { name: string; tagline: string };
};
