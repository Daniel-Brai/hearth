import type { Audience } from '@/domain/audience';
import type { AppState } from '@/domain/app-state';
import type {
  Attachment,
  CommunityEvent,
  EventRepeat,
  EventWhere,
  Hue,
  InviteLink,
  ModerationLevel,
  Permission,
  Post,
  PostKind,
  QueueItem,
  Reply,
  ReportReason,
  RoomAccess,
  RoomSettings,
  UserSettings,
  Visibility,
  VoiceMode,
} from '@/domain/types';

export type Result<T = void> = { ok: true; value: T } | { ok: false; error: string };

export const ok = <T>(value: T): Result<T> => ({ ok: true, value });
export const fail = (error: string): Result<never> => ({ ok: false, error });

// Changing email needs a fresh sign in so the screen offers one with this message
export const SIGN_IN_AGAIN = 'To change your email, sign in again first.';

export type PushStatus = 'on' | 'off' | 'blocked' | 'unsupported';

export type CommunitySpec = {
  name: string;
  tagline: string;
  description?: string | undefined;
  hue: Hue;
  audience: Audience;
  logo: string | null;
  template: string;
  note?: string | undefined;
};

export type CommunityPatch = {
  name: string;
  tagline: string;
  intro: string;
  logo: string | null;
  banner: string | null;
  hue: Hue;
  links: { label: string; url: string }[];
  kinds: PostKind[];
  categories: string[];
  moderation: ModerationLevel;
  audience: Audience;
};

export type EventSpec = {
  title: string;
  desc: string;
  start: string;
  mins: number;
  repeat: EventRepeat;
  where: EventWhere;
  talk?: VoiceMode;
  notify?: boolean;
};

export type ProfileSpec = {
  name: string;
  photo: string | null;
  bio: string;
  pronouns: string;
  location: string;
  links: { url: string; label: string }[];
  private: boolean;
  presence: Visibility;
  photoVis: Visibility;
  commsVis: 'common' | 'everyone' | 'nobody';
};

export type ProviderReturn =
  | { kind: 'signed-in' }
  | {
      kind: 'sign-up';
      via: 'Google' | 'GitHub';
      token: string;
      name: string | null;
      username: string | null;
    }
  | { kind: 'failed'; via: 'Google' | 'GitHub'; error: string };

export type PostPatch = {
  title: string;
  body: string;
  kind: string;
  files: readonly Attachment[];
};

export type ReplyPatch = { body: string; files: readonly Attachment[] };

export type SignupSpec = {
  email: string | null;
  name: string;
  username: string;
  private: boolean;
  photo: string | null;
};

type ChatCommand = {
  cmd: string;
  args: string;
  desc: string;
  ok: boolean;
  reason?: string | undefined;
  icon: string;
};

type ReportSpec = {
  c: string;
  r?: string | null | undefined;
  kind: QueueItem['kind'];
  id: string;
  reason: ReportReason;
  note?: string | null | undefined;
  who: string;
  where: string;
  text: string;
  dm?: boolean;
};

export type ContentRef = {
  c: string;
  kind: QueueItem['kind'];
  id: string;
  postId?: string | null | undefined;
  key?: string | null | undefined;
};

type BanSpec = { c: string; username: string; reason: string; until: string };

export type LinkOptions = { expires: string; max: string; role: string };

export interface HearthGateway {
  readonly load: {
    session(): Promise<Result>;
    home(): Promise<Result>;
    compose(): Promise<Result>;
    community(cid: string): Promise<Result>;
    post(id: string): Promise<Result>;
    chat(key: string): Promise<Result>;
    voice(cid: string, room: string): Promise<Result>;
    events(cid: string | null): Promise<Result>;
    people(): Promise<Result>;
    profile(handle: string): Promise<Result>;
    activity(handle: string, tab: 'posts' | 'replies', more?: boolean): Promise<Result>;
    mentionable(cid: string, query: string): Promise<Result>;
    moderation(cid: string): Promise<Result>;
    moderationLog(cid: string): Promise<Result>;
    reportedMessages(): Promise<Result>;
    roles(cid: string): Promise<Result>;
    invites(cid: string): Promise<Result>;
    invite(code: string): Promise<Result>;
    myInvites(): Promise<Result>;
    archivedRooms(cid: string): Promise<Result>;
    requests(): Promise<Result>;
    transcript(id: string): Promise<Result>;
    instanceUpdate(): Promise<Result>;
    screening(): Promise<Result>;
  };

