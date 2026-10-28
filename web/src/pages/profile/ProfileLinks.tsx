import type { ReactNode } from 'react';
import { Icon, Label, Menu, cn, useMenu } from '@/design-system';
import { cleanUrl, linkIcon, linkKind, linkText, normalizeUrl } from '@/domain/links';
import type { PersonLink } from '@/domain/types';

const INLINE_LIMIT = 6;
const INLINE_WITH_MORE = 5;

export function ProfileLinks({ links }: { readonly links: readonly PersonLink[] }) {
  if (!links.length) return null;

  const overflow = links.length > INLINE_LIMIT;
  const shown = overflow ? links.slice(0, INLINE_WITH_MORE) : links;

  return (
    <div className="link-holder">
      {shown.map((l) => {
        const pill = !linkKind(l.url) || !!l.label;

        return (
          <a
            key={l.url}
            className={cn('link-chip', pill && 'link-chip--text')}
            href={normalizeUrl(l.url)}
            target="_blank"
            rel="noopener me ugc"
            data-tip={cleanUrl(l.url)}
            aria-label={linkText(l)}
          >
            <Icon name={linkIcon(l.url)} />
            {pill ? <span className="link-chip__text">{linkText(l)}</span> : null}
          </a>
        );
      })}

      {overflow ? (
        <Menu
          popupClassName="link-popup"
          trigger={({ open, toggle, id }) => (
            <button
              type="button"
              className="link-chip link-chip--more"
              onClick={toggle}
              aria-expanded={open}
              aria-controls={id}
              aria-label={`All ${links.length} links`}
            >
              +{links.length - INLINE_WITH_MORE}
            </button>
          )}
        >
          <Label className="block px-2.5 py-1">Links · {links.length}</Label>
          {links.map((l) => (
            <MenuAnchor key={l.url} href={normalizeUrl(l.url)}>
              <Icon name={linkIcon(l.url)} />
              <span className="grid" style={{ minInlineSize: 0 }}>
                <span className="truncate">{linkText(l)}</span>
                <span className="x-small subtle truncate">{cleanUrl(l.url)}</span>
              </span>
            </MenuAnchor>
          ))}
        </Menu>
      ) : null}
    </div>
  );
}

function MenuAnchor({ href, children }: { readonly href: string; readonly children: ReactNode }) {
  const menu = useMenu();

  return (
    <a
      className="popup__item"
      href={href}
      target="_blank"
      rel="noopener me ugc"
      onClick={() => menu?.close()}
    >
      {children}
    </a>
  );
}
