import { screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { patterns, routes } from '@/runtime/routes';
import { showScreen } from '@/test/show-screen';
import { JoinPage } from './JoinPage';

const invite = { path: patterns.join, url: routes.join('hw-8f3k2'), element: <JoinPage /> };

describe('JoinPage viewer', () => {
  it('shows no Join to a member while their session restores', async () => {
    await showScreen({ ...invite, hint: true, session: 'loading', signedIn: true });

    expect(screen.queryByRole('button', { name: /^Join / })).not.toBeInTheDocument();
    expect(screen.queryByText("You're already a member.")).not.toBeInTheDocument();
    expect(screen.getByRole('heading', { level: 1 })).toBeInTheDocument();
  });

  it('tells a member they already belong', async () => {
    await showScreen({ ...invite, hint: true, session: 'ready', signedIn: true });

    expect(screen.getByText("You're already a member.")).toBeInTheDocument();
  });
});
