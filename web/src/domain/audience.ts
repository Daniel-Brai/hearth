import type { Community, CommunityVisibility } from './types';

export type Audience = 'indexed' | 'public' | 'invite' | 'private';

const isOpenAudience = (audience: Audience) => audience === 'indexed' || audience === 'public';

export const visibilityOf = (audience: Audience): CommunityVisibility =>
  isOpenAudience(audience) ? 'public' : 'invite';

// Communities from before the exact value was kept read as their nearest one
export const audienceOf = (c: Pick<Community, 'visibility' | 'indexed' | 'audience'>): Audience =>
  c.audience ?? (c.visibility === 'invite' ? 'invite' : c.indexed === false ? 'public' : 'indexed');

export const AUDIENCE_LABEL: Record<Audience, string> = {
  indexed: 'Public',
  public: 'Public, not in search',
  invite: 'Invite only',
  private: 'Private',
};
