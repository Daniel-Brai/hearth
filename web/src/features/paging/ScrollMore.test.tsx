import { render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { fail, ok } from '@/data/gateway';

import { ScrollMore } from './ScrollMore';

let reach: () => void;

beforeEach(() => {
  vi.stubGlobal(
    'IntersectionObserver',
    class {
      constructor(callback: IntersectionObserverCallback) {
        reach = () =>
          callback([{ isIntersecting: true }] as IntersectionObserverEntry[], this as never);
      }

      observe() {}
      disconnect() {}
    },
  );
});

afterEach(() => vi.unstubAllGlobals());

describe('ScrollMore', () => {
  it('says why when the next page fails', async () => {
    const more = vi.fn(() => Promise.resolve(fail('Server trouble')));

    render(<ScrollMore id="more" more={more} />);
    reach();

    expect(await screen.findByRole('alert')).toHaveTextContent('Server trouble');
  });

  it('loads the next page as the end comes near', async () => {
    const more = vi.fn(() => Promise.resolve(ok(undefined)));

    render(<ScrollMore id="more" more={more} />);
    reach();

    await waitFor(() => expect(more).toHaveBeenCalledTimes(1));
  });
});
