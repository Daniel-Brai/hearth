import type {
  ArchivedRoom,
  Ban,
  Community,
  CommunityEvent,
  CommunityRequest,
  Direct,
  Draft,
  Instance,
  InviteEmail,
  InviteLink,
  MyInvite,
  LiveState,
  Message,
  ModLogEntry,
  Notification,
  Person,
  Post,
  ProfileActivity,
  QueueItem,
  Recording,
  Role,
  RoomSettings,
  Template,
  Transcript,
  UserSettings,
} from './types';

export type AppState = {
  me: string | null;
  people: Record<string, Person>;
  // Which joined communities each person shares with me, by slug
  sharedCommunities: Record<string, string[]>;
  communities: Record<string, Community>;
  roomSettings: Record<string, RoomSettings>;
  archivedRooms: Record<string, ArchivedRoom[]>;
  posts: Post[];
  activity: Record<string, ProfileActivity>;
  transcripts: Record<string, Transcript>;
  recordings: Record<string, Recording>;
  chats: Record<string, Message[]>;
  directs: Direct[];
  queue: QueueItem[];
  queueCounts: Record<string, number>;
  modlog: ModLogEntry[];
  bans: Ban[];
  roles: Role[];
  invites: { links: InviteLink[]; emails: InviteEmail[]; mine: MyInvite[] };
  notifications: Notification[];
  notificationsAfter: string | null;
  notificationsUnreadBeyond: number;
  settings: UserSettings;
  instance: Instance;
  events: CommunityEvent[];
  communityRequests: CommunityRequest[];
  templates: Template[];
  drafts: Record<string, Draft>;
  live: LiveState;
  seq: number;
};
