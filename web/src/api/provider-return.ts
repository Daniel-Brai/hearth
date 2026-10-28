import type { ProviderReturn } from '@/data/gateway';

const PROVIDERS = { github: 'GitHub', google: 'Google' } as const;

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
