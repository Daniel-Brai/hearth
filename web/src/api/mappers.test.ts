import { describe, expect, it } from 'vitest';
import type { ChatMessage, Community, CommunityDetail, Post, Reply } from '@/generated/schemas';
import { ageOf, hueOf, paragraphs, toCommunity, toMessage, toPost, toReply } from './mappers';

const at = (minutesAgo: number) => new Date(Date.now() - minutesAgo * 60_000).toISOString();

const community: Community = {
  id: 'c1',
  slug: 'gardeners',
  name: 'gardeners',
  tagline: null,
  description: 'Growing things',
  hue: 'green',
  logo_id: null,
  logo_url: null,
  banner_id: null,
  banner_url: null,
  member_count: 3,
  online_count: 2,
  owner: null,
  visibility: 'invite_only',
  moderation: 'none',
  welcome_message: null,
  template: 'blank',
  owner_id: 'u1',
  links: [{ url: 'https://example.com', label: null }],
  categories: [],
  rooms: [
    {
      id: 'r1',
      community_id: 'c1',
      type: 'text',
      slug: 'general',
      name: 'general',
      topic: null,
      position: 0,
      moderation: null,
      access: 'everyone',
      archived_at: null,
    },
    {
      id: 'r2',
      community_id: 'c1',
      type: 'voice',
      slug: 'lounge',
      name: 'Lounge',
      topic: 'Hang out',
      position: 1,
      moderation: null,
      access: 'everyone',
      archived_at: null,
    },
    {
      id: 'r3',
      community_id: 'c1',
      type: 'text',
      slug: 'old',
      name: 'old',
      topic: null,
      position: 2,
      moderation: null,
      access: 'everyone',
      archived_at: at(5),
    },
  ],
};

describe('ageOf', () => {
  it('writes ages the way the app reads them', () => {
    expect(ageOf(at(0))).toBe('now');
    expect(ageOf(at(5))).toBe('5m');
    expect(ageOf(at(180))).toBe('3h');
    expect(ageOf(at(2 * 1440))).toBe('2d');
  });
});

describe('hueOf', () => {
  it('keeps one hue per person', () => {
    expect(hueOf('abc')).toBe(hueOf('abc'));
  });
});

describe('paragraphs', () => {
  it('splits on blank lines and drops empty ones', () => {
    expect(paragraphs('One\n\n\n\nTwo')).toEqual(['One', 'Two']);
    expect(paragraphs(null)).toEqual([]);
  });
});

describe('toCommunity', () => {
  it('shows the logo, banner and member count the server sends', () => {
    const c = toCommunity(
      { ...community, logo_url: 'https://cdn/logo.webp', banner_url: 'https://cdn/banner.webp' },
      null,
    );

    expect(c).toMatchObject({
      logo: 'https://cdn/logo.webp',
      banner: 'https://cdn/banner.webp',
      members: 3,
    });
  });

  it('leaves out archived rooms and splits text from voice', () => {
    const c = toCommunity(community);

    expect(c.rooms.map((r) => r.id)).toEqual(['general']);
    expect(c.voice.map((r) => r.id)).toEqual(['lounge']);
    expect(c.visibility).toBe('invite');
    expect(c.letter).toBe('G');
    expect(c.links).toEqual([{ label: 'https://example.com', url: 'https://example.com' }]);
  });

  it('is not joined without a membership, and keeps only known permissions', () => {
    const detail: CommunityDetail = { community, kinds: [], membership: null };

    expect(toCommunity(community, detail).joined).toBe(false);

    const member: CommunityDetail = {
      community,
      kinds: [],
      membership: {
        roles: [],
        joined_at: at(1),
        permissions: ['post.create', 'not.a.permission' as 'post.create'],
      },
    };

    expect(toCommunity(community, member).permissions).toEqual(['post.create']);
  });
});

describe('toPost and toReply', () => {
  it('keeps the post in its community and kind, by their store keys', () => {
    const post = {
      id: 'p1',
      community_id: 'c1',
      kind_id: 'k1',
      author: { id: 'u1', username: 'ada', display_name: null, avatar_id: null, avatar_url: null },
      title: 'Hi',
      body: 'Hello\n\nThere',
      status: 'published',
      pinned: true,
      locked: false,
      answer_reply_id: null,
      reply_count: 0,
      helpful_count: 2,
      last_activity_at: at(1),
      edited_at: null,
      inserted_at: at(1),
      attachments: [],
      reported: false,
      in_review: false,
      watching: true,
      live: null,
      from_chat: null,
      transcript: null,
      reactions: [],
      seen: false,
    } satisfies Post;

    expect(toPost(post, 'gardeners', 'Question')).toMatchObject({
      c: 'gardeners',
      kind: 'Question',
      author: 'u1',
      body: ['Hello', 'There'],
      pinned: true,
      watching: true,
      helpful: 2,
    });
  });

  it('shows a deleted reply as removed', () => {
    const reply = {
      id: 'r1',
      post_id: 'p1',
      parent_reply_id: null,
      author: null,
      body: null,
      depth: 0,
      child_count: 1,
      descendant_count: 1,
      helpful_count: 0,
      status: 'published',
      deleted: true,
      edited_at: null,
      inserted_at: at(1),
      attachments: [],
    } satisfies Reply;

    expect(toReply(reply)).toMatchObject({ removed: true, who: '', body: [] });
  });
});

describe('toMessage', () => {
  it('keeps the message it answers', () => {
    const message = {
      id: 'm2',
      room_id: 'r1',
      conversation_id: null,
      reply_to_id: 'm1',
      author: { id: 'u1', username: 'ada', display_name: 'Ada', avatar_id: null, avatar_url: null },
      body: 'Yes',
      depth: 1,
      child_count: 0,
      status: 'published',
      kind: 'text',
      post_id: null,
      deleted: false,
      edited_at: null,
      inserted_at: at(1),
      attachments: [],
      reactions: [{ emoji: '🔥', count: 2, mine: true }],
      preview_hidden: false,
    } satisfies ChatMessage;

    expect(toMessage(message)).toMatchObject({
      id: 'm2',
      who: 'u1',
      text: 'Yes',
      parent: 'm1',
      boosts: [{ e: '🔥', n: 2, mine: true }],
    });
  });

  it('shows a promoted note as a line pointing at the post', () => {
    const message = {
      id: 'm3',
      room_id: 'r1',
      conversation_id: null,
      reply_to_id: null,
      author: { id: 'u1', username: 'ada', display_name: 'Ada', avatar_id: null, avatar_url: null },
      body: 'GenServer state after a restart',
      depth: 0,
      child_count: 0,
      status: 'published',
      kind: 'promoted',
      post_id: 'p9',
      deleted: false,
      edited_at: null,
      inserted_at: at(1),
      attachments: [],
      reactions: [],
      preview_hidden: false,
    } satisfies ChatMessage;

    expect(toMessage(message)).toMatchObject({
      system: true,
      promoted: { id: 'p9', title: 'GenServer state after a restart' },
    });
  });
});
