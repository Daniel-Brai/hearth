import { render } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';

import { routes } from '@/runtime/routes';

import { RouteSkeleton } from './RouteSkeleton';

function show(path: string) {
  render(
    <MemoryRouter initialEntries={[path]}>
      <RouteSkeleton />
    </MemoryRouter>,
  );
}

describe('RouteSkeleton', () => {
  it('falls back to the feed for a screen with no shape of its own', () => {
    show(routes.community('elixir'));

    expect(document.querySelector('.skeleton--feed')).not.toBeNull();
  });

  it('shows a voice room as its room card and recordings', () => {
    show(routes.voice('elixir', 'office-hours'));

    expect(document.querySelector('.skeleton--voice')).not.toBeNull();
  });

  it('keeps a settings screen at its narrow width', () => {
    show(routes.settings);

    expect(document.querySelector('.measure--narrow .skeleton--settings')).not.toBeNull();
  });

  it('shows a transcript at reading width', () => {
    show(routes.session('elixir', 's1'));

    expect(document.querySelector('.measure--read .skeleton--transcript')).not.toBeNull();
  });
});
