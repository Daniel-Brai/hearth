import { describe, expect, it } from 'vitest';
import { parseProviderReturn } from './provider-return';

describe('parseProviderReturn', () => {
  it('ignores a fragment from anywhere else', () => {
    expect(parseProviderReturn('')).toBeNull();
    expect(parseProviderReturn('#main')).toBeNull();
    expect(parseProviderReturn('#oauth=sign_up')).toBeNull();
  });

  it('reads an error with its provider', () => {
    expect(parseProviderReturn('#oauth_error=email_not_verified&via=google')).toEqual({
      kind: 'failed',
      via: 'Google',
      error: 'Verify your email with Google first, then try again.',
    });
  });

  it('reads a sign in', () => {
    expect(parseProviderReturn('#oauth=signed_in')).toEqual({ kind: 'signed-in' });
  });

  it('reads a sign up', () => {
    expect(
      parseProviderReturn(
        '#oauth=sign_up&sign_up_token=st&name=Ada+Lovelace&username=ada&via=github',
      ),
    ).toEqual({
      kind: 'sign-up',
      via: 'GitHub',
      token: 'st',
      name: 'Ada Lovelace',
      username: 'ada',
    });
  });

  it('reads a sign up the provider gave no name for', () => {
    expect(parseProviderReturn('#oauth=sign_up&sign_up_token=st&via=google')).toEqual({
      kind: 'sign-up',
      via: 'Google',
      token: 'st',
      name: null,
      username: null,
    });
  });
});
