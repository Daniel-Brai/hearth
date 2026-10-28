import { useState } from 'react';
import { audienceOf, type Audience } from '@/domain/audience';
import { linkKind } from '@/domain/links';
import type { Community, Hue, ModerationLevel } from '@/domain/types';
import { toKindDraft, type KindDraft, type LinkDraft } from './drafts';

export function useCommunityDraft(current: Community) {
  const [name, setName] = useState(current.name);
  const [hue, setHue] = useState<Hue>(current.hue);
  const [tagline, setTagline] = useState(current.tagline);
  const [intro, setIntro] = useState(current.intro ?? '');
  const [logo, setLogo] = useState(current.logo);
  const [banner, setBanner] = useState(current.banner);
  const [categories, setCategories] = useState(current.categories);
  const [moderation, setModeration] = useState<ModerationLevel>(current.moderation ?? 'none');
  const [audience, setAudience] = useState<Audience>(() => audienceOf(current));

  const [links, setLinks] = useState<LinkDraft[]>(() =>
    current.links.map((l) => ({
      id: crypto.randomUUID(),
      label: l.label,
      url: l.url,
      custom: l.label !== linkKind(l.url)?.name,
    })),
  );

  const [kinds, setKinds] = useState<KindDraft[]>(() => current.kinds.map(toKindDraft));

  return {
    name,
    setName,
    hue,
    setHue,
    tagline,
    setTagline,
    intro,
    setIntro,
    logo,
    setLogo,
    banner,
    setBanner,
    categories,
    setCategories,
    moderation,
    setModeration,
    audience,
    setAudience,
    links,
    setLinks,
    kinds,
    setKinds,
  };
}

export type CommunityDraft = ReturnType<typeof useCommunityDraft>;