  readonly session: {
    requestCode(email: string): Promise<Result<{ known: boolean }>>;
    verifyCode(email: string, code: string): Promise<Result<{ known: boolean }>>;
    usernameAvailable(username: string): Promise<Result<boolean>>;
    // Null when the browser is leaving for the provider's site
    oauth(
      provider: 'Google' | 'GitHub',
      returnTo: string,
    ): Promise<Result<{ name: string; username: string } | null>>;
    providerReturn(): ProviderReturn | null;
    completeSignup(spec: SignupSpec): Promise<Result>;
    signOut(): void;
    changeEmail(email: string): Promise<Result>;
    confirmEmail(code: string): Promise<Result>;
    undoEmailChange(token: string): Promise<Result>;
    inviteByCode(code: string): InviteLink | null;
    acceptInvite(code: string): Promise<Result<{ community: string }>>;
  };

  readonly settings: {
    update(patch: Partial<UserSettings>): void;
    setKeys(keys: Record<string, string>): void;
    setInstanceCreation(mode: AppState['instance']['communityCreation']): Promise<Result>;
    checkForUpdate(): Promise<Result>;
    finishTour(): void;
    pushStatus(): Promise<PushStatus>;
    setPush(on: boolean): Promise<Result>;
  };

  readonly profile: {
    save(spec: ProfileSpec): Promise<Result>;
    removePhoto(): void;
    setVisibility(key: 'presence' | 'photo', v: Visibility): void;
  };

  readonly communities: {
    join(cid: string): Result;
    leave(cid: string): void;
    create(
      spec: CommunitySpec,
    ): Promise<Result<{ community?: string | undefined; requested?: boolean | undefined }>>;
    update(cid: string, patch: CommunityPatch): Promise<Result>;
    requestTransferCode(cid: string): Promise<Result>;
    transferOwnership(cid: string, to: string, code: string): Promise<Result>;
    // The address a new community with this name would get, null when it can't be asked
    slugFor(name: string): Promise<string | null>;
    decideRequest(
      id: string,
      decision: 'approved' | 'declined',
    ): Promise<Result<{ community?: string | undefined }>>;
  };

  readonly rooms: {
    settings(key: string): RoomSettings;
    updateSettings(key: string, patch: Partial<RoomSettings>): void;
    setModeration(cid: string, rid: string, level: ModerationLevel): Promise<Result>;
    rename(cid: string, from: string, to: string): Promise<Result<{ id: string }>>;
    create(
      cid: string,
      spec: {
        type: 'text' | 'voice';
        name: string;
        topic: string;
        access?: RoomAccess;
        roleIds?: string[];
      },
    ): Promise<Result<{ id: string }>>;
    setAccess(cid: string, rid: string, access: RoomAccess, roleIds: string[]): Promise<Result>;
    archive(cid: string, id: string): Promise<Result>;
    restore(cid: string, id: string): Promise<Result>;
    destroy(cid: string, id: string): Promise<Result>;
    markRead(cid: string, rid: string): void;
  };

  readonly posts: {
    markSeen(id: string): Promise<Result>;
    markCommunitySeen(cid: string): Promise<Result>;
    markAllSeen(): Promise<Result>;
    toggleHelpful(id: string): Promise<Result>;
    toggleReplyHelpful(postId: string, replyId: string): Promise<Result>;
    togglePin(id: string): Promise<Result>;
    toggleLock(id: string): Promise<Result>;
    toggleWatch(id: string): Promise<Result>;
    toggleBoost(id: string, emoji: string): Promise<Result>;
    hidePreview(id: string): Promise<Result>;
    loadReplies(postId: string, parent: string): Promise<Result>;
    create(spec: {
      c: string;
      kind: string;
      title: string;
      body: string;
      files?: Attachment[];
    }): Promise<Result<{ post: Post }>>;
    edit(id: string, patch: PostPatch): Promise<Result>;
    remove(id: string): Promise<Result>;
    toggleAnswer(postId: string, replyId: string): Promise<Result>;
    reply(
      postId: string,
      spec: { parent: string | null; body: string; files?: Attachment[] },
    ): Promise<Result<{ reply: Reply }>>;
    editReply(postId: string, replyId: string, patch: ReplyPatch): Promise<Result>;
    removeReply(postId: string, replyId: string): Promise<Result>;
    startLive(postId: string): Promise<Result<{ room: string }>>;
    saveDraft(cid: string, draft: { title: string; body: string; kind: string }): Promise<Result>;
    discardDraft(cid: string): Promise<Result>;
  };

