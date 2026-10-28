import { useState } from 'react';
import { useGateway } from '@/app/gateway-context';
import { dedupeLinks, isValidLink, linkText, normalizeUrl } from '@/domain/links';
import { useUi } from '@/runtime/ui-store';
import type { CommunityDraft } from './use-community-draft';

export function useSaveCommunity(cid: string, draft: CommunityDraft, close: () => void) {
  const gateway = useGateway();
  const flash = useUi((s) => s.flash);
  const [shake, setShake] = useState(false);

  const save = async () => {
    if (!draft.name.trim()) {
      setShake(true);
      window.setTimeout(() => setShake(false), 450);
      return;
    }

    const filled = draft.links.filter((l) => l.url.trim());
    const broken = filled.find((l) => !isValidLink(l.url));

    if (broken) {
      flash(`"${broken.url.trim()}" isn't a valid link`);
      return;
    }

    const r = await gateway.communities.update(cid, {
      name: draft.name,
      tagline: draft.tagline,
      intro: draft.intro,
      logo: draft.logo,
      banner: draft.banner,
      hue: draft.hue,
      links: dedupeLinks(
        filled.map((l) => ({
          url: normalizeUrl(l.url),
          label: l.label.trim() || linkText({ url: l.url }),
        })),
      ),
      kinds: draft.kinds.map(({ id: _id, ...k }) => k),
      categories: draft.categories,
      moderation: draft.moderation,
      audience: draft.audience,
    });

    if (!r.ok) return flash(r.error);

    close();
    flash('Community updated');
  };

  return { save, shake };
}
