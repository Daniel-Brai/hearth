export const onServer = typeof window === 'undefined';

type ServerGlobals = { process?: { env: Record<string, string | undefined> } };

export const serverEnv = (name: string): string | undefined =>
  (globalThis as ServerGlobals).process?.env[name] || undefined;
