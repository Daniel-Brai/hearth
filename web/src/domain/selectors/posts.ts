import type { AppState } from '../app-state';
import { ageMinutes } from '../format';
import type { Post, PostKind } from '../types';
import { DEFAULT_KINDS, KIND_LIB } from '@/domain/catalog';
import { routes } from '@/runtime/routes';
import { canDo, isMod } from './access';
import { joinedCids } from './communities';

export const kindsOf = (state: AppState, cid: string | null | undefined): PostKind[] =>
  (cid && state.communities[cid]?.kinds) || DEFAULT_KINDS;

export const postableKinds = (state: AppState, cid: string, includeMods = true) =>
  kindsOf(state, cid).filter((k) => !k.mods || (includeMods && isMod(state, cid)));

export function kindInfo(state: AppState, cid: string | null | undefined, name: string): PostKind {
  return (
    kindsOf(state, cid).find((k) => k.name === name) ||
    Object.values(KIND_LIB).find((k) => k.name === name) || {
      name,
      icon: 'shapes',
      hue: 'ink',
      hint: 'Give it a title',
      body: 'Markdown, @mentions and #tags work here.',
      answers: false,
      mods: false,
      desc: null,
    }
  );
}

export const takesAnswers = (state: AppState, p: Post | null | undefined) =>
  !!(p && kindInfo(state, p.c, p.kind).answers);

export const post = (state: AppState, id: string | null | undefined) =>
  id ? (state.posts.find((p) => p.id === id) ?? null) : null;

export const postHref = (p: Post) => routes.post(p.c, p.id, p.title);

export const replyCountOf = (p: Post) => p.replyCount ?? p.replies.length;

export const CATCHUP_PER_COMMUNITY = 3;

// A post under review stays in its feed but isn't promoted until someone keeps it
const inCatchup = (state: AppState, p: Post) =>
  !p.seen &&
  !p.removed &&
  !p.pending &&
  !p.reported &&
  !p.inReview &&
  p.author !== state.me &&
  !!state.communities[p.c]?.joined;

const catchupScore = (p: Post) => {
  const hours = ageMinutes(p.age) / 60;

  return (p.pinned ? 1000 : 0) + p.helpful * 3 + replyCountOf(p) * 2 + Math.max(0, 72 - hours) / 6;
};

export const catchupCommunities = (state: AppState) =>
  joinedCids(state)
    .map((cid) => {
      const ranked = state.posts
        .filter((p) => p.c === cid && inCatchup(state, p))
        .sort((a, b) => catchupScore(b) - catchupScore(a));

      return {
        cid,
        c: state.communities[cid]!,
        fresh: ranked.slice(0, CATCHUP_PER_COMMUNITY),
        total: ranked.length,
        more: Math.max(0, ranked.length - CATCHUP_PER_COMMUNITY),
      };
    })
    .filter((x) => x.total || x.c.voice.some((v) => v.live));

export const unseenCount = (state: AppState) =>
  state.posts.filter((p) => inCatchup(state, p)).length;

export type FeedSort = 'active' | 'new' | 'top' | 'unanswered';

export function feed(
  state: AppState,
  cid: string,
  opts: { sort?: FeedSort; kind?: string; tag?: string | null } = {},
) {
  const { sort = 'active', kind = 'all', tag = null } = opts;
  let list = state.posts.filter((p) => p.c === cid && !p.removed && (tag || !p.pinned));

  if (tag) list = list.filter((p) => p.tags.includes(tag));
  if (kind !== 'all') list = list.filter((p) => p.kind === kind);
  if (sort === 'new') list = list.slice().sort((a, b) => ageMinutes(a.age) - ageMinutes(b.age));
  if (sort === 'top') list = list.slice().sort((a, b) => b.helpful - a.helpful);
  if (sort === 'unanswered') list = list.filter((p) => takesAnswers(state, p) && !p.answer);

  return list;
}

export const pinnedPosts = (state: AppState, cid: string) =>
  state.posts.filter((p) => p.c === cid && p.pinned && !p.removed);

export function feedEmpty(
  state: AppState,
  cid: string,
  opts: { sort: FeedSort; kind: string; tag: string | null },
) {
  const any = state.posts.some((p) => p.c === cid);
  const filtered = !!opts.tag || opts.kind !== 'all';

  if (opts.sort === 'unanswered' && !filtered)
    return {
      art: 'replies',
      title: 'Every question has an answer',
      text: 'Nice work, everyone.',
    } as const;

  if (filtered) {
    let text = 'Nothing of this kind yet. Pick another kind above.';

    if (opts.tag && opts.kind !== 'all') text = 'Try another kind, or clear the tag.';
    else if (opts.tag) text = `Nothing tagged #${opts.tag} yet. Clear the tag to see everything.`;

    return { art: 'filter', title: 'No posts match this filter', text } as const;
  }

  if (!any)
    return {
      art: 'posts',
      title: 'No posts yet',
      text: canDo(state, cid, 'post.create')
        ? 'Start the first one. Ask a question, or say what this community is for.'
        : 'When someone posts, it shows up here.',
    } as const;

  return {
    art: 'posts',
    title: 'Nothing new beyond the pinned posts',
    text: canDo(state, cid, 'post.create')
      ? 'Start a discussion and it shows up here.'
      : 'New posts show up here.',
  } as const;
}

export const seenPosts = (state: AppState) =>
  state.posts.filter((p) => p.seen && !p.removed && state.communities[p.c]?.joined).slice(0, 6);

export function allTags(state: AppState, cid?: string | null) {
  const set = new Set<string>();
  state.posts.filter((p) => !cid || p.c === cid).forEach((p) => p.tags.forEach((t) => set.add(t)));
  return Array.from(set).sort();
}

export const liveOnPost = (state: AppState, p: Post | null | undefined) =>
  p ? (state.communities[p.c]?.voice.find((v) => v.live && v.postId === p.id) ?? null) : null;

export const recordingFor = (state: AppState, postId: string) =>
  Object.values(state.recordings).find((r) => r.postId === postId) ?? null;

export const recordingsFor = (state: AppState, postId: string) =>
  Object.values(state.recordings)
    .filter((r) => r.postId === postId)
    .reverse();

export const transcriptFor = (state: AppState, postId: string) =>
  Object.values(state.transcripts).find((t) => t.postId === postId) ?? null;
