import type { Dispatch, SetStateAction } from 'react';
import { Button, Icon, IconButton, Input } from '@/design-system';
import { MAX_LINKS, type LinkDraft } from './drafts';
import { linkIcon, linkKind } from '@/domain/links';

const detectedLabel = (url: string) => linkKind(url)?.name ?? null;

export function LinksEditor({
  links,
  onChange,
}: {
  readonly links: LinkDraft[];
  readonly onChange: Dispatch<SetStateAction<LinkDraft[]>>;
}) {
  const patch = (id: string, change: (l: LinkDraft) => LinkDraft) =>
    onChange((all) => all.map((l) => (l.id === id ? change(l) : l)));

  const setUrl = (id: string, url: string) =>
    patch(id, (l) => ({ ...l, url, label: l.custom ? l.label : (detectedLabel(url) ?? '') }));

  const setLabel = (id: string, label: string) =>
    patch(id, (l) => ({ ...l, label, custom: label.trim() !== '' }));

  return (
    <div className="grid gap-2" id="edit-links">
      {links.map((l) => (
        <div key={l.id} className="flex items-center gap-2">
          <Icon name={linkIcon(l.url)} className="subtle" />
          <Input
            style={{ flex: '0 0 9rem' }}
            value={l.label}
            onChange={(e) => setLabel(l.id, e.target.value)}
            placeholder={detectedLabel(l.url) ?? 'Label'}
            aria-label="Link label"
          />
          <Input
            value={l.url}
            onChange={(e) => setUrl(l.id, e.target.value)}
            placeholder="https://"
            aria-label="Link address"
          />
          <IconButton
            variant="borderless"
            onClick={() => onChange((all) => all.filter((x) => x.id !== l.id))}
            aria-label="Remove link"
          >
            <Icon name="x" />
          </IconButton>
        </div>
      ))}

      {links.length < MAX_LINKS ? (
        <Button
          size="small"
          style={{ justifySelf: 'start' }}
          onClick={() =>
            onChange((all) => [
              ...all,
              { id: crypto.randomUUID(), label: '', url: '', custom: false },
            ])
          }
        >
          <Icon name="plus" />
          Add a link
        </Button>
      ) : null}
    </div>
  );
}
