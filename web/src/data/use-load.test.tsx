import { act, render, screen } from '@testing-library/react';
import { Suspense } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { fail, ok, type Result } from './gateway';
import { useLoad } from './use-load';

function Page({ load, id }: { load: () => Promise<Result>; id: string }) {
  const state = useLoad(load, id);
  return <p>{state.status === 'error' ? `error: ${state.error}` : 'page ready'}</p>;
}

/** React 19 needs a render that may suspend to happen inside an awaited act */
async function show(load: () => Promise<Result>, id: string) {
  let view: ReturnType<typeof render> | null = null;

  await act(async () => {
    view = render(
      <Suspense fallback={<p>waiting</p>}>
        <Page load={load} id={id} />
      </Suspense>,
    );
  });

  return view!;
}

describe('useLoad', () => {
  it('suspends on the first load and renders once the data is in', async () => {
    let finish: (r: Result) => void = () => undefined;
    const load = vi.fn(() => new Promise<Result>((r) => (finish = r)));

    await show(load, 'first');
    expect(screen.getByText('waiting')).toBeTruthy();

    await act(async () => finish(ok(undefined)));
    expect(await screen.findByText('page ready')).toBeTruthy();
    expect(load).toHaveBeenCalledTimes(1);
  });

  it('renders a key it already loaded without waiting or fetching again', async () => {
    const load = vi.fn(() => Promise.resolve(ok(undefined)));

    const first = await show(load, 'again');

    await screen.findByText('page ready');
    first.unmount();

    await show(load, 'again');
    expect(screen.getByText('page ready')).toBeTruthy();
    expect(load).toHaveBeenCalledTimes(1);
  });

  it('reports a failed load and tries again on the next visit', async () => {
    const load = vi
      .fn<() => Promise<Result>>()
      .mockResolvedValueOnce(fail('Server is down'))
      .mockResolvedValueOnce(ok(undefined));

    const first = await show(load, 'flaky');

    expect(await screen.findByText('error: Server is down')).toBeTruthy();
    first.unmount();

    await show(load, 'flaky');
    expect(await screen.findByText('page ready')).toBeTruthy();
    expect(load).toHaveBeenCalledTimes(2);
  });
});
