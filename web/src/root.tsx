import { useEffect, type ReactNode } from 'react';
import { Links, Meta, Outlet, Scripts, ScrollRestoration } from 'react-router';
import stylesheet from '@/design-system/styles/index.css?url';
import { useGateway } from '@/app/gateway-context';
import { ErrorPage } from '@/pages/errors/ErrorPage';
import { installImageFade } from '@/runtime/image-fade';

/* Applies the saved theme before first paint so the screen never flashes the wrong colours */
const THEME_SCRIPT = `(() => {
  const root = document.documentElement;
  root.classList.add('no-anim');
  try {
    const theme = localStorage.getItem('hearth-theme');
    if (theme === 'light' || theme === 'dark') root.dataset.theme = theme;
    else root.removeAttribute('data-theme');
    if (localStorage.getItem('hearth-sidebar') === 'collapsed') root.classList.add('sb-collapsed');
  } catch {
    root.removeAttribute('data-theme');
  }
  requestAnimationFrame(() => requestAnimationFrame(() => root.classList.remove('no-anim')));
})();`;

/* The page colour before the stylesheet arrives so a dark theme never starts white */
const FIRST_PAINT = `html { background: #ffffff; }
@media (prefers-color-scheme: dark) { html:not([data-theme='light']) { background: #0d181d; } }
html[data-theme='dark'] { background: #0d181d; }`;

export function Layout({ children }: { readonly children: ReactNode }) {
  return (
    // The theme script sets classes and data-theme on <html> before React hydrates
    <html lang="en" suppressHydrationWarning>
      <head>
        <meta charSet="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <meta name="color-scheme" content="light dark" />
        <meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)" />
        <meta name="theme-color" content="#1a2733" media="(prefers-color-scheme: dark)" />
        <meta name="apple-mobile-web-app-title" content="Hearth" />
        <script dangerouslySetInnerHTML={{ __html: THEME_SCRIPT }} />
        <style dangerouslySetInnerHTML={{ __html: FIRST_PAINT }} />
        <link rel="stylesheet" href={stylesheet} />
        <link rel="manifest" href="/manifest.webmanifest" />
        <link rel="icon" href="/favicon.ico" sizes="48x48" />
        <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
        <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png" />
        <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16.png" />
        <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />
        <Meta />
        <Links />
      </head>
      <body>
        <div id="root">{children}</div>
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

function BrowserStart() {
  const gateway = useGateway();

  useEffect(() => {
    installImageFade();
    void gateway.load.session();
  }, [gateway]);

  return null;
}

export default function App() {
  return (
    <>
      <BrowserStart />
      <Outlet />
    </>
  );
}

export function ErrorBoundary() {
  return <ErrorPage code={500} />;
}
