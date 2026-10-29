import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { Suspense } from 'react';
import { createMemoryRouter, RouterProvider } from 'react-router';
import { describe, expect, it } from 'vitest';
import { GatewayContext } from '@/app/gateway-context';
import { RequestContext } from '@/app/request-context';
import { Store, StoreContext } from '@/data/store';
import { LoadCache, LoadCacheContext } from '@/data/use-load';
import { MockGateway } from '@/mocks/gateway';
import type { CommunityVisibility } from '@/domain/types';
import { createSeedState } from '@/mocks/seed';
import { routes } from '@/runtime/routes';
import { PostPage } from './PostPage';

async function show(
  c: string,
  id: string,
  visibility: CommunityVisibility = 'public',
  transcription = true,
) {
  const store = new Store(createSeedState());

  store.set((state) => {
    state.communities[c]!.visibility = visibility;
    state.instance.transcription = transcription;
  });

  const router = createMemoryRouter([{ path: '/c/:community/p/:post', element: <PostPage /> }], {
    initialEntries: [routes.post(c, id)],
  });

  await act(async () =>
    render(
      <LoadCacheContext value={new LoadCache()}>
        <StoreContext value={store}>
          <GatewayContext value={new MockGateway(store)}>
            <Suspense fallback={null}>
              <RouterProvider router={router} />
            </Suspense>
          </GatewayContext>
        </StoreContext>
      </LoadCacheContext>,
    ),
  );

  return store;
}

async function showAsGuest(hint: boolean) {
  const store = new Store(createSeedState());

  store.set((state) => {
    state.me = null;
    state.session = 'pending';
  });

  const request = {
    origin: 'https://hearth.example',
    zone: 'UTC',
    signedIn: hint,
    setStatus: () => {},
  };

  const router = createMemoryRouter([{ path: '/c/:community/p/:post', element: <PostPage /> }], {
    initialEntries: [routes.post('elixir', 'p1')],
  });

  await act(async () =>
    render(
      <RequestContext value={request}>
        <LoadCacheContext value={new LoadCache()}>
          <StoreContext value={store}>
            <GatewayContext value={new MockGateway(store)}>
              <Suspense fallback={null}>
                <RouterProvider router={router} />
              </Suspense>
            </GatewayContext>
          </StoreContext>
        </LoadCacheContext>
      </RequestContext>,
    ),
  );
}

const openMenu = () => fireEvent.click(screen.getByRole('button', { name: 'Post options' }));

const startEditing = async (title: string, body: string) => {
  openMenu();
  fireEvent.click(screen.getByRole('menuitem', { name: 'Edit' }));

  fireEvent.change(await screen.findByRole('textbox', { name: 'Title' }), {
    target: { value: title },
  });

  fireEvent.change(screen.getByRole('textbox', { name: 'Post text' }), {
    target: { value: body },
  });
};

