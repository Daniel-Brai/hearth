import { useAppState } from '@/data/store';
import {
  canSeeName,
  commsVisOf,
  displayName,
  handle as handleOf,
  initials,
  person,
  photoOf,
  presence,
  visOf,
} from '@/domain/selectors';
import type { PersonLink, Post, Visibility } from '@/domain/types';
import { routes } from '@/runtime/routes';

const NO_LINKS: PersonLink[] = [];

const PRESENCE_NOTES: Record<Visibility, string | null> = {
  everyone: null,
  members: 'your communities see this',
  nobody: 'only you see this',
};

export function useProfileView(id: string) {
  return useAppState((state) => {
    const p = person(state, id);
    const here = presence(state, id);
    const mine = id === state.me;

    return {
      mine,
      name: displayName(state, id),
      handle: handleOf(state, id),
      username: p.username,
      showName: canSeeName(state, id),
      hidden: p.private,
      hue: p.hue,
      initials: initials(state, id),
      photo: photoOf(state, id),
      bio: p.bio,
      pronouns: p.pronouns ?? null,
      location: p.location,
      joined: p.joined,
      helped: p.helped,
      posts: p.posts,
      answers: p.answers,
      links: p.links?.filter((l) => l.url) ?? NO_LINKS,
      presenceLabel: here?.label ?? null,
      online: !!here?.online,
      presenceNote: mine ? PRESENCE_NOTES[visOf(state, id, 'presence')] : null,
      commsVis: commsVisOf(state, id),
    };
  });
}

export type ProfileViewData = ReturnType<typeof useProfileView>;

const NO_POSTS: Post[] = [];
const NO_REPLIES: ProfileReply[] = [];

export function useProfileActivity(id: string) {
  return useAppState(
    (state) => {
      const activity = state.activity[id];

      if (!activity)
        return { posts: NO_POSTS, postsMore: false, replies: NO_REPLIES, repliesMore: false };

      const byId = new Map(state.posts.map((p) => [p.id, p]));

      return {
        posts: activity.posts.flatMap((pid) => {
          const p = byId.get(pid);
          return p && !p.removed ? [{ ...p }] : [];
        }),
        postsMore: activity.postsAfter !== null,
        replies: activity.replies.map((r) => ({
          key: r.postId + r.id,
          href: routes.post(r.c, r.postId, r.title) + '#reply-' + r.id,
          title: r.title,
          c: r.c,
          community: state.communities[r.c]?.name ?? null,
          excerpt: r.excerpt,
          helpful: r.helpful,
          age: r.age,
          answer: r.answer,
        })),
        repliesMore: activity.repliesAfter !== null,
      };
    },
    () => false,
  );
}

export type ProfileReply = {
  key: string;
  href: string;
  title: string;
  c: string;
  community: string | null;
  excerpt: string | null;
  helpful: number;
  age: string;
  answer: boolean;
};
