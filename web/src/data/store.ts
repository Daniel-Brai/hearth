import { createContext, useContext } from 'react';
import { useSyncExternalStoreWithSelector } from 'use-sync-external-store/with-selector';
import {
  createDraft,
  current as snapshotOf,
  finishDraft,
  isDraft,
  setAutoFreeze,
  type Draft,
} from 'immer';
import type { AppState } from '@/domain/app-state';

setAutoFreeze(false);

type Listener = () => void;

// Immer drafts give every object along a changed path a new identity so selectors on nested records re-render
export class Store {
  private state: AppState;
  private draft: Draft<AppState> | null = null;
  private listeners = new Set<Listener>();

  private afterWrite: ((draft: AppState) => void) | null = null;

  constructor(initial: AppState) {
    this.state = initial;
  }

  onWrite(step: (draft: AppState) => void) {
    this.afterWrite = step;
  }

  get(): AppState {
    return (this.draft as AppState | null) ?? this.state;
  }

  set<T>(mutate: (state: AppState) => T): T {
    if (this.draft) return mutate(this.draft as AppState);

    this.draft = createDraft(this.state);

    let result: T;

    try {
      result = detach(mutate(this.draft as AppState));
      this.afterWrite?.(this.draft as AppState);
      this.state = finishDraft(this.draft) as AppState;
    } finally {
      this.draft = null;
    }

    this.listeners.forEach((l) => l());

    return result;
  }

  replace(next: AppState) {
    this.state = next;
    this.listeners.forEach((l) => l());
  }

  subscribe(listener: Listener) {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  nextId(prefix: string) {
    if (this.draft) {
      this.draft.seq += 1;
      return prefix + this.draft.seq;
    }

    this.state = { ...this.state, seq: this.state.seq + 1 };
    return prefix + this.state.seq;
  }
}

// Drafts stop working once the write ends
function detach<T>(value: T): T {
  if (isDraft(value)) return snapshotOf(value as Draft<T>) as T;
  if (Array.isArray(value)) return value.map(detach) as T;

  if (
    value !== null &&
    typeof value === 'object' &&
    Object.getPrototypeOf(value) === Object.prototype
  ) {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value)) out[k] = detach(v);
    return out as T;
  }

  return value;
}

let current: Store | null = null;

export function setStore(store: Store) {
  current = store;
}

export function getStore(): Store {
  if (!current) throw new Error('The app state store has not been created yet.');
  return current;
}

// The server renders many requests at once, each with its own store
export const StoreContext = createContext<Store | null>(null);

export function useStore(): Store {
  return useContext(StoreContext) ?? getStore();
}

const identity = (state: AppState) => state;

export function shallowEqual<T>(a: T, b: T): boolean {
  if (Object.is(a, b)) return true;
  if (typeof a !== 'object' || typeof b !== 'object' || a === null || b === null) return false;
  if (Array.isArray(a) !== Array.isArray(b)) return false;

  const ka = Object.keys(a) as (keyof T)[];
  const kb = Object.keys(b) as (keyof T)[];

  if (ka.length !== kb.length) return false;

  return ka.every((k) => Object.is(a[k], b[k]));
}

export function useAppState(): AppState;

export function useAppState<T>(
  select: (state: AppState) => T,
  isEqual?: (a: T, b: T) => boolean,
): T;

export function useAppState<T>(
  select?: (state: AppState) => T,
  isEqual: (a: T, b: T) => boolean = shallowEqual,
): T | AppState {
  const store = useStore();
  return useSyncExternalStoreWithSelector(
    (l) => store.subscribe(l),
    () => store.get(),
    () => store.get(),
    (select ?? identity) as (state: AppState) => T | AppState,
    select ? (isEqual as (a: T | AppState, b: T | AppState) => boolean) : undefined,
  );
}