  readonly chat: {
    open(key: string): void;
    openDm(who: string): void;
    send(
      key: string,
      text: string,
      opts?: { files?: Attachment[]; parent?: string | null },
    ): Result<{ sound?: string }>;
    commands(key: string): ChatCommand[];
    edit(key: string, id: string, patch: { text: string; files: readonly Attachment[] }): Result;
    remove(key: string, id: string): void;
    toggleBoost(key: string, id: string, emoji: string): void;
    hidePreview(key: string, id: string): void;
    loadReplies(key: string, parent: string): Promise<Result>;
    promote(
      key: string,
      ids: string[],
      spec: { title: string; kind: string },
    ): Promise<Result<{ post: Post }>>;
  };

  readonly voice: {
    join(cid: string, rid: string, asSpeaker: boolean): Promise<Result>;
    start(cid: string, rid: string, mode: VoiceMode, topic: string): Promise<Result>;
    leave(): Promise<void>;
    end(cid: string, rid: string): Promise<Result>;
    toggleMute(): Promise<Result>;
    setRole(role: AppState['live']['role']): Promise<Result>;
    raiseHand(raised: boolean): Promise<Result>;
    invite(who: string): Promise<Result>;
    demote(who: string): Promise<Result>;
    serverMute(who: string, muted: boolean): Promise<Result>;
    disconnect(who: string): Promise<Result>;
    // screen is captured by the caller during the click
    share(screen: MediaStream | null): Promise<Result>;
    record(on: boolean): Promise<Result>;
    moreRecordings(cid: string, rid: string): Promise<void>;
    renameRecording(id: string, title: string): Promise<Result>;
    deleteRecording(id: string): Promise<Result>;
    editTranscriptLine(sessionId: string, lineId: string, text: string): Promise<Result>;
    react(emoji: string): void;
    setCaptions(on: boolean): void;
    resumeAudio(): void;
  };

  readonly events: {
    toggleInterest(id: string): void;
    save(
      cid: string,
      id: string | null,
      spec: EventSpec,
    ): Promise<Result<{ event: CommunityEvent }>>;
    cancel(id: string): void;
    restore(id: string): void;
    remove(id: string): void;
    loadRecordings(id: string): void;
  };

  readonly moderation: {
    keep(id: string): Promise<Result>;
    remove(id: string, reason: string): Promise<Result>;
    undo(id: string): Promise<Result>;
    banFromQueue(id: string, reason: string): Promise<Result>;
    report(spec: ReportSpec): Promise<Result<{ queued: boolean }>>;
    removeContent(ref: ContentRef, reason: string): Promise<Result>;
    restoreContent(ref: ContentRef): Promise<Result>;
    ban(spec: BanSpec): Promise<Result>;
    unban(id: string): Promise<Result>;
  };

  readonly roles: {
    create(cid: string, name: string): Promise<Result<{ id: string }>>;
    remove(cid: string, id: string): Promise<Result>;
    setPermission(cid: string, id: string, perm: Permission, on: boolean): Promise<Result>;
    addMember(cid: string, id: string, who: string): Promise<Result>;
    removeMember(cid: string, id: string, who: string): Promise<Result>;
  };

  readonly invites: {
    current(cid: string): InviteLink | null;
    newLink(cid: string, opts: LinkOptions): Promise<Result>;
    updateLink(cid: string, opts: LinkOptions): Promise<Result>;
    sendEmails(
      cid: string,
      emails: { email: string; role: string }[],
      note: string | null,
    ): Promise<Result<{ count: number }>>;
    revokeEmail(id: string): void;
    decline(id: string): Promise<Result>;
    unreachable(emails: string[]): Promise<string[]>;
  };

  readonly notifications: {
    open(id: string): void;
    markAllRead(): void;
    loadEarlier(): Promise<void>;
  };
}
