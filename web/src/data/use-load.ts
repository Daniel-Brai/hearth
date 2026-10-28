import { createContext, use, useContext, useEffect, useSyncExternalStore } from 'react';
import type { Result } from '@/data/gateway';

export type LoadState = { status: 'ready' } | { status: 'error'; error: string };

type Entry = {
  readonly promise: Promise<void>;
  state:
    { status: 'pending' } | { status: 'ready'; at: number } | { status: 'error'; error: string };
};

const FRESH_MS = 10_000;

export class LoadCache {
  private readonly entries = new Map<string, Entry>();
  private readonly listeners = new Set<() => void>();
  private inFlight = 0;

  get(key: string): Entry | undefined {
    return this.entries.get(key);
  }

  delete(key: string) {
    this.entries.delete(key);
  }

  start(key: string, load: () => Promise<Result>): Entry {
    this.inFlight++;
    this.notify();

    const entry: Entry = {
      state: { status: 'pending' },
      promise: load()
        .then(
          (r) => {
            entry.state = r.ok
              ? { status: 'ready', at: Date.now() }
              : { status: 'error', error: r.error };
          },
          (error: unknown) => {
            entry.state = {
              status: 'error',
              error: error instanceof Error ? error.message : 'Something went wrong',
            };
          },
        )
        .finally(() => {
          this.inFlight--;
          this.notify();
        }),
    };

    this.entries.set(key, entry);

    return entry;
  }

  seed(keys: readonly string[]) {
    for (const key of keys)
      this.entries.set(key, { promise: settled(), state: { status: 'ready', at: 0 } });
  }

  errors(): string[] {
    return [...this.entries.values()].flatMap((e) =>
      e.state.status === 'error' ? [e.state.error] : [],
    );
  }

  readyKeys(): string[] {
    return [...this.entries].filter(([, e]) => e.state.status === 'ready').map(([key]) => key);
  }

  loading(): boolean {
    return this.inFlight > 0;
  }

  subscribe(listener: () => void) {
    this.listeners.add(listener);

    return () => {
      this.listeners.delete(listener);
    };
  }

  /* Loads start during render so subscribers hear about them after it, not in the middle of it */
  private notify() {
    queueMicrotask(() => this.listeners.forEach((l) => l()));
  }
}

// Lets use read it without suspending
const settled = (): Promise<void> =>
  Object.assign(Promise.resolve(), { status: 'fulfilled' as const, value: undefined });

const browserCache = new LoadCache();

export const LoadCacheContext = createContext<LoadCache>(browserCache);

export const browserLoads = (): LoadCache => browserCache;

export function useLoad(load: () => Promise<Result>, key: string): LoadState {
  const cache = useContext(LoadCacheContext);
  const entry = cache.get(key) ?? cache.start(key, load);

  useEffect(() => {
    const current = cache.get(key);

    if (!current) return;

    if (current.state.status === 'ready' && Date.now() - current.state.at > FRESH_MS) {
      current.state = { status: 'ready', at: Date.now() };
      void load();
    }

    if (current.state.status === 'error') cache.delete(key);
    // Runs once per visit to a key since load changes identity on every render
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  use(entry.promise);

  return entry.state.status === 'error'
    ? { status: 'error', error: entry.state.error }
    : { status: 'ready' };
}

export function useLoading(): boolean {
  const cache = useContext(LoadCacheContext);

  return useSyncExternalStore(
    (l) => cache.subscribe(l),
    () => cache.loading(),
    () => false,
  );
}
