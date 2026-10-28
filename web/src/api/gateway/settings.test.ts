import { describe, expect, it } from 'vitest';
import { gateway, me, routes, sent, session } from './test-support';

const admin = { ...session, user: { ...session.user, is_instance_admin: true } };

const signedIn = async () => {
  routes['POST /api/auth/sessions'] = { status: 200, body: session };

  const { gateway: g, store } = gateway();

  await g.session.verifyCode('ada@example.com', '123456');

  return { g, store };
};

const settled = () => new Promise((resolve) => setTimeout(resolve, 0));

describe('settings', () => {
  it('reads the settings kept on the account', async () => {
    const { store } = await signedIn();

    expect(store.get().settings).toMatchObject({ digest: 'weekly', tourDone: false });
  });

  it('puts a refused change back', async () => {
    routes['PATCH /api/auth/me/settings'] = { status: 422, body: { message: 'Unprocessable' } };

    const { g, store } = await signedIn();

    g.settings.update({ compact: true });
    expect(store.get().settings.compact).toBe(true);

    await settled();
    expect(store.get().settings.compact).toBe(false);
  });

  it('sends quick changes in order and undoes only the one refused', async () => {
    routes['PATCH /api/auth/me/settings'] = [
      { status: 422, body: { message: 'Unprocessable' } },
      {
        status: 200,
        body: {
          ...me.settings,
          notification_prefs: { replies: true, mentions: true, live: false },
        },
      },
    ];

    const { g, store } = await signedIn();

    g.settings.update({ compact: true });
    g.settings.update({ notifyLive: false });
    await settled();
    await settled();

    expect(
      sent.filter((r) => r.method === 'PATCH').map((r) => Object.keys(r.body as object)),
    ).toEqual([['compact_feeds'], ['notification_prefs']]);

    expect(store.get().settings.compact).toBe(false);
    expect(store.get().settings.notifyLive).toBe(false);
  });

  it('sends every notification choice when one changes', async () => {
    routes['PATCH /api/auth/me/settings'] = {
      status: 200,
      body: { ...me.settings, notification_prefs: { replies: true, mentions: false, live: true } },
    };

    const { g, store } = await signedIn();

    g.settings.update({ notifyMentions: false, digest: 'never' });
    await settled();

    expect(sent.find((r) => r.method === 'PATCH')?.body).toEqual({
      digest: 'off',
      notification_prefs: { replies: true, mentions: false, live: true },
    });

    expect(store.get().settings.notifyMentions).toBe(false);
  });

  it('shows why the instance setting was refused', async () => {
    routes['PATCH /api/instance'] = { status: 403, body: { message: 'Forbidden' } };
    const { g } = await signedIn();

    expect(await g.settings.setInstanceCreation('anyone')).toEqual({
      ok: false,
      error: 'Forbidden',
    });
  });
});

describe('load.screening', () => {
  it('asks nothing for someone who is not an instance admin', async () => {
    const { g, store } = await signedIn();

    expect((await g.load.screening()).ok).toBe(true);
    expect(sent.some((r) => r.path === '/api/instance/screening')).toBe(false);
    expect(store.get().instance.screening).toBeNull();
  });

  it("keeps the last month's screening for an instance admin", async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: admin };

    routes['GET /api/instance/screening'] = {
      status: 200,
      body: {
        threshold: 0.5,
        days: [{ day: '2026-10-27', screened: 12, held: 2, kept: 1, removed: 1 }],
      },
    };

    const { gateway: g, store } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    expect((await g.load.screening()).ok).toBe(true);

    expect(store.get().instance.screening).toEqual({
      period: 30,
      threshold: 0.5,
      days: [{ day: '2026-10-27', screened: 12, held: 2, kept: 1, removed: 1 }],
    });
  });
});

describe('push', () => {
  it('says a browser with no push support has none', async () => {
    const { g, store } = await signedIn();

    store.set((state) => (state.instance.pushKey = 'key'));

    expect(await g.settings.pushStatus()).toBe('unsupported');
  });

  it('fails to turn on where the server sends no pushes', async () => {
    const { g } = await signedIn();

    expect(await g.settings.setPush(true)).toEqual({
      ok: false,
      error: "This server doesn't send push notifications.",
    });
  });
});
