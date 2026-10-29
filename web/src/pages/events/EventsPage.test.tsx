import { screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { patterns, routes } from '@/runtime/routes';
import { showScreen } from '@/test/show-screen';
import { EventsPage } from './EventsPage';

const runclub = {
  path: patterns.communityEvents,
  url: routes.communityEvents('runclub'),
  element: <EventsPage />,
};

describe('EventsPage viewer', () => {
  it('shows no interest button while your session restores', async () => {
    await showScreen({ ...runclub, hint: true, session: 'loading', signedIn: true });

    expect(screen.queryByRole('button', { name: 'Interested' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Mark interested' })).not.toBeInTheDocument();
    expect(screen.getByText('Saturday beginners run')).toBeInTheDocument();
  });

  it('shows the events you are interested in', async () => {
    await showScreen({ ...runclub, hint: true, session: 'ready', signedIn: true });

    expect(screen.getAllByRole('button', { name: 'Interested' }).length).toBeGreaterThan(0);
  });
});
