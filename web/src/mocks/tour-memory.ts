import { localStore } from '@/runtime/browser-storage';

const KEY = 'hearth-tour-done';

export function tourDoneRemembered(): boolean {
  try {
    return localStore()?.getItem(KEY) === 'true';
  } catch {
    return false;
  }
}

export function rememberTourDone(done: boolean) {
  try {
    if (done) localStore()?.setItem(KEY, 'true');
    else localStore()?.removeItem(KEY);
  } catch {
    return;
  }
}
