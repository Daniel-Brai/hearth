import { localStore } from './browser-storage';

const KEY = 'hearth-update-dismissed';

export function dismissedUpdate(): string | null {
  try {
    return localStore()?.getItem(KEY) ?? null;
  } catch {
    return null;
  }
}

export function dismissUpdate(version: string) {
  try {
    localStore()?.setItem(KEY, version);
  } catch (error) {
    console.warn('The update banner will show again after a reload.', error);
  }
}
