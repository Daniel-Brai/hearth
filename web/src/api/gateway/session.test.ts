import { beforeEach, describe, expect, it, vi } from 'vitest';
import { SIGN_IN_AGAIN } from '@/data/gateway';
import { reloadApp } from '@/runtime/reload';
import { gateway, instance, me, routes, sent, session } from './test-support';

vi.mock('../realtime', () => ({ getRealtime: () => ({ onPush: () => () => undefined }) }));

vi.mock('@/runtime/reload', () => ({ reloadApp: vi.fn() }));

describe('session', () => {
  it('fails a wrong code with a sentence to show', async () => {
    routes['POST /api/auth/sessions'] = {
      status: 400,
      body: { message: 'Invalid code.', code: 'invalid_code' },
    };

    const r = await gateway().gateway.session.verifyCode('ada@example.com', '123456');

    expect(r).toEqual({ ok: false, error: "That code didn't work. Try again or send a new one." });
  });

  it('says when the server can not be reached', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(() => Promise.reject(new TypeError('Failed to fetch'))),
    );

    const r = await gateway().gateway.session.requestCode('ada@example.com');

    expect(r).toEqual({ ok: false, error: "Can't reach the Hearth server." });
  });

  it('signs in a known email', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };

    const { store, gateway: g } = gateway();

    const r = await g.session.verifyCode('ada@example.com', '123456');

    expect(r).toEqual({ ok: true, value: { known: true } });
    expect(store.get().me).toBe('u1');
    expect(store.get().people.u1?.username).toBe('ada');
  });

  it('signs up a new email with the token it was given', async () => {
    routes['POST /api/auth/sessions'] = { status: 202, body: { sign_up_token: 'st' } };
    routes['POST /api/auth/users'] = { status: 201, body: session };

    const { store, gateway: g } = gateway();

    expect(await g.session.verifyCode('ada@example.com', '123456')).toEqual({
      ok: true,
      value: { known: false },
    });

    const r = await g.session.completeSignup({
      email: 'ada@example.com',
      name: 'Ada',
      username: 'ada',
      private: false,
      photo: null,
    });

    expect(r.ok).toBe(true);

    expect(sent.find((r) => r.path === '/api/auth/users')?.body).toMatchObject({
      sign_up_token: 'st',
      username: 'ada',
    });

    expect(store.get().me).toBe('u1');
  });

  it('drops what the last person loaded when someone else signs in', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };

    const { store, gateway: g } = gateway();

    store.set((state) => {
      state.me = 'u0';
      state.communities.c0 = { name: 'Theirs' } as never;
    });

    await g.session.verifyCode('ada@example.com', '123456');

    expect(store.get().me).toBe('u1');
    expect(store.get().communities.c0).toBeUndefined();
  });

  it('sends the photo picked at sign up as the avatar', async () => {
    const media = { id: 'm1', status: 'processing', purpose: 'avatar' };

    routes['POST /api/auth/sessions'] = { status: 202, body: { sign_up_token: 'st' } };
    routes['POST /api/auth/users'] = { status: 201, body: session };

    routes['POST /api/uploads'] = {
      status: 201,
      body: {
        media,
        upload: { url: 'http://storage.test/avatar', headers: { 'content-type': 'image/png' } },
      },
    };

    routes['PUT /avatar'] = { status: 200 };
    routes['POST /api/uploads/m1/complete'] = { status: 200, body: media };

    routes['PATCH /api/auth/me'] = {
      status: 200,
      body: { ...me, avatar_id: 'm1', avatar_url: 'http://storage.test/w320.webp' },
    };

    const { gateway: g, store } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    const r = await g.session.completeSignup({
      email: null,
      name: 'Ada',
      username: 'ada',
      private: false,
      photo: 'data:image/png;base64,cG5n',
    });

    expect(r.ok).toBe(true);

    expect(sent.find((r) => r.path === '/api/uploads')?.body).toMatchObject({
      content_type: 'image/png',
      byte_size: 3,
      purpose: 'avatar',
    });

    expect(sent.find((r) => r.path === '/api/auth/me')?.body).toEqual({ avatar_id: 'm1' });
    expect(store.get().people['u1']?.photo).toBe('http://storage.test/w320.webp');
  });

  it('shows a field error from sign up', async () => {
    routes['POST /api/auth/sessions'] = { status: 202, body: { sign_up_token: 'st' } };

    routes['POST /api/auth/users'] = {
      status: 422,
      body: { message: 'Unprocessable Content', errors: { username: ['has already been taken'] } },
    };

    const { gateway: g } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    const r = await g.session.completeSignup({
      email: null,
      name: 'Ada',
      username: 'ada',
      private: false,
      photo: null,
    });

    expect(r).toEqual({ ok: false, error: 'username has already been taken' });
  });

  it('says whether a username is free', async () => {
    routes['GET /api/usernames/ada'] = { status: 200, body: { available: false } };

    expect(await gateway().gateway.session.usernameAvailable('ada')).toEqual({
      ok: true,
      value: false,
    });
  });

  it('loads the community templates once signed in', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };

    routes['GET /api/community-templates'] = {
      status: 200,
      body: [
        {
          id: 'blank',
          label: 'Start from scratch',
          icon: 'plus',
          description: 'Just a feed and #general',
          category: null,
          kinds: ['discussion'],
          rooms: ['general'],
          voice: null,
          event: null,
          placeholder: { name: 'Your community', tagline: 'What it is about' },
        },
      ],
    };

    const { store, gateway: g } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    await vi.waitFor(() =>
      expect(store.get().templates).toEqual([
        expect.objectContaining({ id: 'blank', desc: 'Just a feed and #general', category: '' }),
      ]),
    );
  });

  it('keeps the instance name, the ways to sign in and whether it screens and transcribes', async () => {
    routes['GET /api/instance'] = { status: 200, body: instance };

    routes['POST /api/auth/refresh'] = { status: 401, body: { code: 'invalid_refresh' } };

    const { store, gateway: g } = gateway();

    expect((await g.load.session()).ok).toBe(true);

    expect(store.get().instance).toMatchObject({
      name: 'Gardeners',
      signIn: ['email', 'github'],
      communityCreation: 'request',
      aiScreening: true,
      transcription: false,
      voice: true,
      recording: true,
    });

    expect(store.get().me).toBeNull();
  });
});

