import type { ProfileSpec } from '@/data/gateway';
import type { AppState } from '@/domain/app-state';
import { dedupeLinks, isValidLink, normalizeUrl } from '@/domain/links';
import { commsVisOf, person, visOf } from '@/domain/selectors';
import type { CommunitiesVisibility, Visibility } from '@/domain/types';

export type LinkRow = { id: number; url: string; label: string; auto: boolean };

export type Form = {
  name: string;
  photo: string | null;
  bio: string;
  pronouns: string;
  location: string;
  links: LinkRow[];
  hidden: boolean;
  presence: Visibility;
  photoVis: Visibility;
  commsVis: CommunitiesVisibility;
};

export type Problem = { field: string | null; text: string };

export const BIO_MAX = 300;

let linkSeq = 0;

export const newLinkRow = (url = '', label = '', auto = true): LinkRow => ({
  id: ++linkSeq,
  url,
  label,
  auto,
});

export const snapshotOf = (f: Form) =>
  JSON.stringify([
    f.name,
    f.photo,
    f.bio,
    f.pronouns,
    f.location,
    f.links.map((l) => [l.url, l.label]),
    f.hidden,
    f.presence,
    f.photoVis,
    f.commsVis,
  ]);

export function formOf(state: AppState, me: string): Form {
  const p = person(state, me);

  return {
    name: p.name,
    photo: p.photo ?? null,
    bio: p.bio ?? '',
    pronouns: p.pronouns ?? '',
    location: p.location ?? '',
    links: (p.links ?? [])
      .filter((l) => l.url)
      .map((l) => newLinkRow(l.url, l.label ?? '', !l.label)),
    hidden: p.private,
    presence: visOf(state, me, 'presence'),
    photoVis: visOf(state, me, 'photo'),
    commsVis: commsVisOf(state, me),
  };
}

function tidyBio(text: string): string {
  let bio = text.trim();
  while (bio.includes('\n\n\n')) bio = bio.replaceAll('\n\n\n', '\n\n');
  return bio;
}

const problem = (field: string | null, text: string) => ({ ok: false, field, text }) as const;

export function checkForm(form: Form): { ok: true; spec: ProfileSpec } | (Problem & { ok: false }) {
  const name = form.name.trim();

  if (!name) return problem('name', 'Add your name. You can hide it above.');

  const bio = tidyBio(form.bio);

  if (bio.length > BIO_MAX) return problem('bio', `Keep the bio to ${BIO_MAX} characters`);

  const links: { url: string; label: string }[] = [];

  for (const l of form.links) {
    if (!l.url.trim()) continue;

    const url = normalizeUrl(l.url);

    if (!isValidLink(url))
      return problem(`link-${l.id}`, `“${l.url.trim()}” doesn't look like a link`);

    links.push({ url, label: l.auto ? '' : l.label.trim() });
  }

  return {
    ok: true,
    spec: {
      name,
      photo: form.photo,
      bio,
      pronouns: form.pronouns.trim(),
      location: form.location.trim(),
      links: dedupeLinks(links),
      private: form.hidden,
      presence: form.presence,
      photoVis: form.photoVis,
      commsVis: form.commsVis,
    },
  };
}
