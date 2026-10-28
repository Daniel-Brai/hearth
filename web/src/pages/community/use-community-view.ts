import { audienceOf } from '@/domain/audience';
import { useAppState } from '@/data/store';
import {
  canDo,
  community,
  isMod,
  kindsOf,
  modLevel,
  person,
  queueCountIn,
  shortName,
} from '@/domain/selectors';

export function useCommunityView(cid: string) {
  return useAppState((state) => {
    const c = community(state, cid)!;
    return {
      name: c.name,
      tagline: c.tagline,
      hue: c.hue,
      letter: c.letter,
      logo: c.logo,
      banner: c.banner,
      intro: c.intro,
      links: c.links,
      members: c.members,
      online: c.online,
      visibility: c.visibility,
      audience: audienceOf(c),
      joined: c.joined && state.me !== null,
      locked: c.visibility === 'invite' && !(c.joined && state.me !== null),
      maintainer: c.maintainer,
      maintainerName: shortName(state, c.maintainer),
      maintainerUsername: person(state, c.maintainer).username,
      live: c.voice.filter((v) => v.live),
      notModerated: modLevel(state, cid) === 'none',
      canEdit: canDo(state, cid, 'community.update'),
      mod: isMod(state, cid) || canDo(state, cid, 'member.ban'),
      queue: isMod(state, cid) ? queueCountIn(state, cid) : 0,
      canInvite: canDo(state, cid, 'invite.create'),
      canPost: canDo(state, cid, 'post.create'),
      canEvents: canDo(state, cid, 'event.create'),
      compact: state.settings.compact,
      generalRoom: c.rooms[0]?.id ?? null,
      kinds: kindsOf(state, cid).map((k) => k.name),
      kindCounts: Object.fromEntries(
        kindsOf(state, cid).map((k) => [
          k.name,
          state.posts.filter((p) => p.c === cid && p.kind === k.name).length,
        ]),
      ),
      total: state.posts.filter((p) => p.c === cid).length,
    };
  });
}

export type CommunityViewData = ReturnType<typeof useCommunityView>;
