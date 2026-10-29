import { screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { patterns, routes } from '@/runtime/routes';
import { showScreen } from '@/test/show-screen';
import { ProfilePage } from './ProfilePage';

const own = { path: patterns.profile, url: routes.profile('danielbrai'), element: <ProfilePage /> };

describe('ProfilePage viewer', () => {
  it('shows no actions on your own profile while your session restores', async () => {
    await showScreen({ ...own, hint: true, session: 'loading', signedIn: true });

    expect(screen.queryByRole('button', { name: 'Message' })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Edit profile' })).not.toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Daniel Brai' })).toBeInTheDocument();
  });

  it('shows Edit profile on your own profile', async () => {
    await showScreen({ ...own, hint: true, session: 'ready', signedIn: true });

    expect(screen.getByRole('link', { name: 'Edit profile' })).toBeInTheDocument();
  });
});
