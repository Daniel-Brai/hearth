import type { HearthGateway, ProfileSpec, Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import type { Visibility } from '@/domain/types';
import { authUpdateMe } from '@/generated/api/auth/auth';
import type { UpdateProfileBody } from '@/generated/schemas';
import { toPerson } from '../mappers';
import { dataUrlToBlob, uploadFile } from '../upload';
import type { GatewayContext } from './context';
import { call, failed } from './context';

async function avatarOf(
  photo: string | null,
): Promise<Result<Pick<UpdateProfileBody, 'avatar_id'>>> {
  if (photo === null) return ok({ avatar_id: null });
  if (!photo.startsWith('data:')) return ok({});

  const media = await uploadFile(dataUrlToBlob(photo), 'avatar', 'avatar');

  if (!media) return fail("Your photo didn't upload. Try again.");

  return ok({ avatar_id: media.id });
}

export function createProfileGateway(ctx: GatewayContext) {
  const update = async (body: UpdateProfileBody): Promise<Result> => {
    const answer = await call(() => authUpdateMe(body));

    if (answer.status !== 200) return failed(answer);

    ctx.store.set((state) => (state.people[answer.data.id] = toPerson(answer.data)));

    return ok(undefined);
  };

  const save = async (spec: ProfileSpec): Promise<Result> => {
    const avatar = await avatarOf(spec.photo);
    if (!avatar.ok) return avatar;

    return update({
      ...avatar.value,
      display_name: spec.name,
      bio: spec.bio || null,
      pronouns: spec.pronouns || null,
      location: spec.location || null,
      links: spec.links.map((link) => ({ url: link.url, label: link.label || null })),
      privacy: {
        show_name: !spec.private,
        presence: spec.presence,
        avatar: spec.photoVis,
        show_communities: spec.commsVis,
      },
    });
  };

  const field = { presence: 'presence', photo: 'avatar' } as const;

  const profile: HearthGateway['profile'] = {
    save,
    removePhoto: () => void update({ avatar_id: null }),
    setVisibility: (key, visibility: Visibility) =>
      void update({ privacy: { [field[key]]: visibility } }),
  };

  return { profile };
}
