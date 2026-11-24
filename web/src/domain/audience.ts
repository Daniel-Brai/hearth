import type { Community, CommunityVisibility } from './types';

export type Audience = 'indexed' | 'public' | 'invite' | 'private';

export const visibilityOf = (audience: Audience): CommunityVisibility =>
  audience === 'indexed' || audience === 'public' ? 'public' : 'invite';

// Communities from before the exact value was kept read as their nearest one
export function audienceOf(c: Pick<Community, 'visibility' | 'indexed' | 'audience'>): Audience {
  if (c.audience) return c.audience;
  if (c.visibility === 'invite') return 'invite';

  return c.indexed === false ? 'public' : 'indexed';
}

export const AUDIENCE_LABEL: Record<Audience, string> = {
  indexed: 'Public',
  public: 'Public, not in search',
  invite: 'Invite only',
  private: 'Private',
};
