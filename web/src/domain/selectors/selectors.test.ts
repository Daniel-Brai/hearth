// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { createSeedState } from '@/mocks/seed';
import type { Post } from '@/domain/types';
import {
  CATCHUP_PER_COMMUNITY,
  canDo,
  catchupCommunities,
  feed,
  feedEmpty,
  isMod,
  modLevel,
  myRolesIn,
  sharesCommunity,
  unseenCount,
} from '.';

const state = createSeedState();

describe('permissions follow roles per community', () => {
  it('gives the owner everything and a plain member only the member permissions', () => {
    expect(canDo(state, 'plang', 'role.update')).toBe(true);
    expect(canDo(state, 'elixir', 'content.remove')).toBe(false);
    expect(canDo(state, 'elixir', 'post.create')).toBe(true);
  });

  it('treats someone with no role in a joined community as a member', () => {
    expect(myRolesIn(state, 'phoenix')).toEqual(['member']);
  });

  it('refuses everything in a community the person has not joined', () => {
    expect(canDo(state, 'tauri', 'post.create')).toBe(false);
    expect(isMod(state, 'tauri')).toBe(false);
  });
});

describe('moderation level', () => {
  it('lets a room turn moderation down but never up', () => {
    const lowered = createSeedState();

    lowered.roomSettings['elixir/help'] = {
      topic: null,
      previews: true,
      moderation: 'reports',
      sounds: { enabled: true, mode: 'everyone', roles: [], people: [] },
    };

    lowered.roomSettings['runclub/general'] = {
      topic: null,
      previews: true,
      moderation: 'full',
      sounds: { enabled: true, mode: 'everyone', roles: [], people: [] },
    };

    expect(modLevel(lowered, 'elixir', 'help')).toBe('reports');
    expect(modLevel(lowered, 'runclub', 'general')).toBe('none');
  });
});

describe('feed', () => {
  it('keeps pinned posts out of the main list unless a tag is set', () => {
    expect(feed(state, 'elixir').some((p) => p.pinned)).toBe(false);
    expect(feed(state, 'elixir', { tag: 'release' }).some((p) => p.pinned)).toBe(true);
  });

  it('explains an empty filtered feed by the filter that emptied it', () => {
    expect(
      feedEmpty(state, 'elixir', { sort: 'active', kind: 'all', tag: 'nothing-here' }).title,
    ).toBe('No posts match this filter');
    expect(feedEmpty(state, 'tauri', { sort: 'unanswered', kind: 'all', tag: null }).title).toBe(
      'Every question has an answer',
    );
  });
});

describe('catchupCommunities', () => {
  const withPosts = (posts: Partial<Post>[]) => {
    const fresh = createSeedState();
    const base = fresh.posts.find((p) => p.c === 'elixir')!;

    fresh.posts = posts.map((patch, i) => ({
      ...base,
      id: 'x' + i,
      author: 'ada',
      seen: false,
      pinned: false,
      removed: false,
      pending: false,
      reported: false,
      inReview: false,
      helpful: 0,
      replies: [],
      replyCount: 0,
      age: '1h',
      ...patch,
    }));

    return fresh;
  };

  const elixir = (s: ReturnType<typeof createSeedState>) =>
    catchupCommunities(s).find((g) => g.cid === 'elixir');

  it('leaves out removed, held, reported, in review and your own posts', () => {
    const s = withPosts([
      { removed: true },
      { pending: true },
      { reported: true },
      { inReview: true },
      { author: 'dan' },
      { seen: true },
      { id: 'keep' },
    ]);

    expect(elixir(s)?.fresh.map((p) => p.id)).toEqual(['keep']);
    expect(unseenCount(s)).toBe(1);
  });

  it('shows at most three per community and counts the rest', () => {
    const g = elixir(withPosts([{}, {}, {}, {}, {}]));

    expect(g?.fresh).toHaveLength(CATCHUP_PER_COMMUNITY);
    expect(g?.total).toBe(5);
    expect(g?.more).toBe(2);
  });

  it('puts pinned posts first, then what people engage with', () => {
    const s = withPosts([
      { id: 'quiet' },
      { id: 'liked', helpful: 4 },
      { id: 'pinned', pinned: true },
      { id: 'talked', replyCount: 3 },
    ]);

    expect(elixir(s)?.fresh.map((p) => p.id)).toEqual(['pinned', 'liked', 'talked']);
  });
});

describe('sharesCommunity', () => {
  it('is false for someone with no shared community and true for a shared maintainer', () => {
    expect(sharesCommunity(state, 'kai')).toBe(false);
    expect(sharesCommunity(state, 'tobi')).toBe(true);
  });
});
