import { describe, expect, it } from 'vitest';
import type { ProfileSpec } from '@/data/gateway';
import { gateway, me, routes, sent, session } from './test-support';

const spec: ProfileSpec = {
  name: 'Ada Lovelace',
  photo: null,
  bio: '',
  pronouns: 'she/her',
  location: '',
  links: [{ url: 'https://github.com/ada', label: '' }],
  private: true,
  presence: 'members',
  photoVis: 'everyone',
  commsVis: 'nobody',
};

const signedIn = async () => {
  routes['POST /api/auth/sessions'] = { status: 200, body: session };

  const { gateway: g, store } = gateway();

  await g.session.verifyCode('ada@example.com', '123456');

  return { g, store };
};

describe('profile', () => {
  it('shows why a save was refused', async () => {
    routes['PATCH /api/auth/me'] = {
      status: 422,
      body: { message: 'Unprocessable Content', errors: { bio: ['is too long'] } },
    };
    const { g } = await signedIn();

    expect(await g.profile.save(spec)).toEqual({ ok: false, error: 'bio is too long' });
  });

  it('saves the profile, links and privacy in one request', async () => {
    routes['PATCH /api/auth/me'] = {
      status: 200,
      body: {
        ...me,
        display_name: 'Ada Lovelace',
        links: [{ url: 'https://github.com/ada', label: null }],
        privacy: { ...me.privacy, show_name: false, presence: 'members' },
      },
    };

    const { g, store } = await signedIn();

    expect(await g.profile.save(spec)).toEqual({ ok: true, value: undefined });

    expect(sent.find((r) => r.method === 'PATCH')?.body).toEqual({
      avatar_id: null,
      display_name: 'Ada Lovelace',
      bio: null,
      pronouns: 'she/her',
      location: null,
      links: [{ url: 'https://github.com/ada', label: null }],
      privacy: {
        show_name: false,
        presence: 'members',
        avatar: 'everyone',
        show_communities: 'nobody',
      },
    });

    expect(store.get().people['u1']).toMatchObject({
      name: 'Ada Lovelace',
      private: true,
      links: [{ url: 'https://github.com/ada', label: null }],
      show: { presence: 'members' },
    });
  });

  it('keeps a photo already shown', async () => {
    routes['PATCH /api/auth/me'] = { status: 200, body: me };

    const { g } = await signedIn();

    await g.profile.save({ ...spec, photo: 'http://storage.test/w320.webp' });

    expect(sent.find((r) => r.method === 'PATCH')?.body).not.toHaveProperty('avatar_id');
  });
});
