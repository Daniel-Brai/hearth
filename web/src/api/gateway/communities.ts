import type { HearthGateway } from '@/data/gateway';
import type { Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import type { AppState } from '@/domain/app-state';
import { visibilityOf } from '@/domain/audience';
import type { CommunityRequest, PostKind } from '@/domain/types';
import {
  communityCreate,
  communityIndex,
  communityJoin,
  communityKindUpdate,
  communityLeave,
  communityPublic,
  communityRequestDecide,
  communityRequestIndex,
  communityShow,
  communitySlug,
  communityTransfer,
  communityTransferCode,
  communityUpdate,
} from '@/generated/api/communities/communities';
import { postIndex, postPinned, postShow } from '@/generated/api/forum/forum';
import { moderationCommunityLevel } from '@/generated/api/moderation/moderation';
import type {
  CommunityRequest as ApiCommunityRequest,
  CreateCommunityBodyTemplate,
  RequestUploadBodyPurpose,
  UpdateCommunityBodyCategoriesItem,
} from '@/generated/schemas';
import { OPEN, SERVER_VISIBILITY, ageOf, toKindInput, toPerson } from '../mappers';
import { dataUrlToBlob, uploadFile } from '../upload';
import { accessToken } from '../session-token';
import type { GatewayContext } from './context';
import { call, errorCode, failed } from './context';

const TEMPLATES = {
  club: true,
  local: true,
  creator: true,
  class: true,
  support: true,
  oss: true,
  blank: true,
} satisfies Record<CreateCommunityBodyTemplate, true>;

const isTemplate = (id: string): id is CreateCommunityBodyTemplate => Object.hasOwn(TEMPLATES, id);

const setJoined = (state: AppState, cid: string, joined: boolean) => {
  const community = state.communities[cid];
  if (community) community.joined = joined;
};

async function imageId(
  picked: string | null,
  before: string | null,
  name: 'logo' | 'banner',
  purpose: RequestUploadBodyPurpose,
): Promise<Result<{ id?: string | null }>> {
  if (picked === before) return ok({});
  if (picked === null) return ok({ id: null });
  if (!picked.startsWith('data:')) return ok({});

  const media = await uploadFile(dataUrlToBlob(picked), name, purpose);

  if (!media) return fail(`The ${name} didn't upload. Try again.`);

  return ok({ id: media.id });
}

const CATCHUP_POOL = 20;

const REQUEST_STATUSES = ['pending', 'approved', 'declined'] as const;

const toRequest = (r: ApiCommunityRequest, by: string): CommunityRequest => ({
  id: r.id,
  by,
  name: r.name,
  tagline: r.tagline,
  hue: r.hue,
  visibility: OPEN.has(r.visibility) ? 'public' : 'invite',
  template: r.template,
  note: r.note,
  status: r.status,
  age: ageOf(r.inserted_at),
  ...(r.decided_at ? { decided: ageOf(r.decided_at) } : {}),
  ...(r.community_slug ? { communityId: r.community_slug } : {}),
});

const KIND_ERRORS: Record<string, string> = {
  keeps_discussion: 'Discussion has to stay, since posts from removed kinds move there.',
  no_discussion: 'Add a Discussion kind first, so posts from removed kinds have somewhere to go.',
};

const sameKinds = (a: readonly PostKind[], b: readonly PostKind[]) =>
  JSON.stringify(a.map(toKindInput)) === JSON.stringify(b.map(toKindInput));

export function createCommunitiesGateway(ctx: GatewayContext) {
  // Only a changed list goes up, and its answer replaces the kinds shown
  const saveKinds = async (
    id: string,
    cid: string,
    before: readonly PostKind[],
    kinds: readonly PostKind[],
  ): Promise<Result> => {
    if (sameKinds(before, kinds)) return ok(undefined);

    const answer = await call(() => communityKindUpdate(id, { kinds: kinds.map(toKindInput) }));

    if (answer.status === 200) {
      ctx.rememberKinds(cid, answer.data);
      return ok(undefined);
    }

    const code = errorCode(answer);
    const known = code ? KIND_ERRORS[code] : undefined;

    return known ? fail(`The rest is saved. ${known}`) : failed(answer);
  };

  const load = {
    home: async () => {
      await ctx.sessionLoaded;

      // Signed out, the home lists the instance's public communities
      if (!accessToken()) {
        const listed = await call(() => communityPublic());

        if (listed.status !== 200) return failed(listed);

        const keys = listed.data.map((community) => ctx.rememberCommunity(community, null));

        // A list answer counts as joined, which only holds for the list of your own communities
        ctx.store.set((state) => {
          for (const key of keys) state.communities[key]!.joined = false;
        });

        return ok(undefined);
      }

      const answer = await call(() => communityIndex());

      if (answer.status !== 200) return failed(answer);

      for (const community of answer.data) ctx.rememberCommunity(community, null);

      // The list carries no post kinds, and feed rows show them so fetch each community's
      // details once, alongside its posts
      const unknown = answer.data.filter((c) => !ctx.knowsKindsOf(c.id));

      const [pages] = await Promise.all([
        Promise.all(answer.data.map((c) => call(() => postIndex(c.id, { limit: CATCHUP_POOL })))),
        Promise.all(
          unknown.map(async (c) => {
            const shown = await call(() => communityShow(c.id));
            if (shown.status === 200) ctx.rememberCommunity(shown.data.community, shown.data);
          }),
        ),
      ]);

      for (const page of pages) if (page.status === 200) ctx.rememberPosts(page.data.data);

      return ok(undefined);
    },

    compose: async () => {
      await ctx.sessionLoaded;
      if (!accessToken()) return ok(undefined);

      const answer = await call(() => communityIndex());

      if (answer.status !== 200) return failed(answer);

      for (const community of answer.data) ctx.rememberCommunity(community, null);

      // Who may post, and in which kinds, comes only with each community's details
      await Promise.all(
        answer.data
          .filter((c) => !ctx.hasDetailFor(c.id))
          .map(async (c) => {
            const shown = await call(() => communityShow(c.id));
            if (shown.status === 200) ctx.rememberCommunity(shown.data.community, shown.data);
          }),
      );

      return ok(undefined);
    },

    community: async (cid: string) => {
      await ctx.sessionLoaded;

      const shown = await call(() => communityShow(cid));

      if (shown.status !== 200) return failed(shown);

      const id = shown.data.community.id;

      ctx.rememberCommunity(shown.data.community, shown.data);

      // An invite only community shows outsiders only its outline so there is nothing more to read
      const open = ['public', 'public_indexed'].includes(shown.data.community.visibility);

      if (!open && shown.data.membership === null) return ok(undefined);

      const [page, pinned] = await Promise.all([
        call(() => postIndex(id)),
        call(() => postPinned(id)),
      ]);

      if (page.status === 200) ctx.rememberPosts(page.data.data);
      if (pinned.status === 200) ctx.rememberPosts(pinned.data);

      // A post that a moderator removed leaves the feed for anyone the server no longer shows it to
      const refetch = async (postId: string) => {
        const answer = await call(() => postShow(postId));
        if (answer.status === 200) ctx.rememberPosts([answer.data]);
        else if (answer.status === 404)
          ctx.store.set((state) => {
            state.posts = state.posts.filter((p) => p.id !== postId);
          });
      };

      // The person who joined or left already changed their own count
      const countMember = (userId: string, by: number) => {
        if (userId === ctx.store.get().me) return;

        ctx.store.set((state) => {
          const community = state.communities[cid];
          if (community) community.members = Math.max(0, community.members + by);
        });
      };

      ctx.watch(`community:${id}`, (realtime, topic) => {
        const stops = [
          realtime.onPush(topic, 'PostCreated', ({ post_id }) => void refetch(post_id)),
          realtime.onPush(topic, 'ContentRemoved', (e) => void refetch(e.subject_id)),
          realtime.onPush(topic, 'ContentRestored', (e) => void refetch(e.subject_id)),
          realtime.onPush(topic, 'MemberJoined', (e) => countMember(e.user_id, 1)),
          realtime.onPush(topic, 'MemberLeft', (e) => countMember(e.user_id, -1)),
          realtime.onPush(topic, 'online_count', ({ count }) =>
            ctx.store.set((state) => {
              const community = state.communities[cid];
              if (community) community.online = count;
            }),
          ),
          realtime.onPush(topic, 'RoomChanged', () => void load.community(cid)),
          realtime.onPush(topic, 'KindsChanged', () => void load.community(cid)),
          realtime.onPush(topic, 'room_access_changed', () => void load.community(cid)),
        ];

        return () => stops.forEach((stop) => stop());
      });

      return ok(undefined);
    },

    requests: async () => {
      const answers = await Promise.all(
        REQUEST_STATUSES.map((status) => call(() => communityRequestIndex({ status }))),
      );

      const requests: ApiCommunityRequest[] = [];

      for (const answer of answers) {
        if (answer.status !== 200) return failed(answer);
        requests.push(...answer.data);
      }

      ctx.store.set((state) => {
        state.communityRequests = [];

        // A request from an account that is gone has nobody to tell so it stays out
        for (const r of requests) {
          if (!r.requester) continue;

          state.people[r.requester.id] ??= toPerson(r.requester);
          state.communityRequests.push(toRequest(r, r.requester.id));
        }
      });

      return ok(undefined);
    },
  } satisfies Partial<HearthGateway['load']>;

  const communities: HearthGateway['communities'] = {
    join: (cid) => {
      const id = ctx.communityIds.get(cid);

      if (!id) return fail('That community is not loaded.');

      ctx.store.set((state) => setJoined(state, cid, true));

      void call(() => communityJoin(id)).then(async (answer) => {
        if (answer.status !== 201) return ctx.store.set((state) => setJoined(state, cid, false));

        await load.community(cid);
      });

      return ok(undefined);
    },

    leave: (cid) => {
      const id = ctx.communityIds.get(cid);

      if (!id) return;

      ctx.store.set((state) => setJoined(state, cid, false));

      void call(() => communityLeave(id)).then((answer) => {
        if (answer.status !== 204) ctx.store.set((state) => setJoined(state, cid, true));
      });
    },

    create: async (spec) => {
      const logo = await imageId(spec.logo, null, 'logo', 'logo');

      if (!logo.ok) return logo;

      const answer = await call(() =>
        communityCreate({
          name: spec.name,
          tagline: spec.tagline || null,
          description: spec.description?.trim() || null,
          ...(logo.value.id ? { logo_id: logo.value.id } : {}),
          hue: spec.hue === 'ink' ? 'blue' : spec.hue,
          visibility: SERVER_VISIBILITY[spec.audience],
          ...(isTemplate(spec.template) ? { template: spec.template } : {}),
          note: spec.note ?? null,
        }),
      );

      if (answer.status === 201) return ok({ community: ctx.rememberCommunity(answer.data, null) });
      if (answer.status === 202) return ok({ requested: true });

      return failed(answer);
    },

    update: async (cid, patch) => {
      const id = ctx.communityIds.get(cid);
      const before = ctx.store.get().communities[cid];

      if (!id || !before) return fail('That community is not loaded.');

      const kinds = patch.kinds.filter((k) => k.name.trim());
      const names = kinds.map((k) => k.name.trim().toLowerCase());

      if (!names.length) return fail('Keep at least one kind of post');
      if (new Set(names).size !== names.length) return fail('Two kinds share a name');

      // The server keeps no image addresses so the picked images stay here
      const kept = { logo: patch.logo, banner: patch.banner };

      const restore = (r: Result<never>) => {
        ctx.store.set((state) => (state.communities[cid] = before));
        return r;
      };

      ctx.store.set((state) => {
        state.communities[cid] = {
          ...before,
          ...kept,
          name: patch.name.trim(),
          tagline: patch.tagline.trim(),
          intro: patch.intro.trim() || null,
          categories: patch.categories,
          hue: patch.hue,
          links: patch.links,
          visibility: visibilityOf(patch.audience),
          audience: patch.audience,
          moderation: patch.moderation,
        };
      });

      const [logo, banner] = await Promise.all([
        imageId(patch.logo, before.logo, 'logo', 'logo'),
        // A logo upload is cropped square so the banner goes up as a plain image
        imageId(patch.banner, before.banner, 'banner', 'attachment'),
      ]);

      if (!logo.ok) return restore(logo);
      if (!banner.ok) return restore(banner);

      const answer = await call(() =>
        communityUpdate(id, {
          name: patch.name.trim(),
          tagline: patch.tagline.trim() || null,
          description: patch.intro.trim() || null,
          hue: patch.hue,
          links: patch.links,
          categories: patch.categories as UpdateCommunityBodyCategoriesItem[],
          visibility: SERVER_VISIBILITY[patch.audience],
          ...(logo.value.id === undefined ? {} : { logo_id: logo.value.id }),
          ...(banner.value.id === undefined ? {} : { banner_id: banner.value.id }),
        }),
      );

      if (answer.status !== 200) return restore(failed(answer));

      ctx.rememberCommunity(answer.data, null);

      ctx.store.set((state) => {
        const saved = state.communities[cid];
        if (saved) Object.assign(saved, kept);
      });

      const savedKinds = await saveKinds(id, cid, before.kinds, kinds);

      if (!savedKinds.ok) return savedKinds;

      // The level has its own endpoint that logs every change
      if (patch.moderation === answer.data.moderation) return ok(undefined);

      const level = await call(() => moderationCommunityLevel(id, { level: patch.moderation }));

      if (level.status === 403)
        return fail("The rest is saved. Your role here can't change how much it is moderated.");

      if (level.status !== 200) return failed(level);

      ctx.store.set((state) => {
        const saved = state.communities[cid];
        if (saved) saved.moderation = level.data.level ?? 'none';
      });

      return ok(undefined);
    },

    slugFor: async (name) => {
      const answer = await call(() => communitySlug({ name }));

      return answer.status === 200 ? answer.data.slug : null;
    },

    requestTransferCode: async (cid) => {
      const id = ctx.communityIds.get(cid);

      if (!id) return fail('That community is not loaded.');

      const answer = await call(() => communityTransferCode(id));

      return answer.status === 204 ? ok(undefined) : failed(answer);
    },

    transferOwnership: async (cid, to, code) => {
      const id = ctx.communityIds.get(cid);

      if (!id) return fail('That community is not loaded.');

      const answer = await call(() => communityTransfer(id, { user_id: to, code }));

      if (answer.status !== 200) return failed(answer);

      return load.community(cid);
    },

    decideRequest: async (id, decision) => {
      const answer = await call(() => communityRequestDecide(id, { decision }));

      if (answer.status !== 200) return failed(answer);

      const decided = answer.data;

      ctx.store.set((state) => {
        const index = state.communityRequests.findIndex((r) => r.id === id);
        const before = state.communityRequests[index];

        if (before) state.communityRequests[index] = toRequest(decided, before.by);
      });

      return ok(decided.community_slug ? { community: decided.community_slug } : {});
    },
  };

  const loadJoined = async () => {
    const answer = await call(() => communityIndex());
    if (answer.status === 200) for (const c of answer.data) ctx.rememberCommunity(c, null);
  };

  return { load, communities, loadJoined };
}
