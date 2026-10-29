import { afterEach, beforeEach, vi } from 'vitest';
import { emptyState } from '@/data/empty-state';
import { Store } from '@/data/store';
import { ApiGateway } from '../api-gateway';
import { setAccessToken } from '../session-token';
import type { Post } from '@/generated/schemas';

type Route = { status: number; body?: unknown };

export let routes: Record<string, Route | Route[]>;
export let sent: { method: string; path: string; body: unknown }[];

export const at = new Date().toISOString();

export const me = {
  id: 'u1',
  username: 'ada',
  display_name: 'Ada',
  email: 'ada@example.com',
  avatar_id: null,
  avatar_url: null,
  bio: null,
  pronouns: null,
  location: null,
  timezone: null,
  locale: null,
  links: [],
  privacy: {
    show_name: true,
    show_communities: 'common',
    presence: 'everyone',
    last_seen: 'everyone',
    avatar: 'everyone',
  },
  settings: {
    theme: 'system',
    ui_sounds: true,
    play_sounds: true,
    captions_on: false,
    compact_feeds: false,
    sidebar_collapsed: false,
    tour_done: false,
    key_bindings: {},
    notification_prefs: {},
    digest: 'weekly',
  },
  is_instance_admin: false,
};

export const session = { access_token: 'token', token_type: 'Bearer', expires_in: 900, user: me };

export const community = {
  id: 'c1',
  slug: 'gardeners',
  name: 'Gardeners',
  tagline: null,
  description: null,
  hue: 'green',
  logo_id: null,
  logo_url: null,
  banner_id: null,
  banner_url: null,
  member_count: 1,
  owner: null,
  visibility: 'public',
  moderation: 'none',
  welcome_message: null,
  template: 'oss',
  owner_id: 'u1',
  links: [],
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
      archived_at: null,
    },
  ],
};

export const kind = {
  id: 'k1',
  key: 'question',
  label: 'Question',
  icon: 'q',
  hue: 'blue',
  description: null,
  title_hint: null,
  body_hint: null,
  answers: true,
  postable: true,
  position: 0,
};

export const post = {
  id: 'p1',
  community_id: 'c1',
  kind_id: 'k1',
  author: { id: 'u1', username: 'ada', display_name: 'Ada', avatar_id: null, avatar_url: null },
  title: 'Hi',
  body: 'Hello',
  status: 'published',
  pinned: false,
  locked: false,
  answer_reply_id: null,
  reply_count: 0,
  helpful_count: 0,
  last_activity_at: at,
  edited_at: null,
  inserted_at: at,
  attachments: [],
  reported: false,
  in_review: false,
  watching: false,
  live: null,
  from_chat: null,
  transcript: null,
  reactions: [],
  seen: false,
} satisfies Post;

export const reply = (id: string, body: string, parent: string | null = null) => ({
  id,
  post_id: 'p1',
  parent_reply_id: parent,
  author: post.author,
  body,
  child_count: 0,
  descendant_count: 0,
  depth: parent ? 1 : 0,
  status: 'published',
  deleted: false,
  helpful_count: 0,
  edited_at: null,
  inserted_at: at,
  attachments: [],
});

export const message = (id: string, body: string) => ({
  id,
  room_id: 'r1',
  conversation_id: null,
  reply_to_id: null,
  author: post.author,
  body,
  depth: 0,
  child_count: 0,
  status: 'published',
  deleted: false,
  edited_at: null,
  inserted_at: at,
  attachments: [],
  reactions: [],
  preview_hidden: false,
});

export const file = {
  id: '0195f0c4-0000-7000-8000-000000000001',
  name: 'plot.png',
  purpose: 'attachment',
  content_type: 'image/png',
  byte_size: 3,
  status: 'ready',
  failure: null,
  width: 800,
  height: 600,
  duration_ms: null,
  blurhash: null,
  urls: {
    original: 'https://storage.test/plot.png',
    variants: [
      { width: 400, height: 300, format: 'webp', url: 'https://storage.test/small.webp' },
      { width: 800, height: 600, format: 'webp', url: 'https://storage.test/plot.webp' },
    ],
  },
};

export const page = (data: unknown[]) => ({
  data,
  meta: { after: null, before: null, has_next: false, has_previous: false },
});

beforeEach(() => {
  setAccessToken(null);
  sent = [];
  routes = {};

  vi.stubGlobal(
    'fetch',
    vi.fn((url: string, init: RequestInit = {}) => {
      const method = init.method ?? 'GET';
      const path = new URL(url).pathname;
      const body = typeof init.body === 'string' ? JSON.parse(init.body) : (init.body ?? null);

      sent.push({ method, path, body });

      const route = routes[`${method} ${path}`];

      const answer = (Array.isArray(route) ? route.shift() : route) ?? {
        status: 404,
        body: { message: 'Not Found' },
      };

      return Promise.resolve(
        new Response(answer.body === undefined ? null : JSON.stringify(answer.body), {
          status: answer.status,
          headers: { 'content-type': 'application/json' },
        }),
      );
    }),
  );
});

afterEach(() => vi.unstubAllGlobals());

export const gateway = () => {
  const store = new Store(emptyState());
  return { store, gateway: new ApiGateway(store) };
};

export const openPost = async (replies: unknown[] = [], changes: Record<string, unknown> = {}) => {
  routes['GET /api/posts/p1'] = { status: 200, body: { ...post, ...changes } };

  routes['GET /api/communities/c1'] = {
    status: 200,
    body: { community, kinds: [kind], membership: null },
  };

  routes['GET /api/posts/p1/replies'] = { status: 200, body: page(replies) };

  const opened = gateway();

  await opened.gateway.load.post('p1');

  opened.store.set((state) => {
    state.me = me.id;
  });

  return opened;
};
