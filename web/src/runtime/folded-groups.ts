import { useSyncExternalStore } from 'react';

import { localStore } from './browser-storage';

const KEY = 'hearth-folded-groups';
const listeners = new Set<() => void>();

const read = (): string => {
  try {
    return localStore()?.getItem(KEY) ?? '{}';
  } catch {
    return '{}';
  }
};

const parse = (raw: string): Record<string, boolean> => {
  try {
    const value: unknown = JSON.parse(raw);

    if (typeof value !== 'object' || value === null || Array.isArray(value)) return {};

    return Object.fromEntries(
      Object.entries(value).filter((e): e is [string, boolean] => typeof e[1] === 'boolean'),
    );
  } catch {
    return {};
  }
};

const subscribe = (listener: () => void) => {
  listeners.add(listener);
  return () => listeners.delete(listener);
};

/** The server render uses the default so both sides match */
export function useFolded(id: string, byDefault = false): boolean {
  const raw = useSyncExternalStore(subscribe, read, () => '{}');

  return parse(raw)[id] ?? byDefault;
}

export function toggleFolded(id: string, byDefault = false) {
  const folded = parse(read());

  try {
    localStore()?.setItem(KEY, JSON.stringify({ ...folded, [id]: !(folded[id] ?? byDefault) }));
  } catch (error) {
    console.warn('Folded sidebar sections will not be remembered on this device.', error);
  }

  listeners.forEach((listener) => listener());
}
