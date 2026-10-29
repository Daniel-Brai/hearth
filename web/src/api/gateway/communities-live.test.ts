import { describe, expect, it, vi } from 'vitest';
import { community, gateway, kind, page, routes } from './test-support';

type Handler = (payload: Record<string, unknown>) => void;

const pushes = vi.hoisted(() => new Map<string, Handler>());

vi.mock('../realtime', () => ({
  getRealtime: () => ({
    onPush: (topic: string, event: string, handler: Handler) => {
      pushes.set(`${topic} ${event}`, handler);
      return () => pushes.delete(`${topic} ${event}`);
    },
  }),
}));

describe('a community being viewed', () => {
  it('updates the online count the server pushes', async () => {
    routes['GET /api/communities/gardeners'] = {
      status: 200,
      body: { community: { ...community, online_count: 4 }, kinds: [kind], membership: null },
    };

    routes['GET /api/communities/c1/posts'] = { status: 200, body: page([]) };
    routes['GET /api/communities/c1/posts/pinned'] = { status: 200, body: [] };

    const { store, gateway: g } = gateway();

    await g.load.community('gardeners');
    pushes.get('community:c1 online_count')!({ community_id: 'c1', count: 7 });

    expect(store.get().communities.gardeners?.online).toBe(7);
  });
});
