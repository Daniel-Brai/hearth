import { useEffect, useRef, type ReactNode } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { ButtonLink, cn, Icon, IconButton, Link } from '@/design-system';
import { isPublicPath, routes } from '@/runtime/routes';
import type { TrailEntry } from '@/runtime/trail';
import { useSignedInNow } from './use-signed-in';
import { useTrail } from './use-trail';
import { useUi } from '@/runtime/ui-store';
import { PageMeta } from './PageMeta';

export type PageHeaderProps = {
  readonly title: ReactNode;
  readonly eyebrow?: ReactNode | undefined;
  readonly sub?: ReactNode | undefined;
  readonly label: string;
  readonly actions?: ReactNode | undefined;
  readonly endActions?: ReactNode | undefined;
  readonly back?: boolean | undefined;
  // Asks before going back, and calls go once it may
  readonly confirmBack?: ((go: () => void) => void) | undefined;
  readonly ruled?: boolean | undefined;
  readonly hideTitle?: boolean | undefined;
  readonly documentTitle?: readonly string[] | undefined;
  readonly description?: string | null | undefined;
  readonly image?: string | null | undefined;
  readonly noindex?: boolean | undefined;
  readonly jsonLd?: string | null | undefined;
};

const PENDING = '…';

const textParts = (...nodes: ReactNode[]) =>
  nodes.filter((n): n is string => typeof n === 'string' && n !== PENDING);

let firstPage = true;

/** Moves focus to the heading after navigation so screen readers announce it */
function useHeadingFocus() {
  const { pathname } = useLocation();
  const heading = useRef<HTMLHeadingElement>(null);

  useEffect(() => {
    if (firstPage) {
      firstPage = false;
      return;
    }

    const active = document.activeElement;
    const typing = active instanceof HTMLInputElement || active instanceof HTMLTextAreaElement;

    if (!typing) heading.current?.focus({ preventScroll: true });
  }, [pathname]);

  return heading;
}

export function PageHeader({
  title,
  eyebrow,
  sub,
  label,
  actions,
  endActions,
  back = true,
  confirmBack,
  ruled,
  hideTitle,
  documentTitle,
  description,
  image,
  noindex,
  jsonLd,
}: PageHeaderProps) {
  const trail = useTrail(label);
  const signedIn = useSignedInNow();
  const heading = useHeadingFocus();
  const from = signedIn || !trail || isPublicPath(trail.href) ? trail : null;

  return (
    <header className={cn('header', ruled && 'header--ruled')}>
      <PageMeta
        title={documentTitle ?? textParts(title, eyebrow)}
        description={description}
        image={image}
        noindex={noindex}
        jsonLd={jsonLd}
      />

      <div className="header__actions">
        {back ? <BackButton from={from} signedIn={signedIn} confirm={confirmBack} /> : null}
        {actions}
      </div>

      <h1 className="header__title" ref={heading} tabIndex={-1}>
        {eyebrow ? <span className="header__eyebrow">{eyebrow}</span> : null}
        <span className={hideTitle ? 'sr-only' : undefined}>{title}</span>
        {sub ? <span className="header__sub">{sub}</span> : null}
      </h1>

      <div className="header__actions header__actions--end">
        {endActions}
        <SidebarToggle />
      </div>
    </header>
  );
}

function BackButton({
  from,
  signedIn,
  confirm,
}: {
  readonly from: TrailEntry | null;
  readonly signedIn: boolean;
  readonly confirm?: ((go: () => void) => void) | undefined;
}) {
  const navigate = useNavigate();

  const guard = (href: string) => (event: React.MouseEvent) => {
    if (!confirm) return;

    event.preventDefault();
    confirm(() => void navigate(href));
  };

  if (from) {
    return (
      <Link
        to={from.href}
        onClick={guard(from.href)}
        className="btn btn--circle btn--small btn--back"
        aria-label={'Back to ' + from.label}
        data-tip={'Back to ' + from.label}
      >
        <Icon name="back" />
        <span className="btn__label">{from.label}</span>
      </Link>
    );
  }

  if (!signedIn) {
    return (
      <Link
        to={routes.home}
        onClick={guard(routes.home)}
        className="btn btn--circle btn--small btn--back"
        aria-label="Back to Communities"
        data-tip="Back to Communities"
      >
        <Icon name="back" />
        <span className="btn__label">Communities</span>
      </Link>
    );
  }

  return (
    <ButtonLink
      to={routes.home}
      onClick={guard(routes.home)}
      circle
      size="small"
      aria-label="Catch up"
      data-tip="Catch up"
    >
      <Icon name="inbox" />
    </ButtonLink>
  );
}

function SidebarToggle() {
  const signedIn = useSignedInNow();
  const setSidebarOpen = useUi((s) => s.setSidebarOpen);

  const open = () => {
    if (window.matchMedia('(min-width: 100ch)').matches) {
      document.documentElement.classList.remove('sb-collapsed');
      localStorage.removeItem('hearth-sidebar');
    } else setSidebarOpen(true);
  };

  if (!signedIn) return null;

  return (
    <IconButton
      variant="borderless"
      className="sidebar-toggle"
      onClick={open}
      aria-label="Show sidebar"
      data-tip="Show sidebar"
    >
      <Icon name="sidebar" />
    </IconButton>
  );
}