describe('signed in hint', () => {
  const hint = () => document.cookie.includes('hearth-signed-in=1');

  beforeEach(() => {
    document.cookie = 'hearth-signed-in=; path=/; max-age=0';
  });

  it('is cleared when the refresh is refused', async () => {
    document.cookie = 'hearth-signed-in=1; path=/';
    routes['GET /api/instance'] = { status: 200, body: instance };
    routes['POST /api/auth/refresh'] = { status: 401, body: { code: 'invalid_refresh' } };

    const { store, gateway: g } = gateway();

    await g.load.session();

    expect(hint()).toBe(false);
    expect(store.get().session).toBe('out');
  });

  it('is kept when the server can not be reached', async () => {
    document.cookie = 'hearth-signed-in=1; path=/';
    vi.stubGlobal(
      'fetch',
      vi.fn(() => Promise.reject(new TypeError('Failed to fetch'))),
    );

    const { gateway: g } = gateway();

    await g.load.session();

    expect(hint()).toBe(true);
  });

  it('is set when a session is restored', async () => {
    routes['GET /api/instance'] = { status: 200, body: instance };
    routes['POST /api/auth/refresh'] = { status: 200, body: session };
    routes['GET /api/auth/me'] = { status: 200, body: me };

    const { store, gateway: g } = gateway();

    await g.load.session();

    expect(hint()).toBe(true);
    expect(store.get().me).toBe('u1');
  });

  it('is set when someone signs in and the sidebar waits for the first loads', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };

    const { store, gateway: g } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    expect(hint()).toBe(true);
    expect(store.get().session).toBe('loading');

    await vi.waitFor(() => expect(store.get().session).toBe('ready'));
  });

  it('is cleared when the person signs out', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };
    routes['DELETE /api/auth/session'] = { status: 204 };

    const { store, gateway: g } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    g.session.signOut();

    expect(hint()).toBe(false);
    expect(store.get().session).toBe('out');
  });
});

describe('session.signOut', () => {
  it('reloads the app once the server has ended the session', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };
    routes['DELETE /api/auth/session'] = { status: 204 };

    const { gateway: g } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    g.session.signOut();

    await vi.waitFor(() => expect(reloadApp).toHaveBeenCalledWith('/signin'));
  });

  it('starts the next person from nothing of the last one', async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };
    routes['DELETE /api/auth/session'] = { status: 204 };

    const { store, gateway: g } = gateway();

    await g.session.verifyCode('ada@example.com', '123456');

    store.set((state) => {
      state.notifications = [{ id: 'n1' } as (typeof state.notifications)[number]];
    });

    g.session.signOut();

    routes['POST /api/auth/sessions'] = {
      status: 200,
      body: { ...session, user: { ...me, id: 'u2', username: 'sam' } },
    };

    await g.session.verifyCode('sam@example.com', '123456');

    expect(store.get().me).toBe('u2');
    expect(store.get().notifications).toEqual([]);
  });
});

describe('email change', () => {
  const signedIn = async () => {
    routes['POST /api/auth/sessions'] = { status: 200, body: session };

    const opened = gateway();

    await opened.gateway.session.verifyCode('ada@example.com', '123456');

    return opened;
  };

  it('asks for a fresh sign in when the session is old', async () => {
    const { gateway: g } = await signedIn();

    routes['POST /api/auth/me/email'] = {
      status: 400,
      body: { message: 'Sign in again.', code: 'sign_in_again' },
    };

    expect(await g.session.changeEmail('new@example.com')).toEqual({
      ok: false,
      error: SIGN_IN_AGAIN,
    });
  });

  it('sends the new address without spaces', async () => {
    const { gateway: g } = await signedIn();

    routes['POST /api/auth/me/email'] = { status: 204 };

    expect((await g.session.changeEmail(' new@example.com ')).ok).toBe(true);
    expect(sent.find((r) => r.path === '/api/auth/me/email')?.body).toEqual({
      email: 'new@example.com',
    });
  });

  it('fails a wrong code with a sentence to show', async () => {
    const { gateway: g } = await signedIn();

    routes['POST /api/auth/me/email/confirm'] = {
      status: 400,
      body: { message: 'Invalid code.', code: 'invalid_code' },
    };

    expect(await g.session.confirmEmail('000000')).toEqual({
      ok: false,
      error: "That code didn't work. Try again or send a new one.",
    });
  });

  it('keeps the new address once confirmed', async () => {
    const { gateway: g, store } = await signedIn();

    routes['POST /api/auth/me/email/confirm'] = {
      status: 200,
      body: { ...me, email: 'new@example.com' },
    };

    expect((await g.session.confirmEmail('042917')).ok).toBe(true);
    expect(store.get().people[me.id]?.email).toBe('new@example.com');
  });

  it('undoes a change with the token from the link', async () => {
    routes['POST /api/auth/email/undo'] = { status: 204 };

    expect((await gateway().gateway.session.undoEmailChange('tok')).ok).toBe(true);
    expect(sent.at(-1)?.body).toEqual({ token: 'tok' });
  });
});
