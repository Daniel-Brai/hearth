import { describe, expect, it, vi } from 'vitest';
import {
  at,
  community,
  gateway,
  kind,
  openPost,
  page,
  post,
  reply,
  routes,
  sent,
} from './test-support';

vi.mock('../realtime', () => ({ getRealtime: () => ({ onPush: () => () => undefined }) }));

const report = {
  c: 'gardeners',
  kind: 'Reply' as const,
  id: 'r1',
  reason: 'spam' as const,
  who: 'u1',
  where: 'on a post',
  text: 'Buy now',
};

const member = (permissions: string[]) => ({
  community,
  kinds: [kind],
  membership: { joined_at: at, roles: [], permissions },
});

const item = {
  id: 'q1',
  community_id: 'c1',
  room_id: null,
  subject_type: 'reply',
  subject_id: 'r1',
  source: 'report',
  status: 'pending',
  reason: null,
  score: null,
  note: null,
  report_count: 2,
  reports: [
    { reason: 'spam', note: null, inserted_at: at },
    { reason: 'hate', note: 'Slurs in the second line', inserted_at: at },
  ],
  author: post.author,
  reviewed_by: null,
  reviewed_at: null,
  inserted_at: at,
  subject: {
    id: 'r1',
    type: 'reply',
    title: null,
    body: 'Buy now',
    status: 'published',
    post_id: 'p1',
    room_id: null,
    conversation_id: null,
    author: post.author,
    attachments: [],
    inserted_at: at,
  },
};

describe('moderation.report', () => {
  it('says plainly when reports are off there', async () => {
    routes['POST /api/reports'] = { status: 400, body: { code: 'reports_off', message: 'Bad' } };

    expect(await gateway().gateway.moderation.report(report)).toEqual({
      ok: false,
      error: "Reports are off here, so this can't be reported.",
    });
  });

  it('says plainly when the same person reports it again', async () => {
    routes['POST /api/reports'] = {
      status: 400,
      body: { code: 'already_reported', message: 'Bad' },
    };

    const r = await gateway().gateway.moderation.report(report);

    expect(r.ok).toBe(false);
    expect(!r.ok && r.error).toMatch(/already reported/);
  });

  it('sends the reason and the note', async () => {
    routes['POST /api/reports'] = { status: 201, body: { queued: true } };

    const r = await gateway().gateway.moderation.report({ ...report, note: ' Spam link ' });

    expect(r).toEqual({ ok: true, value: { queued: true } });

    expect(sent.at(-1)?.body).toEqual({
      subject_type: 'reply',
      subject_id: 'r1',
      reason: 'spam',
      note: 'Spam link',
    });
  });
});

describe('moderation.removeContent', () => {
  it('asks for a reason before sending anything', async () => {
    const { gateway: g } = await openPost([reply('r1', 'Buy now')]);
    const before = sent.length;

    const r = await g.moderation.removeContent({ c: 'gardeners', kind: 'Reply', id: 'r1' }, '  ');

    expect(r.ok).toBe(false);
    expect(sent.length).toBe(before);
  });

  it('shows the reply as removed by a moderator', async () => {
    const { store, gateway: g } = await openPost([reply('r1', 'Buy now')]);

    routes['POST /api/moderation/remove'] = {
      status: 200,
      body: { subject_type: 'reply', subject_id: 'r1', status: 'removed' },
    };

    const r = await g.moderation.removeContent({ c: 'gardeners', kind: 'Reply', id: 'r1' }, 'Spam');

    expect(r.ok).toBe(true);
    expect(store.get().posts[0]?.replies[0]).toMatchObject({ removed: true, moderated: true });
  });
});

describe('moderation.ban', () => {
  it('sends a permanent ban with no end and the reason', async () => {
    routes['GET /api/communities/gardeners'] = { status: 200, body: member(['member.ban']) };
    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };

    routes['POST /api/communities/c1/bans'] = {
      status: 201,
      body: {
        id: 'b1',
        community_id: 'c1',
        user: post.author,
        banned_by: null,
        reason: 'Spam',
        expires_at: null,
        lifted_at: null,
        inserted_at: at,
      },
    };

    routes['GET /api/communities/c1/moderation/log'] = { status: 200, body: page([]) };

    const { store, gateway: g } = gateway();

    await g.load.community('gardeners');

    const r = await g.moderation.ban({
      c: 'gardeners',
      username: 'ada',
      reason: 'Spam',
      until: 'permanent',
    });

    expect(r.ok).toBe(true);

    expect(sent.find((s) => s.path === '/api/communities/c1/bans')?.body).toEqual({
      username: 'ada',
      reason: 'Spam',
      expires_at: null,
    });

    expect(store.get().bans[0]).toMatchObject({ id: 'b1', until: 'permanent', c: 'gardeners' });
  });
});

describe('load.moderation', () => {
  it('loads no queue for someone who can only ban', async () => {
    routes['GET /api/communities/gardeners'] = { status: 200, body: member(['member.ban']) };
    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };
    routes['GET /api/communities/c1/moderation/log'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/bans'] = { status: 200, body: [] };
    routes['GET /api/moderation/counts'] = { status: 200, body: { counts: {} } };

    const { gateway: g } = gateway();

    await g.load.community('gardeners');

    expect((await g.load.moderation('gardeners')).ok).toBe(true);
    expect(sent.some((s) => s.path.startsWith('/api/communities/c1/moderation/queue'))).toBe(false);
  });

  it('keeps each queued report with its reasons, never who sent it', async () => {
    routes['GET /api/communities/gardeners'] = { status: 200, body: member(['content.remove']) };
    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };
    routes['GET /api/communities/c1/moderation/log'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/moderation/queue'] = { status: 200, body: page([item]) };
    routes['GET /api/moderation/counts'] = { status: 200, body: { counts: { c1: 1 } } };

    const { store, gateway: g } = gateway();

    await g.load.community('gardeners');

    await g.load.moderation('gardeners');

    expect(store.get().queue[0]).toMatchObject({
      id: 'q1',
      c: 'gardeners',
      kind: 'Reply',
      source: 'report',
      reports: [{ reason: 'spam' }, { reason: 'hate', note: 'Slurs in the second line' }],
      subject: { type: 'reply', id: 'r1', postId: 'p1' },
    });

    expect(store.get().queueCounts).toEqual({ gardeners: 1 });
  });
});

describe('moderation log', () => {
  const entry = (id: string, action: string) => ({
    id,
    community_id: 'c1',
    action,
    subject_type: 'user',
    subject_id: 'u2',
    actor: post.author,
    target: { ...post.author, id: 'u2', username: 'sam' },
    reason: null,
    metadata: {},
    inserted_at: at,
  });

  it('says what a host did to someone in a voice room', async () => {
    routes['GET /api/communities/gardeners'] = { status: 200, body: member(['content.remove']) };
    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };
    routes['GET /api/communities/c1/moderation/queue'] = { status: 200, body: page([]) };
    routes['GET /api/moderation/counts'] = { status: 200, body: { counts: {} } };

    routes['GET /api/communities/c1/moderation/log'] = {
      status: 200,
      body: page([
        entry('l1', 'server_mute_lifted'),
        entry('l2', 'disconnected'),
        entry('l3', 'moved_to_listeners'),
      ]),
    };

    const { store, gateway: g } = gateway();

    await g.load.community('gardeners');

    await g.load.moderation('gardeners');

    expect(store.get().modlog.map((l) => l.text)).toEqual([
      'lifted the server mute on @sam',
      'disconnected @sam',
      'moved @sam to listeners',
    ]);
  });
});
