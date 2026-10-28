import { localStore } from './browser-storage';

const KEY = 'hearth-jump-recent';

export function recentJumps(): string[] {
  try {
    const raw = localStore()?.getItem(KEY);
    return raw ? (JSON.parse(raw) as string[]) : [];
  } catch {
    return [];
  }
}

export function rememberJump(href: string) {
  try {
    localStore()?.setItem(
      KEY,
      JSON.stringify([href, ...recentJumps().filter((h) => h !== href)].slice(0, 8)),
    );
  } catch (error) {
    console.warn('Recent searches will not be remembered on this device.', error);
  }
}
