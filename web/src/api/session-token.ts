type Listener = (token: string | null) => void;

let token: string | null = null;
const listeners = new Set<Listener>();

// Memory only so a script can't read it back after a reload
export const accessToken = (): string | null => token;

export function setAccessToken(next: string | null): void {
  if (next === token) return;

  token = next;
  for (const listener of listeners) listener(next);
}

export function onAccessToken(listener: Listener): () => void {
  listeners.add(listener);

  return () => listeners.delete(listener);
}
