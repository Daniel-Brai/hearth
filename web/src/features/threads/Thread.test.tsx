import { act, fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it, vi } from 'vitest';
import { Store, StoreContext } from '@/data/store';
import { createSeedState } from '@/mocks/seed';
import { Thread } from './Thread';
import { buildTree } from './tree';

type Item = { id: string; parent: string | null; who: string; direct?: number; total?: number };

const show = (node: ReturnType<typeof buildTree<Item>>, onOpen = vi.fn(async () => undefined)) => {
  render(
    <MemoryRouter>
      <StoreContext value={new Store(createSeedState())}>
        <Thread
          node={node}
          className="thread--post"
          keyOf={(x) => x.id}
          authorOf={(x) => x.who}
          renderItem={(x) => <p>{x.id}</p>}
          serverCount={(x) => (x.direct ? { direct: x.direct, total: x.total ?? x.direct } : null)}
          onOpen={onOpen}
        />
      </StoreContext>
    </MemoryRouter>,
  );

  return onOpen;
};

describe('Thread', () => {
  it('shows nothing to open when the server holds no replies', () => {
    show(buildTree({ id: 'a', parent: null, who: 'ada' }, [], 2, (x) => x.who));

    expect(screen.queryByRole('button', { name: /Expand/ })).toBeNull();
  });

  it('offers replies the server holds but the screen has not loaded', async () => {
    const root: Item = { id: 'a', parent: null, who: 'ada', direct: 2, total: 4 };
    const onOpen = show(buildTree(root, [], 2, (x) => x.who));

    expect(screen.getByRole('button', { name: /Expand 4 replies/ })).toBeTruthy();

    await act(async () => fireEvent.click(screen.getByText('4 replies')));

    expect(onOpen).toHaveBeenCalledWith(root);
  });

  it('stops offering them once they are loaded', () => {
    const root: Item = { id: 'a', parent: null, who: 'ada', direct: 1 };
    const reply: Item = { id: 'b', parent: 'a', who: 'sam' };

    show(buildTree(root, [reply], 2, (x) => x.who));

    expect(screen.getByRole('button', { name: /Expand 1 reply/ })).toBeTruthy();
  });

  it('keeps the count in place while the replies load', () => {
    const root: Item = { id: 'a', parent: null, who: 'ada', direct: 2, total: 4 };

    show(
      buildTree(root, [], 2, (x) => x.who),
      vi.fn(() => new Promise<undefined>(() => undefined)),
    );

    fireEvent.click(screen.getByText('4 replies'));

    const more = screen.getByText('4 replies');

    expect(more.getAttribute('aria-busy')).toBe('true');
    expect(more.querySelector('.loading-dots')).not.toBeNull();
  });
});
