import type { LinkOptions } from '@/data/gateway';
import type { InviteEmail, InviteLink } from '@/domain/types';
import type {
  CreateInviteBody,
  Invite,
  InviteEmail as ApiInviteEmail,
  InvitePreviewCommunity,
  Community as ApiCommunity,
} from '@/generated/schemas';
import { ageOf } from './mappers';

const DAY_MS = 24 * 60 * 60 * 1000;
const EXPIRY_DAYS: Record<string, number> = { '1d': 1, '7d': 7, '30d': 30 };

function expiryOf(invite: Invite): string {
  if (invite.expires_at === null) return 'never';

  const days = Math.round(
    (Date.parse(invite.expires_at) - Date.parse(invite.inserted_at)) / DAY_MS,
  );

  const choice = Object.entries(EXPIRY_DAYS).find(([, n]) => n === days);

  return choice?.[0] ?? `${days}d`;
}

export const toInviteLink = (invite: Invite, cid: string): InviteLink => ({
  code: invite.code,
  c: cid,
  expires: expiryOf(invite),
  max: invite.max_uses === null ? 'none' : String(invite.max_uses),
  role: invite.role_key,
  uses: invite.uses_count,
  created: ageOf(invite.inserted_at),
  by: invite.created_by_id,
  revoked: invite.revoked_at !== null,
});

const EMAIL_STATUS = {
  pending: 'pending',
  accepted: 'joined',
  declined: 'declined',
  revoked: 'revoked',
} as const;

export const toInviteEmail = (invite: ApiInviteEmail, cid: string): InviteEmail => ({
  id: invite.id,
  email: invite.email,
  c: cid,
  role: invite.role_key,
  age: ageOf(invite.inserted_at),
  status: EMAIL_STATUS[invite.status],
});

export function toInviteBody(opts: LinkOptions): CreateInviteBody {
  const days = EXPIRY_DAYS[opts.expires];
  const expiresAt = days === undefined ? null : new Date(Date.now() + days * DAY_MS).toISOString();

  return {
    role_key: opts.role,
    max_uses: opts.max === 'none' ? null : Number(opts.max),
    expires_at: expiresAt,
  };
}

export const previewCommunity = (
  community: Omit<InvitePreviewCommunity, 'member_count' | 'logo_url'> &
    Partial<Pick<InvitePreviewCommunity, 'member_count' | 'logo_url'>>,
  ownerId: string | null,
): ApiCommunity => ({
  ...community,
  logo_url: community.logo_url ?? null,
  member_count: community.member_count ?? 0,
  online_count: 0,
  owner: null,
  banner_id: null,
  banner_url: null,
  categories: [],
  description: null,
  links: [],
  moderation: 'none',
  owner_id: ownerId,
  rooms: [],
  template: 'blank',
  visibility: 'invite_only',
  welcome_message: null,
});
