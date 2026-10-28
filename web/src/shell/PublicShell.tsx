import { Suspense, useEffect, useState } from 'react';
import { useGateway } from '@/app/gateway-context';
import { Outlet } from 'react-router';
import { Button, Link, Skeleton, Toasts, TooltipLayer } from '@/design-system';
import { useAppState } from '@/data/store';
import { codeBlockClick } from '@/features/markdown/code-block';
import { brandFor } from '@/runtime/brand';
import { routes } from '@/runtime/routes';
import { useUi } from '@/runtime/ui-store';
import { DialogHost } from './dialogs/DialogHost';
import { NavProgress } from './NavProgress';
import { useGuest } from './use-guest';

export function PublicShell() {
  const brand = useAppState((state) => brandFor(state.instance));
  const toasts = useUi((s) => s.toasts);
  const { signIn } = useGuest();
  const checked = useSessionChecked();

  useEffect(() => {
    document.addEventListener('click', codeBlockClick);

    return () => document.removeEventListener('click', codeBlockClick);
  }, []);

  return (
    <div id="app" className="public-shell">
      <NavProgress />

      <a href="#main" className="btn btn--small skip-link">
        Skip to main content
      </a>

      <header className="public-shell__top">
        <Link to={routes.home} className="logo">
          <span className="contents" dangerouslySetInnerHTML={{ __html: brand.mark }} />
          <span>{brand.name}</span>
        </Link>

        <Button
          id="public-sign-in"
          size="small"
          variant="reversed"
          className={checked ? 'public-shell__sign-in' : 'public-shell__sign-in is-waiting'}
          onClick={signIn}
          aria-hidden={!checked}
          tabIndex={checked ? undefined : -1}
        >
          Sign in
        </Button>
      </header>

      <div className="main-col">
        <Suspense
          fallback={
            <main id="main">
              <div className="measure">
                <Skeleton kind="feed" />
              </div>
            </main>
          }
        >
          <Outlet />
        </Suspense>
      </div>

      <DialogHost />
      <Toasts toasts={toasts} />
      <TooltipLayer />
    </div>
  );
}

// The server renders everyone signed out, so Sign in waits for the browser to restore any session
function useSessionChecked(): boolean {
  const gateway = useGateway();
  const [checked, setChecked] = useState(false);

  useEffect(() => {
    let live = true;

    void gateway.load.session().finally(() => {
      if (live) setChecked(true);
    });

    return () => {
      live = false;
    };
  }, [gateway]);

  return checked;
}
