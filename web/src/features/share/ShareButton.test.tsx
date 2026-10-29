import { act, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { RequestContext } from '@/app/request-context';
import { Store, StoreContext } from '@/data/store';
import { createSeedState } from '@/mocks/seed';
import { ShareButton } from './ShareButton';

const request = {
  origin: 'https://hearth.example',
  zone: 'UTC',
  signedIn: false,
  setStatus: () => undefined,
};

function show(store: Store) {
  return render(
    <RequestContext value={request}>
      <StoreContext value={store}>
        <ShareButton
          id="share"
          cid="elixir"
          path="/c/elixir"
          title="Elixir"
          label="Share community"
        />
      </StoreContext>
    </RequestContext>,
  );
}

afterEach(() => vi.unstubAllGlobals());

describe('ShareButton', () => {
  it('is hidden for a community outsiders cannot open', () => {
    const store = new Store(createSeedState());

    store.set((state) => (state.communities.elixir!.visibility = 'invite'));

    show(store);

    expect(screen.queryByRole('button', { name: 'Share community' })).toBeNull();
  });

  it('opens the system share sheet where there is one', async () => {
    const share = vi.fn(() => Promise.resolve());

    vi.stubGlobal('navigator', { ...navigator, share });
    show(new Store(createSeedState()));

    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Share community' })));

    expect(share).toHaveBeenCalledWith({ title: 'Elixir', url: 'https://hearth.example/c/elixir' });
    expect(screen.queryByRole('menu')).toBeNull();
  });

  it('falls back to a menu that copies the link', async () => {
    const writeText = vi.fn(() => Promise.resolve());

    vi.stubGlobal('navigator', { ...navigator, share: undefined, clipboard: { writeText } });
    show(new Store(createSeedState()));

    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Share community' })));
    await act(async () => fireEvent.click(screen.getByRole('menuitem', { name: /Copy link/ })));

    expect(writeText).toHaveBeenCalledWith('https://hearth.example/c/elixir');
    expect(screen.queryByRole('menu')).toBeNull();
  });

  it('links to each network in a new tab', async () => {
    vi.stubGlobal('navigator', { ...navigator, share: undefined });
    show(new Store(createSeedState()));

    await act(async () => fireEvent.click(screen.getByRole('button', { name: 'Share community' })));

    const reddit = screen.getByRole('menuitem', { name: 'Reddit' });

    expect(reddit.getAttribute('target')).toBe('_blank');
    expect(reddit.getAttribute('rel')).toBe('noopener noreferrer');
    expect(reddit.getAttribute('href')).toContain('reddit.com/submit');
  });
});
