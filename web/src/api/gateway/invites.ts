import type { HearthGateway, LinkOptions, Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import {
  inviteAccept,
  inviteCreate,
  inviteDelete,
  emailCheckCreate,
  inviteEmailCreate,
  inviteEmailDecline,
  inviteMine,
  inviteEmailDelete,
  inviteIndex,
  inviteShow,
  inviteUpdate,
} from '@/generated/api/communities/communities';
import { previewCommunity, toInviteBody, toInviteEmail, toInviteLink } from '../invites';
import { ageOf, toPerson } from '../mappers';
import type { GatewayContext } from './context';
import { call, failed } from './context';

const NOT_LOADED = 'Open the community first.';

export function createInvitesGateway(
  ctx: GatewayContext,
  loadCommunity: (cid: string) => Promise<Result>,
  loadRoles: (cid: string) => Promise<Result>,
) {
  const communityId = async (cid: string): Promise<string | null> => {
    if (!ctx.communityIds.has(cid)) await loadCommunity(cid);

    return ctx.communityIds.get(cid) ?? null;
  };

  const current = (cid: string) =>
    ctx.store.get().invites.links.find((link) => link.c === cid && !link.revoked) ?? null;

  const load = {
    invites: async (cid: string) => {
      const id = await communityId(cid);

      if (!id) return fail(NOT_LOADED);

      const [answer, roles] = await Promise.all([call(() => inviteIndex(id)), loadRoles(cid)]);

      if (answer.status !== 200) return failed(answer);
      if (!roles.ok) return roles;

      ctx.store.set((state) => {
        state.invites.links = [
          ...state.invites.links.filter((link) => link.c !== cid),
          ...answer.data.links.map((link) => toInviteLink(link, cid)),
        ];
        state.invites.emails = [
          ...state.invites.emails.filter((email) => email.c !== cid),
          ...answer.data.emails.map((email) => toInviteEmail(email, cid)),
        ];
      });

      return ok(undefined);
    },

    invite: async (code: string) => {
      await ctx.sessionLoaded;

      const answer = await call(() => inviteShow(code));

      if (answer.status !== 200) return failed(answer);

      const { community, inviter } = answer.data;
      const cid = ctx.communitySlugs.get(community.id) ?? null;

      const slug =
        cid ?? ctx.rememberCommunity(previewCommunity(community, inviter?.id ?? null), null);

      ctx.store.set((state) => {
        const stored = state.communities[slug];

        if (stored && cid === null) stored.joined = false;
        if (stored) stored.members = community.member_count;
        if (inviter) state.people[inviter.id] ??= toPerson(inviter);

        // Someone outside the community can't list its roles so the preview names the one it gives
        const role = answer.data.role_key;

        if (!state.roles.some((r) => r.c === slug && r.id === role))
          state.roles.push({
            c: slug,
            id: role,
            name: answer.data.role_name,
            hue: 'ink',
            members: [],
            permissions: [],
          });

        state.invites.links = state.invites.links.filter((link) => link.code !== code);

        state.invites.links.push({
          code,
          c: slug,
          expires: 'never',
          max: 'none',
          role: answer.data.role_key,
          uses: 0,
          created: '',
          by: inviter?.id ?? '',
          revoked: !answer.data.usable,
        });
      });

      return ok(undefined);
    },

    // Joining one goes through acceptInvite, which finds its community from the link kept here
    myInvites: async () => {
      await ctx.sessionLoaded;

      const answer = await call(() => inviteMine());

      if (answer.status !== 200) return failed(answer);

      const mine = answer.data.map((invite) => {
        const known = ctx.communitySlugs.get(invite.community.id);
        const c = known ?? ctx.rememberCommunity(previewCommunity(invite.community, null), null);
        return { invite, c, known: known !== undefined };
      });

      ctx.store.set((state) => {
        for (const { invite, c, known } of mine) {
          const stored = state.communities[c];

          if (!known && stored) stored.joined = false;
          if (invite.inviter) state.people[invite.inviter.id] ??= toPerson(invite.inviter);

          state.invites.links = state.invites.links.filter((link) => link.code !== invite.code);

          state.invites.links.push({
            code: invite.code,
            c,
            expires: 'never',
            max: '1',
            role: invite.role_key,
            uses: 0,
            created: '',
            by: invite.inviter?.id ?? '',
            revoked: false,
          });
        }

        state.invites.mine = mine.map(({ invite, c }) => ({
          id: invite.id,
          code: invite.code,
          c,
          by: invite.inviter?.id ?? null,
          role: invite.role_key,
          age: ageOf(invite.inserted_at),
        }));
      });

      return ok(undefined);
    },
  } satisfies Partial<HearthGateway['load']>;

  const replace = async (cid: string, opts: LinkOptions): Promise<Result> => {
    const id = await communityId(cid);

    if (!id) return fail(NOT_LOADED);

    const old = current(cid);
    const answer = await call(() => inviteCreate(id, toInviteBody(opts)));

    if (answer.status !== 201) return failed(answer);

    if (old) void call(() => inviteDelete(old.code));

    ctx.store.set((state) => {
      for (const link of state.invites.links) if (link.c === cid) link.revoked = true;
      state.invites.links.unshift(toInviteLink(answer.data, cid));
    });

    return ok(undefined);
  };

  const invites: HearthGateway['invites'] = {
    current,
    newLink: replace,

    updateLink: async (cid, opts) => {
      const link = current(cid);

      if (!link) return replace(cid, opts);

      const answer = await call(() => inviteUpdate(link.code, toInviteBody(opts)));

      if (answer.status !== 200) return failed(answer);

      ctx.store.set((state) => {
        const index = state.invites.links.findIndex((l) => l.code === link.code);
        if (index >= 0) state.invites.links[index] = toInviteLink(answer.data, cid);
      });

      return ok(undefined);
    },

    sendEmails: async (cid, emails, note) => {
      const id = await communityId(cid);

      if (!id) return fail(NOT_LOADED);

      const body = { note, emails: emails.map((e) => ({ email: e.email, role_key: e.role })) };
      const answer = await call(() => inviteEmailCreate(id, body));

      if (answer.status !== 201) return failed(answer);

      ctx.store.set((state) => {
        state.invites.emails.unshift(...answer.data.map((email) => toInviteEmail(email, cid)));
      });

      return ok({ count: answer.data.length });
    },

    decline: async (id) => {
      const answer = await call(() => inviteEmailDecline(id));

      if (answer.status !== 204) return failed(answer);

      ctx.store.set((state) => {
        state.invites.mine = state.invites.mine.filter((invite) => invite.id !== id);
      });

      return ok(undefined);
    },

    // A check that fails says nothing is wrong and the send checks again
    unreachable: async (emails) => {
      const answer = await call(() => emailCheckCreate({ emails }));
      if (answer.status !== 200) return [];

      return answer.data.filter((c) => c.status === 'unreachable').map((c) => c.email);
    },

    revokeEmail: (id) => {
      ctx.store.set((state) => {
        const email = state.invites.emails.find((e) => e.id === id);
        if (email) email.status = 'revoked';
      });

      void call(() => inviteEmailDelete(id));
    },
  };

  const inviteByCode = (code: string) =>
    ctx.store.get().invites.links.find((link) => link.code === code) ?? null;

  const acceptInvite = async (code: string): Promise<Result<{ community: string }>> => {
    const link = inviteByCode(code);

    if (!link) return fail('Open the invite link again.');

    const answer = await call(() => inviteAccept(code));

    if (answer.status !== 201) return failed(answer);

    await loadCommunity(link.c);

    ctx.store.set((state) => {
      state.invites.mine = state.invites.mine.filter((invite) => invite.code !== code);
    });

    return ok({ community: link.c });
  };

  return { load, invites, inviteByCode, acceptInvite };
}
