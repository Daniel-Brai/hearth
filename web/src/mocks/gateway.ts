import type { AppState } from '@/domain/app-state';
import { nowTime } from '@/domain/format';
import {
  canDo,
  canRequestCommunity,
  canStartCommunity,
  community,
  displayName,
  handle,
  isHeld,
  mayTalk,
  isMod,
  isOwner,
  modLevel,
  modLevelText,
  person,
  personIdByHandle,
  postableKinds,
  reportsOn,
  rolesOf,
  soundAccess,
  roomAccess,
} from '@/domain/selectors';
import { stripPrefix } from '@/domain/links';
import { usernameProblem } from '@/domain/username';
import { extractTags } from '@/features/markdown/tags';
import type {
  Message,
  Attachment,
  Boost,
  CommunityEvent,
  ModerationLevel,
  ModLogAction,
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
import { KIND_LIB, ROOM_DEFAULTS, SOUNDS, TEMPLATES, TITLE_MAX } from '@/domain/catalog';
import type { Store } from '@/data/store';
import {
  floatReaction,
  getRoomSession,
  useVoiceSession,
  type SessionAction,
} from '@/data/voice-session';
import {
  fail,
  ok,
  type CommunityPatch,
  type CommunitySpec,
  type ContentRef,
  type EventSpec,
  type HearthGateway,
  type PostPatch,
  type PushStatus,
  type ReplyPatch,
  type ProfileSpec,
  type Result,
  type SignupSpec,
} from '@/data/gateway';
import { slugify } from '@/runtime/routes';
import { visibilityOf } from '@/domain/audience';
import { sfx } from '@/runtime/sounds';
import { profileActivity } from './activity';
import { rememberTourDone } from './tour-memory';
import { grantPermissions } from './permissions';
import { showVisibleRooms, type Offstage } from './private-rooms';

const SUBJECT_TYPE = { Post: 'post', Reply: 'reply', Message: 'message' } as const;

const SUBJECT_KIND = { post: 'Post', reply: 'Reply', message: 'Message' } as const;

const latency = (ms = 450) => new Promise<void>((r) => setTimeout(r, ms));
const loaded = () => Promise.resolve(ok(undefined));

const clone = <T>(o: T): T => structuredClone(o);

const PRIVATE_ROOM = "Messages in a private room can't become a post.";

export class MockGateway implements HearthGateway {
  private readonly store: Store;
  private readonly offstage: Offstage = new Map();

  constructor(store: Store) {
    this.store = store;
    store.onWrite((state) => {
      grantPermissions(state);
      showVisibleRooms(state, this.offstage);
    });
  }

  readonly load: HearthGateway['load'] = {
    session: loaded,
    home: loaded,
    compose: loaded,
    community: loaded,
    post: loaded,
    chat: loaded,
    // With no server to ask who is in a room, a live one shows its host there.
    // The stage draws you yourself, so only someone else's room is seeded
    voice: async (cid: string, rid: string) => {
      const state = this.state();
      const room = community(state, cid)?.voice.find((v) => v.id === rid);

      if (room?.live && room.host && room.host !== state.me)
        useVoiceSession.getState().dispatch(`${cid}/${rid}`, { type: 'seed', host: room.host });

      return ok(undefined);
    },
    events: loaded,
    people: loaded,
    profile: loaded,
    activity: async (handle: string) => {
      this.store.set((state) => {
        const id = personIdByHandle(state, handle);
        if (id) state.activity[id] = profileActivity(state, id);
      });
      return ok(undefined);
    },
    moderation: loaded,
    moderationLog: loaded,
    reportedMessages: loaded,
    roles: loaded,
    invites: loaded,
    invite: loaded,
    mentionable: loaded,
    myInvites: loaded,
    archivedRooms: loaded,
    requests: loaded,
    transcript: loaded,
    instanceUpdate: loaded,
    screening: loaded,
  };

  private state() {
    return this.store.get();
  }

  private me(): string {
    const me = this.state().me;
    if (!me) throw new Error('Signed out');
    return me;
  }

  private log(
    state: AppState,
    c: string,
    action: ModLogAction,
    text: string,
    reason: string | null = null,
  ) {
    state.modlog.unshift({
      id: this.store.nextId('l'),
      who: this.me(),
      action,
      text,
      reason,
      c,
      age: 'now',
    });
  }

  readonly session = {
    requestCode: async (email: string): Promise<Result<{ known: boolean }>> => {
      await latency(700);
      const known = Object.values(this.state().people).some(
        (p) => p.email?.toLowerCase() === email.toLowerCase(),
      );
      return ok({ known });
    },
    usernameAvailable: async (username: string): Promise<Result<boolean>> => {
      await latency(200);
      return ok(!Object.values(this.state().people).some((p) => p.username === username));
    },
    verifyCode: async (email: string, code: string): Promise<Result<{ known: boolean }>> => {
      await latency(700);
      if (code === '000000') return fail("That code didn't work. Try again or send a new one.");

      const known = Object.values(this.state().people).some(
        (p) => p.email?.toLowerCase() === email.toLowerCase(),
      );

      if (known) this.store.set((state) => (state.me = 'dan'));

      return ok({ known });
    },
    oauth: async (): Promise<Result<{ name: string; username: string } | null>> => {
      await latency(700);
      return ok({ name: 'Daniel Brai', username: 'daniel' });
    },
    providerReturn: () => null,
    completeSignup: async (spec: SignupSpec): Promise<Result> => {
      await latency(500);

      const problem = usernameProblem(this.state(), spec.username, 'dan');

      if (problem) return fail(problem);

      this.store.set((state) => {
        state.me = 'dan';

        const me = state.people.dan!;

        me.name = spec.name;
        me.username = spec.username;
        me.private = spec.private;
        if (spec.photo) me.photo = spec.photo;
        if (spec.email) me.email = spec.email.toLowerCase();
        state.settings.tourDone = false;
      });

      rememberTourDone(false);

      return ok(undefined);
    },
    signOut: () => this.store.set((state) => (state.me = null)),
    changeEmail: async (email: string): Promise<Result> =>
      email.includes('@') ? ok(undefined) : fail('Enter an email address'),
    confirmEmail: async (code: string): Promise<Result> => {
      if (code.length !== 6) return fail("That code didn't work. Check the email and try again.");

      return ok(undefined);
    },
    undoEmailChange: async (): Promise<Result> => ok(undefined),
    inviteByCode: (code: string) =>
      this.state().invites.links.find((l) => l.code === code && !l.revoked) ?? null,
    acceptInvite: (code: string): Promise<Result<{ community: string }>> => {
      const link = this.state().invites.links.find((l) => l.code === code && !l.revoked);

      if (!link) return Promise.resolve(fail('This invite link has expired or was revoked.'));

      this.store.set((state) => {
        const c = state.communities[link.c]!;
        link.uses += 1;

        if (!c.joined) {
          c.joined = true;
          c.members += 1;
        }
      });

      return Promise.resolve(ok({ community: link.c }));
    },
  };

  readonly settings = {
    update: (patch: Partial<UserSettings>) => {
      if (patch.tourDone !== undefined) rememberTourDone(patch.tourDone);
      // Like the server, captions can't be turned on where the instance doesn't transcribe
      const allowed =
        patch.captions && !this.state().instance.transcription
          ? { ...patch, captions: false }
          : patch;
      this.store.set((state) => Object.assign(state.settings, allowed));
    },
    setKeys: (keys: Record<string, string>) =>
      this.store.set((state) => (state.settings.keys = keys)),
    setInstanceCreation: (mode: AppState['instance']['communityCreation']): Promise<Result> => {
      if (!this.state().instance.isAdmin)
        return Promise.resolve(fail('Only instance admins can change this.'));

      this.store.set((state) => (state.instance.communityCreation = mode));
      return Promise.resolve(ok(undefined));
    },
    checkForUpdate: async (): Promise<Result> => {
      if (!this.state().instance.isAdmin)
        return fail('Only instance admins can check for updates.');

      await latency(900);

      this.store.set((state) => {
        if (state.instance.update) state.instance.update.checkedAt = new Date().toISOString();
      });

      return ok(undefined);
    },
    finishTour: () => {
      rememberTourDone(true);
      this.store.set((state) => (state.settings.tourDone = true));
    },
    pushStatus: async (): Promise<PushStatus> => 'unsupported',
    setPush: async (): Promise<Result> => fail('There is no server to send pushes.'),
  };

  readonly profile = {
    save: (spec: ProfileSpec): Promise<Result> => {
      this.store.set((state) => {
        const me = state.people[this.me()]!;
        Object.assign(me, {
          name: spec.name,
          photo: spec.photo,
          bio: spec.bio,
          pronouns: spec.pronouns,
          location: spec.location,
          links: spec.links,
          private: spec.private,
          show: { presence: spec.presence, photo: spec.photoVis, communities: spec.commsVis },
        });
      });
      return Promise.resolve(ok(undefined));
    },
    removePhoto: () => this.store.set((state) => (state.people[this.me()]!.photo = null)),
    setVisibility: (key: 'presence' | 'photo', v: Visibility) =>
      this.store.set((state) => {
        const me = state.people[this.me()]!;
        me.show = { presence: 'everyone', photo: 'everyone', ...me.show, [key]: v };
      }),
  };

  readonly communities = {
    join: (cid: string): Result => {
      const c = community(this.state(), cid);

      if (!c) return fail('That community does not exist.');
      if (c.joined) return ok(undefined);

      this.store.set((state) => {
        const x = state.communities[cid]!;
        x.joined = true;
        x.members += 1;
      });

      return ok(undefined);
    },
    leave: (cid: string) =>
      this.store.set((state) => {
        const x = state.communities[cid]!;
        x.joined = false;
        x.members -= 1;
      }),
    create: async (
      spec: CommunitySpec,
    ): Promise<Result<{ community?: string; requested?: boolean }>> => {
      await latency(700);

      const state = this.state();
      const asRequest = canRequestCommunity(state);

      if (!canStartCommunity(state) && !asRequest)
        return fail('Only the instance admin can start communities');

      if (!spec.name.trim()) return fail('Give the community a name');

      if (asRequest) {
        this.store.set((d) => {
          d.communityRequests.unshift({
            id: this.store.nextId('cr'),
            by: this.me(),
            status: 'pending',
            age: 'now',
            name: spec.name.trim(),
            tagline: spec.tagline.trim(),
            hue: spec.hue,
            visibility: visibilityOf(spec.audience),
            template: spec.template,
            note: spec.note?.trim() || null,
          });
        });
        return ok({ requested: true });
      }

      const slug = this.store.set((d) => buildCommunity(d, this.store, spec, this.me()));

      return ok({ community: slug });
    },
    update: async (cid: string, patch: CommunityPatch): Promise<Result> => {
      const state = this.state();

      if (!canDo(state, cid, 'community.update'))
        return fail("Your role here can't edit this community");

      if (!patch.name.trim()) return fail('Give the community a name');

      const names = patch.kinds.map((k) => k.name.trim().toLowerCase()).filter(Boolean);

      if (!names.length) return fail('Keep at least one kind of post');
      if (new Set(names).size !== names.length) return fail('Two kinds share a name');

      this.store.set((d) => {
        const c = d.communities[cid]!;
        const before = c.moderation || 'none';

        Object.assign(c, {
          name: patch.name.trim(),
          letter: patch.name.trim()[0]!.toUpperCase(),
          tagline: patch.tagline.trim(),
          intro: patch.intro.trim(),
          logo: patch.logo,
          banner: patch.banner,
          hue: patch.hue,
          links: patch.links.filter((l) => l.label.trim() && l.url.trim()),
          kinds: patch.kinds
            .filter((k) => k.name.trim())
            .map((k) => ({ ...k, name: k.name.trim() })),
          categories: patch.categories.slice(0, 2),
          visibility: visibilityOf(patch.audience),
          audience: patch.audience,
        });

        this.log(d, cid, 'changed', 'updated the ' + c.name + ' profile');

        if (patch.moderation !== before) {
          c.moderation = patch.moderation;
          this.log(d, cid, 'changed', 'set ' + c.name + ' to ' + modLevelText(patch.moderation));
        }
      });

      return ok(undefined);
    },
    slugFor: async (name: string): Promise<string | null> => {
      const base = slugify(name) || 'community';
      const taken = this.state().communities;

      if (!taken[base]) return base;

      let n = 2;

      while (taken[`${base}-${n}`]) n++;

      return `${base}-${n}`;
    },
    requestTransferCode: async (cid: string): Promise<Result> =>
      isOwner(this.state(), cid) ? ok(undefined) : fail('Only the owner can transfer a community'),
    transferOwnership: async (cid: string, to: string, code: string): Promise<Result> => {
      const state = this.state();

      if (!isOwner(state, cid)) return fail('Only the owner can transfer a community');
      if (code.length !== 6) return fail("That code didn't work. Check the email and try again.");

      this.store.set((d) => {
        const c = d.communities[cid]!;
        const roles = rolesOf(d, cid);

        const next =
          roles.find((r) => r.id === 'maintainer') || roles.find((r) => r.id === 'moderator');

        c.maintainer = to;

        roles.forEach((r) => {
          if (r.id === 'owner') r.members = [to];
          else r.members = r.members.filter((id) => id !== to);
        });

        if (next && !next.members.includes(this.me())) next.members.push(this.me());
        this.log(d, cid, 'changed', 'transferred ownership of ' + c.name + ' to ' + handle(d, to));
      });

      return ok(undefined);
    },
    decideRequest: async (
      id: string,
      decision: 'approved' | 'declined',
    ): Promise<Result<{ community?: string }>> => {
      if (!this.state().instance.isAdmin) return fail('Only instance admins decide requests');
      const slug = this.store.set((d) => {
        const r = d.communityRequests.find((x) => x.id === id);

        if (!r) return null;
        r.status = decision;
        r.decided = 'now';

        if (decision === 'approved') {
          const made = buildCommunity(
            d,
            this.store,
            {
              ...r,
              tagline: r.tagline ?? '',
              note: r.note ?? undefined,
              logo: null,
              audience: r.visibility === 'public' ? 'indexed' : 'invite',
            },
            r.by,
          );
          r.communityId = made;
          return made;
        }

        return null;
      });
      return slug ? ok({ community: slug }) : ok({});
    },
  };

  readonly rooms = {
    settings: (key: string) => this.state().roomSettings[key] ?? (ROOM_DEFAULTS as RoomSettings),
    updateSettings: (key: string, patch: Partial<RoomSettings>) =>
      this.store.set((state) => {
        state.roomSettings[key] = {
          ...clone(ROOM_DEFAULTS as RoomSettings),
          ...state.roomSettings[key],
          ...patch,
        };
      }),
    setModeration: async (cid: string, rid: string, level: ModerationLevel): Promise<Result> => {
      const state = this.state();
      const order: ModerationLevel[] = ['none', 'reports', 'full'];
      const ceiling = community(state, cid)?.moderation ?? 'none';

      if (order.indexOf(level) > order.indexOf(ceiling))
        return fail("A room can't be moderated more than its community.");

      this.store.set((d) => {
        const key = cid + '/' + rid;
        d.roomSettings[key] = {
          ...clone(ROOM_DEFAULTS as RoomSettings),
          ...d.roomSettings[key],
          moderation: level,
        };
        this.log(d, cid, 'changed', 'set #' + rid + ' to ' + modLevelText(level));
      });

      return ok(undefined);
    },
    rename: async (cid: string, from: string, to: string): Promise<Result<{ id: string }>> => {
      await latency(200);

      const name = slugify(to);

      if (name.length < 2) return fail('Room names need at least 2 characters');

      const c = community(this.state(), cid)!;

      if (
        name !== from &&
        (c.rooms.some((r) => r.id === name) || c.voice.some((v) => v.id === name))
      )
        return fail('#' + name + ' already exists');

      const voice = c.voice.some((v) => v.id === from);

      this.store.set((state) => {
        const x = state.communities[cid]!;
        const r = voice ? x.voice.find((y) => y.id === from)! : x.rooms.find((y) => y.id === from)!;

        r.id = name;
        r.name = voice ? to.trim() : name;

        if (state.roomSettings[cid + '/' + from]) {
          state.roomSettings[cid + '/' + name] = state.roomSettings[cid + '/' + from]!;
          delete state.roomSettings[cid + '/' + from];
        }

        if (state.chats[cid + '/' + from]) {
          state.chats[cid + '/' + name] = state.chats[cid + '/' + from]!;
          delete state.chats[cid + '/' + from];
        }

        this.log(state, cid, 'changed', 'renamed #' + from + ' to #' + name);
      });

      return ok({ id: name });
    },
    create: async (
      cid: string,
      spec: {
        type: 'text' | 'voice';
        name: string;
        topic: string;
        access?: RoomAccess;
        roleIds?: string[];
      },
    ): Promise<Result<{ id: string }>> => {
      await latency(200);

      const state = this.state();

      if (!canDo(state, cid, 'room.update')) return fail('You need the Manage rooms permission');

      const id = slugify(spec.name);

      if (id.length < 2) return fail('Give the room a name with at least 2 letters');

      const c = community(state, cid)!;

      if (c.rooms.some((r) => r.id === id) || c.voice.some((v) => v.id === id))
        return fail('There is already a room called that');

      this.store.set((d) => {
        const x = d.communities[cid]!;
        const access: RoomAccess = spec.access ?? 'everyone';
        const roleIds = access === 'roles' ? [...(spec.roleIds ?? [])] : [];

        if (spec.type === 'text') {
          x.rooms.push({ id, name: id, unread: 0, access, roleIds });
          d.roomSettings[cid + '/' + id] = {
            ...clone(ROOM_DEFAULTS as RoomSettings),
            topic: spec.topic.trim(),
          };
          this.log(d, cid, 'changed', 'added #' + id);
        } else {
          x.voice.push({
            id,
            name: spec.name.trim(),
            live: false,
            listeners: 0,
            topic: spec.topic.trim(),
            host: this.me(),
            postId: null,
            access,
            roleIds,
          });
          this.log(d, cid, 'changed', 'added the voice room ' + spec.name.trim());
        }
      });

      return ok({ id });
    },
    setAccess: async (
      cid: string,
      rid: string,
      access: RoomAccess,
      roleIds: string[],
    ): Promise<Result> => {
      await latency(200);

      if (!canDo(this.state(), cid, 'room.update'))
        return fail('You need the Manage rooms permission');

      this.store.set((d) => {
        const x = d.communities[cid]!;
        const room = x.rooms.find((r) => r.id === rid) ?? x.voice.find((v) => v.id === rid);

        if (!room) return;

        room.access = access;
        room.roleIds = access === 'roles' ? [...roleIds] : [];
        this.log(d, cid, 'changed', 'changed who can see ' + room.name);
      });

      return ok(undefined);
    },
    archive: async (cid: string, id: string): Promise<Result> => {
      await latency(200);

      if (!canDo(this.state(), cid, 'room.update'))
        return fail('You need the Manage rooms permission');

      this.store.set((state) => {
        const c = state.communities[cid]!;
        const text = c.rooms.find((r) => r.id === id);
        const voice = c.voice.find((v) => v.id === id);
        const room = text ?? voice;

        if (!room) return;
        c.rooms = c.rooms.filter((r) => r.id !== id);
        c.voice = c.voice.filter((v) => v.id !== id);

        (state.archivedRooms[cid] ??= []).unshift({
          id,
          name: room.name,
          type: text ? 'text' : 'voice',
          archivedAt: new Date().toISOString(),
        });

        this.log(state, cid, 'removed', 'archived ' + (text ? '#' + id : room.name));
      });

      return ok(undefined);
    },
    restore: async (cid: string, id: string): Promise<Result> => {
      await latency(200);
      this.store.set((state) => {
        const c = state.communities[cid]!;
        const room = state.archivedRooms[cid]?.find((r) => r.id === id);

        if (!room) return;
        state.archivedRooms[cid] = state.archivedRooms[cid]!.filter((r) => r.id !== id);

        if (room.type === 'text') c.rooms.push({ id, name: room.name, unread: 0 });
        else
          c.voice.push({
            id,
            name: room.name,
            live: false,
            listeners: 0,
            topic: null,
            host: this.me(),
            postId: null,
          });

        this.log(
          state,
          cid,
          'changed',
          'restored ' + (room.type === 'text' ? '#' + id : room.name),
        );
      });
      return ok(undefined);
    },
    destroy: async (cid: string, id: string): Promise<Result> => {
      await latency(200);
      if (!canDo(this.state(), cid, 'room.delete')) return fail('Only the owner can delete rooms');

      this.store.set((state) => {
        const c = state.communities[cid]!;

        const label =
          c.voice.find((v) => v.id === id)?.name ??
          state.archivedRooms[cid]?.find((r) => r.id === id && r.type === 'voice')?.name ??
          '#' + id;

        c.rooms = c.rooms.filter((r) => r.id !== id);
        c.voice = c.voice.filter((v) => v.id !== id);
        state.archivedRooms[cid] = (state.archivedRooms[cid] ?? []).filter((r) => r.id !== id);
        delete state.chats[cid + '/' + id];
        delete state.roomSettings[cid + '/' + id];
        this.log(state, cid, 'removed', 'deleted ' + label);
      });

      return ok(undefined);
    },
    markRead: (cid: string, rid: string) =>
      this.store.set((state) => {
        const r = state.communities[cid]?.rooms.find((x) => x.id === rid);
        if (r) r.unread = 0;
      }),
  };

  readonly posts = {
    markSeen: async (id: string): Promise<Result> => {
      this.store.set((state) => {
        const p = state.posts.find((x) => x.id === id);
        if (p) p.seen = true;
      });

      return ok(undefined);
    },
    markCommunitySeen: async (cid: string): Promise<Result> => {
      this.store.set((state) =>
        state.posts.filter((p) => p.c === cid).forEach((p) => (p.seen = true)),
      );

      return ok(undefined);
    },
    markAllSeen: async (): Promise<Result> => {
      this.store.set((state) => state.posts.forEach((p) => (p.seen = true)));

      return ok(undefined);
    },
    toggleHelpful: async (id: string): Promise<Result> => {
      this.store.set((state) => {
        const p = state.posts.find((x) => x.id === id);

        if (!p || p.author === this.me()) return;
        p.helpfulMine = !p.helpfulMine;
        p.helpful += p.helpfulMine ? 1 : -1;
      });

      return ok(undefined);
    },
    toggleReplyHelpful: async (postId: string, replyId: string): Promise<Result> => {
      this.store.set((state) => {
        const r = state.posts.find((x) => x.id === postId)?.replies.find((y) => y.id === replyId);

        if (!r || r.who === this.me()) return;
        r.helpfulMine = !r.helpfulMine;
        r.helpful += r.helpfulMine ? 1 : -1;
      });

      return ok(undefined);
    },
    togglePin: async (id: string): Promise<Result> => {
      const p = this.state().posts.find((x) => x.id === id);

      if (!p) return fail('Post not found');
      if (!canDo(this.state(), p.c, 'post.pin')) return fail('You need the Pin posts permission');

      this.store.set((state) => {
        const x = state.posts.find((y) => y.id === id)!;
        x.pinned = !x.pinned;
        this.log(state, x.c, 'pinned', (x.pinned ? 'pinned “' : 'unpinned “') + x.title + '”');
      });

      return ok(undefined);
    },
    toggleLock: async (id: string): Promise<Result> => {
      const p = this.state().posts.find((x) => x.id === id);

      if (!p) return fail('Post not found');
      if (!isMod(this.state(), p.c)) return fail('You need the Remove content permission');

      this.store.set((state) => {
        const x = state.posts.find((y) => y.id === id)!;
        x.locked = !x.locked;
        this.log(state, x.c, 'locked', (x.locked ? 'locked “' : 'unlocked “') + x.title + '”');
      });

      return ok(undefined);
    },
    toggleWatch: async (id: string): Promise<Result> => {
      this.store.set((state) => {
        const p = state.posts.find((x) => x.id === id);
        if (p) p.watching = !p.watching;
      });

      return ok(undefined);
    },
    loadReplies: (_postId: string, _parent: string): Promise<Result> =>
      Promise.resolve(ok(undefined)),
    toggleBoost: async (id: string, emoji: string): Promise<Result> => {
      this.store.set((state) => {
        const p = state.posts.find((x) => x.id === id);
        if (p) toggleBoost(p.boosts, emoji);
      });

      return ok(undefined);
    },
    hidePreview: async (id: string): Promise<Result> => {
      this.store.set((state) => {
        const p = state.posts.find((x) => x.id === id);
        if (p) p.previewHidden = true;
      });

      return ok(undefined);
    },
    create: async (spec: {
      c: string;
      kind: string;
      title: string;
      body: string;
      files?: Attachment[];
    }): Promise<Result<{ post: Post }>> => {
      await latency(600);

      const state = this.state();

      if (!canDo(state, spec.c, 'post.create'))
        return fail(
          'Join ' + (community(state, spec.c)?.name ?? 'the community') + ' to post there',
        );

      if (!spec.title.trim()) return fail('Give your post a title first');

      if (spec.title.trim().length > TITLE_MAX)
        return fail(`Keep the title to ${TITLE_MAX} characters.`);

      if (!postableKinds(state, spec.c).some((k) => k.name === spec.kind))
        return fail('Pick a kind of post');

      const post = this.store.set((d) => {
        const p: Post = {
          id: this.store.nextId('p'),
          c: spec.c,
          kind: spec.kind,
          title: spec.title.trim(),
          author: this.me(),
          age: 'now',
          seen: true,
          pinned: false,
          watching: true,
          tags: extractTags(d, spec.title + ' ' + spec.body, spec.c),
          body: spec.body.trim() ? [spec.body.trim()] : [],
          files: spec.files ?? [],
          helpful: 0,
          helpfulMine: false,
          boosts: [],
          answer: null,
          fromChat: null,
          transcript: null,
          replies: [],
        };

        d.posts.unshift(p);
        delete d.drafts[spec.c];

        return p;
      });

      return ok({ post });
    },
    edit: async (id: string, patch: PostPatch): Promise<Result> => {
      await latency(300);

      const p = this.state().posts.find((x) => x.id === id);

      if (!p) return fail('That post is gone.');
      if (p.author !== this.me()) return fail('Only the person who wrote this post can edit it.');

      const title = patch.title.trim();

      if (!title) return fail('A post needs a title.');
      if (title.length > TITLE_MAX) return fail(`Keep the title to ${TITLE_MAX} characters.`);

      this.store.set((state) => {
        const post = state.posts.find((x) => x.id === id);

        if (!post) return;
        post.title = title;

        post.body = patch.body
          .trim()
          .split('\n\n')
          .filter((b) => b.trim() !== '');

        post.kind = patch.kind;
        post.files = [...patch.files];
        post.editedAt = new Date().toISOString();
      });

      return ok(undefined);
    },
    remove: async (id: string): Promise<Result> => {
      await latency(300);

      const state = this.state();
      const p = state.posts.find((x) => x.id === id);

      if (!p) return fail('Post not found');
      if (p.author !== this.me()) return fail('Only the person who wrote this post can delete it.');

      this.store.set((d) => {
        d.posts = d.posts.filter((x) => x.id !== id);
      });

      return ok(undefined);
    },
    toggleAnswer: async (postId: string, replyId: string): Promise<Result> => {
      await latency(300);

      const state = this.state();
      const p = state.posts.find((x) => x.id === postId);

      if (!p) return fail('Post not found');

      if (p.author !== this.me() && !canDo(state, p.c, 'post.answer'))
        return fail('Only the author or a moderator can mark the answer');

      this.store.set((d) => {
        const x = d.posts.find((y) => y.id === postId)!;
        x.answer = x.answer === replyId ? null : replyId;
      });

      return ok(undefined);
    },
    reply: async (
      postId: string,
      spec: { parent: string | null; body: string; files?: Attachment[] },
    ): Promise<Result<{ reply: Reply }>> => {
      const state = this.state();
      const p = state.posts.find((x) => x.id === postId);

      if (!p) return fail('Post not found');

      if (!canDo(state, p.c, 'reply.create'))
        return fail('Join ' + community(state, p.c)!.name + ' to reply');

      if (!spec.body.trim() && !spec.files?.length)
        return fail('Write something or attach a file first.');

      const reply = this.store.set((d) => {
        const r: Reply = {
          id: this.store.nextId('r'),
          parent: spec.parent,
          who: this.me(),
          age: 'now',
          helpful: 0,
          helpfulMine: false,
          body: [spec.body.trim()],
          files: spec.files ?? [],
        };
        d.posts.find((x) => x.id === postId)!.replies.push(r);
        return r;
      });

      return ok({ reply });
    },
    editReply: async (postId: string, replyId: string, patch: ReplyPatch): Promise<Result> => {
      await latency(300);

      const r = this.state()
        .posts.find((x) => x.id === postId)
        ?.replies.find((y) => y.id === replyId);

      if (!r) return fail('That reply is gone.');
      if (r.who !== this.me()) return fail('Only the person who wrote this reply can edit it.');

      if (!patch.body.trim() && patch.files.length === 0)
        return fail('A reply needs some words or a file.');

      this.store.set((state) => {
        const x = state.posts.find((y) => y.id === postId)?.replies.find((y) => y.id === replyId);

        if (!x) return;

        x.body = patch.body
          .trim()
          .split('\n\n')
          .filter((b) => b.trim() !== '');

        x.files = [...patch.files];
        x.edited = true;
      });

      return ok(undefined);
    },
    removeReply: async (postId: string, replyId: string): Promise<Result> => {
      await latency(300);

      const state = this.state();
      const p = state.posts.find((x) => x.id === postId);
      const r = p?.replies.find((x) => x.id === replyId);

      if (!p || !r) return fail('That reply is gone.');
      if (r.who !== this.me()) return fail('Only the person who wrote this reply can delete it.');

      this.store.set((d) => {
        const x = d.posts.find((y) => y.id === postId)!;
        // One with replies under it stays as a marker so the thread keeps its shape
        if (x.replies.some((y) => y.parent === replyId)) {
          const reply = x.replies.find((y) => y.id === replyId)!;

          reply.removed = true;
          reply.body = [];
          reply.files = [];
        } else {
          x.replies = x.replies.filter((y) => y.id !== replyId);
          if (x.answer === replyId) x.answer = null;
        }
      });

      return ok(undefined);
    },
    startLive: async (postId: string): Promise<Result<{ room: string }>> => {
      const state = this.state();
      const p = state.posts.find((x) => x.id === postId);

      if (!p) return fail('Post not found');

      if (p.author !== this.me())
        return fail('Only the person who wrote the post can start a live discussion on it');

      const c = community(state, p.c)!;

      if (c.voice.length && c.voice.every((x) => x.live))
        return fail('Every voice room in ' + c.name + ' is busy right now');

      const room = this.store.set((d) => {
        const x = d.communities[p.c]!;
        let v = x.voice.find((y) => !y.live);

        if (!v) {
          v = {
            id: 'live',
            name: 'Live room',
            live: false,
            listeners: 0,
            topic: null,
            host: this.me(),
            postId: null,
          };
          x.voice.push(v);
        }

        Object.assign(v, {
          live: true,
          topic: p.title,
          postId: p.id,
          host: this.me(),
          listeners: Math.max(v.listeners, 3),
          mode: 'stage' as const,
        });

        d.live = {
          joined: true,
          key: p.c + '/' + v.id,
          role: 'host',
          muted: false,
          hostTools: true,
        };

        return v.id;
      });

      return ok({ room });
    },
    saveDraft: async (
      cid: string,
      draft: { title: string; body: string; kind: string },
    ): Promise<Result> => {
      this.store.set((state) => {
        state.drafts[cid] = { ...draft, updatedAt: new Date().toISOString() };
      });

      return ok(undefined);
    },
    discardDraft: async (cid: string): Promise<Result> => {
      this.store.set((state) => delete state.drafts[cid]);

      return ok(undefined);
    },
  };

  readonly chat = {
    open: (key: string) =>
      this.store.set((state) => {
        if (!state.chats[key]) state.chats[key] = [];
        const [cid, rid] = key.split('/') as [string, string];

        if (cid === 'dm') {
          const d = state.directs.find((x) => x.who === rid);
          if (d) d.unread = false;
        } else {
          const r = state.communities[cid]?.rooms.find((x) => x.id === rid);
          if (r) r.unread = 0;
        }
      }),
    openDm: (who: string) =>
      this.store.set((state) => {
        if (!state.directs.find((d) => d.who === who))
          state.directs.unshift({ who, unread: false });
        if (!state.chats['dm/' + who]) state.chats['dm/' + who] = [];
      }),
    send: (
      key: string,
      text: string,
      opts: { files?: Attachment[]; parent?: string | null } = {},
    ): Result<{ sound?: string }> => {
      const state = this.state();
      const [cid, rid] = key.split('/') as [string, string];
      const body = text.trim();

      if (!body && !opts.files?.length) return fail('Write something first.');

      if (cid !== 'dm' && !canDo(state, cid, 'message.create'))
        return fail('Join ' + community(state, cid)!.name + ' to chat there');

      if (opts.parent && !state.chats[key]?.some((m) => m.id === opts.parent))
        return fail('That message was deleted, so there is nothing to reply to.');

      const push = (m: Partial<Message> & { who: string; text: string }) =>
        this.store.set((d) => {
          (d.chats[key] ??= []).push({
            id: this.store.nextId('m'),
            time: nowTime(),
            boosts: [],
            ...m,
          });
        });

      if (body.startsWith('/')) {
        const space = body.search(/\s/);
        const name = (space < 0 ? body.slice(1) : body.slice(1, space)).toLowerCase();
        const arg = space < 0 ? '' : body.slice(space).trim();
        const cmd = this.chat.commands(key).find((c) => c.cmd === name);

        if (!cmd)
          return fail(
            name
              ? "There's no /" + name + ' command. Type / to see the ones you can use.'
              : 'Type a command after the slash, like /play tada.',
          );

        if (!cmd.ok) return fail(cmd.reason ?? 'You cannot use that here');

        if (name === 'play') {
          if (!arg) return fail('Pick a sound, like /play tada.');

          if (!SOUNDS.includes(arg.toLowerCase())) {
            const examples = SOUNDS.slice(0, 4).join(', ');

            return fail(`“${arg}” isn't a sound. Try ${examples} or another from the list.`);
          }

          push({ who: this.me(), system: true, text: 'played “' + arg.toLowerCase() + '”' });

          return ok({ sound: arg.toLowerCase() });
        }

        if (name === 'me') {
          if (!arg) return fail("Say what you're doing, like /me is reviewing the PR.");
          push({ who: this.me(), system: true, text: arg });
          return ok({});
        }

        if (name === 'shrug') {
          push({
            who: this.me(),
            text: [arg, '¯\\_(ツ)_/¯'].filter(Boolean).join(' '),
            files: opts.files ?? [],
          });
          return ok({});
        }

        if (name === 'topic') {
          if (!arg) return fail('Write the new topic after /topic.');
          this.rooms.updateSettings(key, { topic: arg });
          push({ who: this.me(), system: true, text: 'changed the topic to “' + arg + '”' });

          return ok({});
        }

        return fail('Unknown command');
      }

      push({ who: this.me(), text: body, parent: opts.parent ?? null, files: opts.files ?? [] });
      void rid;

      return ok({});
    },
    commands: (key: string) => {
      const state = this.state();
      const dm = key.startsWith('dm/');
      const cid = key.split('/')[0]!;
      const sound = soundAccess(state, key);
      const admin = !dm && (isOwner(state, cid) || canDo(state, cid, 'room.update'));

      return [
        {
          cmd: 'play',
          args: 'sound',
          desc: 'Play a sound for everyone here',
          ok: sound.ok,
          reason: sound.ok ? undefined : sound.reason,
          icon: 'music',
        },
        { cmd: 'me', args: 'action', desc: "Say what you're doing", ok: true, icon: 'user' },
        { cmd: 'shrug', args: 'message', desc: 'Add ¯\\_(ツ)_/¯', ok: true, icon: 'smile' },
        {
          cmd: 'topic',
          args: 'new topic',
          desc: 'Change the room topic',
          ok: admin,
          reason: dm ? 'Not available in direct messages' : 'Only admins can change the topic',
          icon: 'pencil',
        },
      ];
    },
    edit: (
      key: string,
      id: string,
      patch: { text: string; files: readonly Attachment[] },
    ): Result =>
      this.store.set((state) => {
        const m = state.chats[key]?.find((x) => x.id === id);

        if (!m) return fail('That message is gone.');

        const text = patch.text.trim();
        const files = [...patch.files];

        if (!text && !files.length)
          return fail('A message needs some text or a file. Delete it instead.');

        m.text = text;
        m.files = files;
        m.edited = true;

        return ok(undefined);
      }),
    remove: (key: string, id: string) =>
      this.store.set((state) => {
        if (state.chats[key]) state.chats[key] = state.chats[key]!.filter((m) => m.id !== id);
      }),
    loadReplies: (_key: string, _parent: string): Promise<Result> => Promise.resolve(ok(undefined)),
    toggleBoost: (key: string, id: string, emoji: string) =>
      this.store.set((state) => {
        const m = state.chats[key]?.find((x) => x.id === id);
        if (m) toggleBoost(m.boosts, emoji);
      }),
    hidePreview: (key: string, id: string) =>
      this.store.set((state) => {
        const m = state.chats[key]?.find((x) => x.id === id);
        if (m) m.previewHidden = true;
      }),
    promote: async (
      key: string,
      ids: string[],
      spec: { title: string; kind: string },
    ): Promise<Result<{ post: Post }>> => {
      const state = this.state();
      const [cid, rid] = key.split('/') as [string, string];
      const msgs = (state.chats[key] ?? []).filter((m) => ids.includes(m.id) && !m.system);

      if (!msgs.length) return fail('Pick at least one message');
      if (!spec.title.trim()) return fail('Give the post a title');
      if (roomAccess(state, cid, rid) === 'roles') return fail(PRIVATE_ROOM);

      const first = msgs[0]!;

      const post = this.store.set((d) => {
        const p: Post = {
          id: this.store.nextId('p'),
          c: cid,
          kind: spec.kind,
          title: spec.title.trim(),
          author: first.who,
          age: 'now',
          seen: true,
          pinned: false,
          watching: true,
          tags: extractTags(d, msgs.map((m) => m.text).join(' '), cid),
          body: [
            first.text,
            '_Started in #' + rid + ', promoted by @' + person(d, this.me()).username + '._',
          ],
          helpful: 0,
          helpfulMine: false,
          boosts: [],
          answer: null,
          fromChat: { room: rid, count: msgs.length },
          transcript: null,
          replies: msgs.slice(1).map((m) => ({
            id: this.store.nextId('r'),
            parent: null,
            who: m.who,
            age: m.time,
            helpful: 0,
            helpfulMine: false,
            body: [m.text],
            files: m.files ?? [],
          })),
        };

        d.posts.unshift(p);

        d.chats[key]!.push({
          id: this.store.nextId('m'),
          who: this.me(),
          system: true,
          text: 'promoted ' + msgs.length + ' messages to a post: “' + p.title + '”',
          time: nowTime(),
          boosts: [],
        });

        return p;
      });

      return ok({ post });
    },
  };

  readonly voice = {
    moreRecordings: async (): Promise<void> => undefined,

    renameRecording: async (id: string, title: string): Promise<Result> => {
      this.store.set((state) => {
        const r = state.recordings[id];
        if (r) r.title = title;
      });
      return ok(undefined);
    },

    deleteRecording: async (id: string): Promise<Result> => {
      this.store.set((state) => {
        delete state.recordings[id];
      });
      return ok(undefined);
    },

    join: async (cid: string, rid: string, asSpeaker: boolean): Promise<Result> => {
      const state = this.state();
      const v = community(state, cid)?.voice.find((x) => x.id === rid);

      if (!v) return fail('That room does not exist');
      if (!community(state, cid)!.joined) return fail('Join the community first');

      const open = v.mode === 'open';

      this.store.set((d) => {
        if (d.live.joined && d.live.key !== cid + '/' + rid) this.voice.leaveNow(d);

        let role: AppState['live']['role'] = 'listener';

        if (v.host === this.me()) role = 'host';
        else if (open || asSpeaker) role = 'speaker';

        d.live = {
          joined: true,
          key: cid + '/' + rid,
          role,
          muted: true,
          hostTools: role === 'host',
        };

        d.communities[cid]!.voice.find((x) => x.id === rid)!.listeners += 1;
      });

      return ok(undefined);
    },
    start: async (cid: string, rid: string, mode: VoiceMode, topic: string): Promise<Result> => {
      const state = this.state();

      if (!canDo(state, cid, 'voice-session.create'))
        return fail('You need the Start voice rooms permission');

      this.store.set((d) => {
        const v = d.communities[cid]!.voice.find((x) => x.id === rid)!;
        Object.assign(v, { live: true, mode, topic, host: this.me(), listeners: 1 });
        d.live = {
          joined: true,
          key: cid + '/' + rid,
          role: 'host',
          muted: false,
          hostTools: true,
        };
      });

      return ok(undefined);
    },
    leave: async () => this.store.set((d) => this.voice.leaveNow(d)),
    leaveNow: (d: AppState) => {
      const [cid, rid] = (d.live.key || '/').split('/') as [string, string];
      const v = d.communities[cid]?.voice.find((x) => x.id === rid);

      if (v && v.listeners > 0) v.listeners -= 1;
      if (d.live.key) useVoiceSession.getState().dispatch(d.live.key, { type: 'left' });
      d.live = { joined: false, key: null, role: 'listener', muted: true };
    },
    end: async (cid: string, rid: string): Promise<Result> => {
      if (getRoomSession(cid + '/' + rid).recording.on) await this.voice.record(false);

      this.store.set((d) => {
        const v = d.communities[cid]!.voice.find((x) => x.id === rid);
        if (v) Object.assign(v, { live: false, listeners: 0, topic: null, postId: null });
        this.voice.leaveNow(d);
      });

      useVoiceSession.getState().drop(cid + '/' + rid);

      return ok(undefined);
    },
    toggleMute: async (): Promise<Result> => {
      this.store.set((d) => {
        if (mayTalk(d)) d.live.muted = !d.live.muted;
      });
      return ok(undefined);
    },
    setRole: async (role: AppState['live']['role']): Promise<Result> => {
      this.store.set((d) => {
        d.live.role = role;
        d.live.muted = true;
      });
      return ok(undefined);
    },
    room: (action: SessionAction) => {
      const key = this.state().live.key;
      if (key) useVoiceSession.getState().dispatch(key, action);
    },
    raiseHand: async (raised: boolean): Promise<Result> => {
      const key = this.state().live.key;

      if (!key) return fail('Join the room first');
      if (getRoomSession(key).handUp !== raised) this.voice.room({ type: 'hand-toggled' });

      return ok(undefined);
    },
    invite: async (who: string): Promise<Result> => {
      this.voice.room({ type: 'invited', id: who });
      return ok(undefined);
    },
    demote: async (who: string): Promise<Result> => {
      this.voice.room({ type: 'demoted', id: who });
      return ok(undefined);
    },
    serverMute: async (who: string, muted: boolean): Promise<Result> => {
      this.voice.room({ type: muted ? 'server-muted' : 'server-mute-lifted', id: who });
      return ok(undefined);
    },
    disconnect: async (who: string): Promise<Result> => {
      this.voice.room({ type: 'disconnected', id: who });
      return ok(undefined);
    },
    share: async (screen: MediaStream | null): Promise<Result> => {
      const me = this.me();

      if (screen) this.voice.room({ type: 'share-started', by: me });
      else this.voice.room({ type: 'share-stopped' });

      return ok(undefined);
    },
    editTranscriptLine: async (
      sessionId: string,
      lineId: string,
      text: string,
    ): Promise<Result> => {
      const trimmed = text.trim();

      if (!trimmed) return fail('Write what was said.');

      this.store.set((state) => {
        const line = state.transcripts[sessionId]?.lines.find((l) => l.id === lineId);
        if (line) line.text = trimmed;
      });

      return ok(undefined);
    },

    record: async (on: boolean): Promise<Result> => {
      const key = this.state().live.key;

      if (!key) return fail('Join the room first');

      const [cid, rid] = key.split('/') as [string, string];
      const now = getRoomSession(key).recording;

      if (on) {
        if (now.on) return fail('This room is already being recorded.');
        this.voice.room({ type: 'recording-started', by: this.me(), startedAt: Date.now() });
        sfx('recordStart');

        this.store.set((d) => {
          const v = d.communities[cid]?.voice.find((x) => x.id === rid);
          if (v) v.recording = true;
        });

        return ok(undefined);
      }

      if (!now.on) return fail('Nothing is being recorded.');

      const seconds = Math.max(1, Math.round((Date.now() - now.startedAt) / 1000));
      const id = 'rec-' + crypto.randomUUID();
      const screen = getRoomSession(key).share !== null;

      this.voice.room({ type: 'recording-stopped' });
      sfx('recordStop');

      this.store.set((d) => {
        const v = d.communities[cid]?.voice.find((x) => x.id === rid);
        if (v) v.recording = false;
        d.recordings[id] = {
          id,
          postId: v?.postId ?? '',
          c: cid,
          room: v?.name ?? '',
          rid,
          title: v?.topic ?? v?.name ?? 'Recording',
          duration: `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`,
          date: 'Today',
          by: this.me(),
          screen,
          real: false,
          status: 'processing',
          seconds,
        };
      });

      // The demo has no server to put a video together so it is ready at once with nothing to play
      setTimeout(
        () =>
          this.store.set((d) => {
            const r = d.recordings[id];
            if (r) r.status = 'ready';
          }),
        1500,
      );

      return ok(undefined);
    },
    setCaptions: () => undefined,
    react: (emoji: string) => {
      const key = this.state().live.key;
      if (key) floatReaction(key, this.me(), emoji);
    },
    resumeAudio: () => undefined,
  };

  readonly events = {
    // The demo's recordings are already in its data
    loadRecordings: () => undefined,
    toggleInterest: (id: string) =>
      this.store.set((state) => {
        const e = state.events.find((x) => x.id === id);

        if (!e) return;

        const me = this.me();

        e.interested = e.interested.includes(me)
          ? e.interested.filter((x) => x !== me)
          : [...e.interested, me];
      }),
    save: async (
      cid: string,
      id: string | null,
      spec: EventSpec,
    ): Promise<Result<{ event: CommunityEvent }>> => {
      await latency(0);

      const state = this.state();
      const existing = id ? state.events.find((e) => e.id === id) : null;

      if (
        existing
          ? !(existing.host === this.me() || canDo(state, cid, 'event.create'))
          : !canDo(state, cid, 'event.create')
      )
        return fail('You need the Schedule events permission');

      if (!spec.title.trim()) return fail('Give the event a name');

      if (!id && new Date(spec.start).getTime() < Date.now() - 60000)
        return fail('That time has already passed');

      const event = this.store.set((d) => {
        const data = { ...spec, title: spec.title.trim(), desc: spec.desc.trim() };

        if (spec.where.type !== 'voice') delete (data as Partial<EventSpec>).talk;

        if (id) {
          const e = d.events.find((x) => x.id === id)!;

          Object.assign(e, data);
          this.log(d, cid, 'changed', 'rescheduled ' + e.title);

          return e;
        }

        const e: CommunityEvent = {
          id: this.store.nextId('e'),
          c: cid,
          host: this.me(),
          interested: [this.me()],
          cancelled: false,
          ...data,
        };

        d.events.push(e);
        this.log(d, cid, 'changed', 'scheduled ' + e.title);

        return e;
      });

      return ok({ event });
    },
    cancel: (id: string) =>
      this.store.set((state) => {
        const e = state.events.find((x) => x.id === id);

        if (!e) return;
        e.cancelled = true;
        this.log(state, e.c, 'changed', 'cancelled ' + e.title);
      }),
    restore: (id: string) =>
      this.store.set((state) => {
        const e = state.events.find((x) => x.id === id);
        if (e) e.cancelled = false;
      }),
    remove: (id: string) =>
      this.store.set((state) => {
        const e = state.events.find((x) => x.id === id);

        if (!e) return;
        state.events = state.events.filter((x) => x.id !== id);
        this.log(state, e.c, 'removed', 'deleted the event ' + e.title);
      }),
  };

  private readonly reported = new Set<string>();

  readonly moderation = {
    keep: async (id: string): Promise<Result> => {
      this.store.set((state) => {
        const x = state.queue.find((q) => q.id === id);

        if (!x) return;
        x.status = 'kept';
        this.setContent(state, x, false);

        this.log(
          state,
          x.c,
          'kept',
          'kept a ' + x.kind.toLowerCase() + ' ' + x.where + ' that was flagged',
          'Not a violation',
        );
      });
      return ok(undefined);
    },
    remove: async (id: string, reason: string): Promise<Result> => {
      if (!reason.trim()) return fail('Say why it was removed. It goes in the public log.');
      this.store.set((state) => {
        const x = state.queue.find((q) => q.id === id);

        if (!x) return;
        x.status = 'removed';
        this.setContent(state, x, true);

        this.log(
          state,
          x.c,
          'removed',
          'removed a ' + x.kind.toLowerCase() + ' ' + x.where,
          reason,
        );
      });
      return ok(undefined);
    },
    undo: async (id: string): Promise<Result> => {
      this.store.set((state) => {
        const x = state.queue.find((q) => q.id === id);

        if (!x) return;
        if (x.status === 'removed') this.setContent(state, x, false);
        x.status = 'pending';
      });
      return ok(undefined);
    },
    banFromQueue: async (id: string, reason: string): Promise<Result> => {
      if (!reason.trim()) return fail('Say why. It goes in the public log.');
      this.store.set((state) => {
        const x = state.queue.find((q) => q.id === id);

        if (!x) return;
        x.status = 'removed';
        this.setContent(state, x, true);

        state.queue
          .filter((y) => y.who === x.who && y.status === 'pending')
          .forEach((y) => (y.status = 'removed'));

        this.log(state, x.c, 'banned', 'banned ' + handle(state, x.who), reason);

        state.bans.unshift({
          id: this.store.nextId('b'),
          name: person(state, x.who).username,
          c: x.c,
          reason,
          by: this.me(),
          age: 'now',
          until: 'permanent',
        });
      });
      return ok(undefined);
    },
    report: async (spec: {
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
    }): Promise<Result<{ queued: boolean }>> => {
      const state = this.state();

      if (!spec.dm && !reportsOn(state, spec.c, spec.r))
        return fail("Reports are off here, so this can't be reported.");

      if (spec.who === this.me()) return fail("You can't report your own post or message.");

      const mark = this.me() + ':' + spec.id;

      if (this.reported.has(mark))
        return fail("You've already reported this. A moderator will take a look.");

      this.reported.add(mark);

      const open = state.queue.find(
        (x) => x.subject?.id === spec.id && x.status === 'pending' && x.reported,
      );

      const report = { reason: spec.reason, note: spec.note?.trim() || null, age: 'now' };

      this.store.set((d) => {
        const post = spec.kind === 'Post' ? d.posts.find((p) => p.id === spec.id) : null;

        if (post) {
          post.reported = true;
          post.inReview = true;
        }

        const item = d.queue.find((x) => x.id === open?.id);

        if (item) {
          item.reports = [...(item.reports ?? []), report];
          return;
        }

        d.queue.unshift({
          id: this.store.nextId('q'),
          c: spec.dm ? 'dm' : spec.c,
          ...(spec.r ? { r: spec.r } : {}),
          reported: true,
          source: spec.dm ? 'instance' : 'report',
          reports: [report],
          subject: {
            type: SUBJECT_TYPE[spec.kind],
            id: spec.id,
            postId: null,
          },
          kind: spec.kind,
          who: spec.who,
          where: spec.where,
          text: spec.text,
          reason: 'Reported by ' + displayName(d, this.me()) + '.',
          score: 0.5,
          status: 'pending',
          age: 'now',
        });
      });

      return ok({ queued: true });
    },
    removeContent: async (ref: ContentRef, reason: string): Promise<Result> => {
      if (!canDo(this.state(), ref.c, 'content.remove'))
        return fail('You need the Remove content permission');

      if (!reason.trim()) return fail('Say why it was removed. It goes in the public log.');

      this.store.set((d) => {
        this.markRemoved(d, ref, true);
        this.log(d, ref.c, 'removed', 'removed a ' + ref.kind.toLowerCase(), reason);
      });

      return ok(undefined);
    },
    restoreContent: async (ref: ContentRef): Promise<Result> => {
      if (!canDo(this.state(), ref.c, 'content.remove'))
        return fail('You need the Remove content permission');

      this.store.set((d) => {
        this.markRemoved(d, ref, false);
        this.log(d, ref.c, 'restored', 'restored a ' + ref.kind.toLowerCase());
      });

      return ok(undefined);
    },
    ban: async (spec: {
      c: string;
      username: string;
      reason: string;
      until: string;
    }): Promise<Result> => {
      const state = this.state();

      if (!canDo(state, spec.c, 'member.ban')) return fail('You need the Ban people permission');

      const v = stripPrefix(spec.username.trim(), ['@']).toLowerCase();

      if (!v) return fail('Add the username to ban');
      if (!spec.reason.trim()) return fail('Say why. It goes in the public log.');
      if (v === person(state, this.me()).username) return fail("You can't ban yourself");

      if (state.bans.some((b) => b.name === v && b.c === spec.c))
        return fail('@' + v + ' is already banned there');

      this.store.set((d) => {
        d.bans.unshift({
          id: this.store.nextId('b'),
          name: v,
          c: spec.c,
          reason: spec.reason.trim(),
          by: this.me(),
          age: 'now',
          until: spec.until,
        });
        this.log(
          d,
          spec.c,
          'banned',
          'banned @' + v + (spec.until === 'permanent' ? '' : ' for ' + spec.until),
          spec.reason.trim(),
        );
      });

      return ok(undefined);
    },
    unban: async (id: string): Promise<Result> => {
      this.store.set((state) => {
        const b = state.bans.find((x) => x.id === id);

        if (!b) return;
        state.bans = state.bans.filter((x) => x.id !== id);
        this.log(state, b.c, 'unbanned', 'lifted the ban on @' + b.name);
      });
      return ok(undefined);
    },
    isHeld: (x: QueueItem) => isHeld(this.state(), x),
    level: (cid: string, rid?: string | null) => modLevel(this.state(), cid, rid),
  };

  private setContent(state: AppState, x: QueueItem, removed: boolean) {
    if (!x.subject) return;
    const kind = SUBJECT_KIND[x.subject.type];
    this.markRemoved(state, { c: x.c, kind, id: x.subject.id }, removed);
  }

  private markRemoved(state: AppState, ref: ContentRef, removed: boolean) {
    for (const post of state.posts) {
      if (ref.kind === 'Post' && post.id === ref.id) {
        post.removed = removed;
        post.moderated = removed;
      }

      if (ref.kind !== 'Reply') continue;

      const reply = post.replies.find((r) => r.id === ref.id);

      if (reply) {
        reply.removed = removed;
        reply.moderated = removed;
      }
    }

    if (ref.kind !== 'Message') return;

    for (const messages of Object.values(state.chats)) {
      const m = messages.find((x) => x.id === ref.id);
      if (m) {
        m.system = removed;
        m.moderated = removed;
      }
    }
  }

  readonly roles = {
    create: async (cid: string, name: string): Promise<Result<{ id: string }>> => {
      if (!canDo(this.state(), cid, 'role.update'))
        return fail('You need the Manage roles permission');

      if (!name.trim()) return fail('Give the role a name');

      const id = this.store.set((d) => {
        const rid = slugify(name) + '-' + d.seq;
        d.roles.push({
          c: cid,
          id: rid,
          name: name.trim(),
          hue: 'pink',
          members: [],
          permissions: ['post.create', 'reply.create', 'message.create'],
        });
        return rid;
      });

      return ok({ id });
    },
    remove: async (cid: string, id: string): Promise<Result> => {
      this.store.set((state) => {
        state.roles = state.roles.filter((r) => !(r.c === cid && r.id === id));
      });
      return ok(undefined);
    },
    setPermission: async (
      cid: string,
      id: string,
      perm: Permission,
      on: boolean,
    ): Promise<Result> => {
      this.store.set((state) => {
        const r = state.roles.find((x) => x.c === cid && x.id === id);

        if (!r || r.locked) return;

        r.permissions = on
          ? [...new Set([...r.permissions, perm])]
          : r.permissions.filter((p) => p !== perm);

        this.log(state, cid, 'changed', 'changed “' + perm + '” for ' + r.name);
      });
      return ok(undefined);
    },
    addMember: async (cid: string, id: string, who: string): Promise<Result> => {
      this.store.set((state) => {
        const r = state.roles.find((x) => x.c === cid && x.id === id);

        if (!r || r.members.includes(who)) return;
        r.members.push(who);
        this.log(state, cid, 'changed', 'gave ' + handle(state, who) + ' the ' + r.name + ' role');
      });
      return ok(undefined);
    },
    removeMember: async (cid: string, id: string, who: string): Promise<Result> => {
      this.store.set((state) => {
        const r = state.roles.find((x) => x.c === cid && x.id === id);
        if (r) r.members = r.members.filter((m) => m !== who);
      });
      return ok(undefined);
    },
  };

  readonly invites = {
    current: (cid: string) =>
      this.state().invites.links.find((l) => l.c === cid && !l.revoked) ?? null,
    newLink: (cid: string, opts: { expires: string; max: string; role: string }) => {
      this.store.set((state) => {
        const old = state.invites.links.find((l) => l.c === cid && !l.revoked);

        if (old) old.revoked = true;

        const code = cid.slice(0, 2) + '-' + Math.random().toString(36).slice(2, 7);

        state.invites.links.unshift({
          code,
          c: cid,
          ...opts,
          uses: 0,
          created: 'just now',
          by: this.me(),
          revoked: false,
        });
      });
      return Promise.resolve(ok(undefined));
    },
    updateLink: (cid: string, opts: { expires: string; max: string; role: string }) => {
      this.store.set((state) => {
        const l = state.invites.links.find((x) => x.c === cid && !x.revoked);
        if (l) Object.assign(l, opts);
      });
      return Promise.resolve(ok(undefined));
    },
    sendEmails: async (
      cid: string,
      emails: { email: string; role: string }[],
    ): Promise<Result<{ count: number }>> => {
      if (!canDo(this.state(), cid, 'invite.update'))
        return fail('You need the Manage invites permission');

      if (!emails.length) return fail('Add at least one email address.');
      await latency(700);

      this.store.set((state) => {
        emails.forEach((e) =>
          state.invites.emails.unshift({
            id: this.store.nextId('e'),
            email: e.email,
            c: cid,
            role: e.role,
            age: 'just now',
            status: 'pending',
          }),
        );
      });

      return ok({ count: emails.length });
    },
    decline: (id: string) => {
      this.store.set((state) => {
        state.invites.mine = state.invites.mine.filter((i) => i.id !== id);
      });
      return Promise.resolve(ok(undefined));
    },
    unreachable: (emails: string[]) =>
      Promise.resolve(emails.filter((email) => email.endsWith('.invalid'))),
    revokeEmail: (id: string) =>
      this.store.set((state) => {
        const e = state.invites.emails.find((x) => x.id === id);
        if (e) e.status = 'revoked';
      }),
  };

  readonly notifications = {
    open: (id: string) =>
      this.store.set((state) => {
        if (id.startsWith('dm-')) {
          const d = state.directs.find((x) => x.who === id.slice(3));
          if (d) d.unread = false;
        } else {
          const n = state.notifications.find((x) => x.id === id);
          if (n) n.read = true;
        }
      }),
    markAllRead: () =>
      this.store.set((state) => {
        state.notifications.forEach((n) => (n.read = true));
        state.directs.forEach((d) => (d.unread = false));
      }),
    loadEarlier: () => Promise.resolve(),
  };
}

function toggleBoost(boosts: Boost[], e: string) {
  const b = boosts.find((x) => x.e === e);

  if (!b) {
    boosts.push({ e, n: 1, mine: true });
    return;
  }

  if (b.mine) {
    b.n -= 1;
    b.mine = false;
    if (b.n <= 0) boosts.splice(boosts.indexOf(b), 1);
  } else {
    b.n += 1;
    b.mine = true;
  }
}

function buildCommunity(state: AppState, store: Store, spec: CommunitySpec, owner: string) {
  const t = TEMPLATES.find((x) => x.id === spec.template) || TEMPLATES[TEMPLATES.length - 1]!;
  let slug = slugify(spec.name) || 'community';

  while (state.communities[slug]) slug += '-' + Math.random().toString(36).slice(2, 5);

  const kinds = t.kinds.map((k) => ({ ...(KIND_LIB as Record<string, PostKind>)[k]! }));

  state.communities[slug] = {
    name: spec.name.trim(),
    hue: spec.hue,
    letter: spec.name.trim()[0]!.toUpperCase(),
    logo: spec.logo,
    banner: null,
    tagline: spec.tagline.trim(),
    intro: spec.description?.trim() || null,
    links: [],
    members: 1,
    online: 1,
    joined: owner === state.me,
    permissions: [],
    visibility: visibilityOf(spec.audience),
    audience: spec.audience,
    previews: true,
    maintainer: owner,
    welcome:
      "Welcome. You're the first one here. Say hi in #general and invite the people you want around.",
    rooms: t.rooms.map((r) => ({ id: r, name: r, unread: 0 })),
    voice: t.voice
      ? [
          {
            id: slugify(t.voice),
            name: t.voice,
            live: false,
            listeners: 0,
            topic: null,
            host: owner,
            postId: null,
          },
        ]
      : [],
    summary: null,
    kinds,
    categories: t.category ? [t.category] : [],
    place: null,
    listed: true,
    verified: null,
    stats: { helpedWeek: 0, answered: 0, replyMins: 0, ageDays: 0 },
    moderation: 'none',
  };

  const member = state.roles.find((r) => r.c === 'elixir' && r.id === 'member')?.permissions ?? [];

  const moderator =
    state.roles.find((r) => r.c === 'elixir' && r.id === 'moderator')?.permissions ?? [];

  state.roles.push({
    c: slug,
    id: 'owner',
    name: 'Owner',
    hue: 'yellow',
    members: [owner],
    locked: true,
    permissions: [],
  });

  state.roles.push({
    c: slug,
    id: 'moderator',
    name: 'Moderator',
    hue: 'green',
    members: [],
    permissions: [...moderator],
  });

  state.roles.push({
    c: slug,
    id: 'member',
    name: 'Member',
    hue: 'ink',
    members: [],
    permissions: [...new Set([...member, 'invite.create' as const])],
  });

  if (t.event && t.voice) {
    const d = new Date();

    d.setDate(d.getDate() + t.event.days);
    d.setHours(17, 0, 0, 0);

    state.events.push({
      id: store.nextId('e'),
      c: slug,
      title: t.event.title,
      start: d.toISOString(),
      mins: t.event.mins,
      repeat: t.event.repeat,
      where: { type: 'voice', room: slugify(t.voice) },
      talk: 'open',
      host: owner,
      interested: [owner],
      cancelled: false,
      desc: null,
    });
  }

  return slug;
}
