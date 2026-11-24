import type { ProviderReturn } from '@/data/gateway';
import { sessionStore } from '@/runtime/browser-storage';

const PROVIDERS = { github: 'GitHub', google: 'Google' } as const;

const STARTED = 'hearth:oauth-started';

/** Marks the tab that left for a provider so only its own return is read */
export function markProviderStart() {
  try {
    sessionStore()?.setItem(STARTED, '1');
  } catch {
    // Without storage no return is trusted
  }
}

/** A return only counts in the tab that left so a link can't plant someone else's sign up */
export function takeProviderReturn(hash: string): ProviderReturn | null {
  const parsed = parseProviderReturn(hash);
  if (!parsed) return null;

  try {
    const started = sessionStore()?.getItem(STARTED) === '1';
    sessionStore()?.removeItem(STARTED);
    return started ? parsed : null;
  } catch {
    return null;
  }
}

export function parseProviderReturn(hash: string): ProviderReturn | null {
  const params = new URLSearchParams(hash.replace(/^#/, ''));
  const via = PROVIDERS[params.get('via') as keyof typeof PROVIDERS] ?? 'GitHub';
  const error = params.get('oauth_error');

  if (error) return { kind: 'failed', via, error: errorText(error, via) };

  switch (params.get('oauth')) {
    case 'signed_in':
      return { kind: 'signed-in' };

    case 'sign_up': {
      const token = params.get('sign_up_token');
      if (!token) return null;

      return {
        kind: 'sign-up',
        via,
        token,
        name: params.get('name'),
        username: params.get('username'),
      };
    }

    default:
      return null;
  }
}

function errorText(error: string, via: string) {
  switch (error) {
    case 'unavailable':
      return `Signing in with ${via} isn't set up here.`;
    case 'expired':
      return 'That took too long. Try again.';
    case 'email_not_verified':
      return `Verify your email with ${via} first, then try again.`;
    default:
      return `Couldn't sign in with ${via}. Try again.`;
  }
}
