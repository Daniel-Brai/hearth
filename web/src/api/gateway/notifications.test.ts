import { describe, expect, it, vi } from 'vitest';
import { unreadNotifications } from '@/domain/selectors';
import { at, gateway, routes, sent, session } from './test-support';

const notification = (id: string, kind: string, data: Record<string, unknown>) => ({
  id,
  kind,
  actor: { id: 'u2', username: 'bo', display_name: 'Bo', avatar_id: null, avatar_url: null },
  community_id: 'c1',
  subject_type: 'reply',
  subject_id: 'x',
  data,
  read_at: null,
  inserted_at: at,
});

describe('notifications', () => {
  it('lists them once signed in, leaving direct messages to the conversations', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };

    routes['GET /api/notifications'] = {
      status: 200,
      body: {
        data: [
          notification('n1', 'reply', {
            community_slug: 'gardeners',
            post_id: 'p1',
            post_title: 'Tomatoes',
          }),
          notification('n2', 'dm', {}),
        ],
        meta: {},
        unread: 2,
      },
    };

    const { gateway: g, store } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(store.get().notifications).toEqual([
      expect.objectContaining({
        id: 'n1',
        who: 'u2',
        target: 'Tomatoes',
        href: '/c/gardeners/p/p1-tomatoes',
      }),
    ]);
  });

  it('marks everything read at once', async () => {
    routes['POST /api/notifications/read'] = { status: 204 };

    const { gateway: g } = gateway();

    g.notifications.markAllRead();
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(sent.some((r) => r.method === 'POST' && r.path === '/api/notifications/read')).toBe(
      true,
    );
  });

  it('asks nothing when no earlier page is left', async () => {
    const { gateway: g } = gateway();

    await g.notifications.loadEarlier();

    expect(sent).toEqual([]);
  });

  it('counts the unread ones beyond the first page', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };

    routes['GET /api/notifications'] = {
      status: 200,
      body: {
        data: [notification('n1', 'reply', { community_slug: 'gardeners', post_id: 'p1' })],
        meta: { after: 'n1', before: null, has_next: true, has_previous: false },
        unread: 100,
      },
    };

    const { gateway: g, store } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');
    await new Promise((resolve) => setTimeout(resolve, 0));

    expect(unreadNotifications(store.get())).toBe(100);
    g.notifications.markAllRead();
    expect(unreadNotifications(store.get())).toBe(0);
  });

  it('adds the next older page and stops at the end', async () => {
    routes['GET /api/notifications'] = {
      status: 200,
      body: {
        data: [notification('n9', 'reply', { community_slug: 'gardeners', post_id: 'p9' })],
        meta: { after: 'n9', before: 'n9', has_next: false, has_previous: true },
        unread: 0,
      },
    };

    const { gateway: g, store } = gateway();

    store.set((state) => (state.notificationsAfter = 'n8'));

    await g.notifications.loadEarlier();

    expect(String(vi.mocked(fetch).mock.calls.at(-1)?.[0])).toContain('after=n8');
    expect(store.get().notifications.map((n) => n.id)).toEqual(['n9']);
    expect(store.get().notificationsAfter).toBeNull();
  });
});