describe('PostPage', () => {
  it('offers no Edit on someone else’s post', async () => {
    await show('elixir', 'p1');

    openMenu();

    expect(screen.queryByRole('menuitem', { name: 'Edit' })).toBeNull();
  });

  it('puts the post back as it was on Cancel', async () => {
    const store = await show('plang', 'p8');
    const before = store.get().posts.find((p) => p.id === 'p8')!;

    await startEditing('Another title', 'Other words');
    fireEvent.click(screen.getByRole('button', { name: 'Cancel' }));

    expect(screen.getByRole('heading', { name: before.title })).toBeTruthy();
    expect(screen.queryByRole('textbox', { name: 'Title' })).toBeNull();
    expect(store.get().posts.find((p) => p.id === 'p8')?.title).toBe(before.title);
  });

  it('cancels on Esc', async () => {
    await show('plang', 'p8');

    await startEditing('Another title', 'Other words');
    fireEvent.keyDown(screen.getByRole('textbox', { name: 'Post text' }), { key: 'Escape' });

    expect(screen.queryByRole('textbox', { name: 'Title' })).toBeNull();
  });

  it('saves the title and body and marks the post edited', async () => {
    await show('plang', 'p8');

    await startEditing('A paper a month', 'First up is the Lambda paper.');

    fireEvent.keyDown(screen.getByRole('textbox', { name: 'Post text' }), {
      key: 'Enter',
      ctrlKey: true,
    });

    await waitFor(() =>
      expect(screen.getByRole('heading', { name: 'A paper a month' })).toBeTruthy(),
    );

    expect(screen.getByText('First up is the Lambda paper.')).toBeTruthy();
    expect(screen.getByText('edited').getAttribute('data-tip')).toMatch(/^Edited /);
  });

  it('closes replies when a moderator locks the post', async () => {
    const store = await show('elixir', 'p1');

    act(() =>
      store.set((state) => {
        state.roles.find((r) => r.c === 'elixir' && r.id === 'moderator')!.members.push(state.me!);
      }),
    );

    openMenu();
    fireEvent.click(screen.getByRole('menuitem', { name: 'Lock replies' }));

    await waitFor(() => expect(document.getElementById('post-locked-note')).toBeTruthy());

    expect(document.getElementById('reply-box')).toBeNull();
    expect(store.get().posts.find((p) => p.id === 'p1')?.locked).toBe(true);
  });

  it('leaves Copy link to Share in a public community', async () => {
    await show('elixir', 'p1');

    openMenu();

    expect(screen.getByRole('button', { name: 'Share post' })).toBeTruthy();
    expect(screen.queryByRole('menuitem', { name: 'Copy link' })).toBeNull();
  });

  it('offers Copy link in the menu of an invite only community', async () => {
    await show('elixir', 'p1', 'invite');

    openMenu();

    expect(screen.queryByRole('button', { name: 'Share post' })).toBeNull();
    expect(screen.getByRole('menuitem', { name: 'Copy link' })).toBeTruthy();
  });

  // jsdom applies no media queries so these check which items are marked for phones only
  it('moves Share and Watch into the menu on phones', async () => {
    await show('elixir', 'p1');

    openMenu();

    expect(screen.getByRole('button', { name: 'Share post' }).closest('.hide-mobile')).toBeTruthy();
    expect(screen.getByRole('menuitem', { name: 'Share' }).classList).toContain('mobile-only');
    expect(screen.getByRole('menuitem', { name: /watch/i }).classList).toContain('mobile-only');
  });

  it('keeps Share out of the menu of an invite only community', async () => {
    await show('elixir', 'p1', 'invite');

    openMenu();

    expect(screen.queryByRole('menuitem', { name: 'Share' })).toBeNull();
  });

  it('offers no Report on a post that was removed', async () => {
    const store = await show('elixir', 'p1');

    act(() =>
      store.set((state) => {
        state.communities.elixir!.moderation = 'reports';
      }),
    );

    openMenu();
    expect(screen.getByRole('menuitem', { name: 'Report' })).toBeTruthy();
    openMenu();

    act(() =>
      store.set((state) => {
        state.posts.find((p) => p.id === 'p1')!.removed = true;
      }),
    );

    openMenu();

    expect(screen.queryByRole('menuitem', { name: 'Report' })).toBeNull();
  });

  it('hides the transcript where the instance does not transcribe', async () => {
    await show('elixir', 'p1', 'public', false);

    expect(screen.queryByRole('link', { name: 'Transcript' })).toBeNull();
  });

  it('links the transcript where the instance transcribes', async () => {
    await show('elixir', 'p1');

    expect(screen.getByRole('link', { name: 'Transcript' })).toBeTruthy();
  });

  it('offers a guest the sign in prompts without the hint', async () => {
    await showAsGuest(false);

    expect(document.getElementById('guest-reply-note')).not.toBeNull();
    expect(screen.getByRole('button', { name: /Helpful/ })).toBeInTheDocument();
  });

  it('shows no sign in prompt while the viewer is unknown', async () => {
    await showAsGuest(true);

    expect(screen.getByRole('heading', { level: 1 })).toBeInTheDocument();
    expect(document.getElementById('guest-reply-note')).toBeNull();
    expect(screen.queryByRole('button', { name: 'Sign in' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Helpful ·/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('textbox')).not.toBeInTheDocument();
  });
});
