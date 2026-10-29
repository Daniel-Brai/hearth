import { PassThrough } from 'node:stream';
import { JSDOM } from 'jsdom';
import { renderToPipeableStream } from 'react-dom/server';
import { ServerRouter, type EntryContext } from 'react-router';
import { OUTAGES } from '@/api/gateway/context';
import { AppProviders } from '@/app/AppProviders';
import { hydrationScript } from '@/app/hydration';
import { RENDER_OPTIONS } from '@/app/render-options';
import { signedInFromCookies, zoneFromCookies } from '@/app/request-context';
import { createRuntime } from '@/app/runtime';
import { LoadCache } from '@/data/use-load';
import { setMarkdownWindow } from '@/features/markdown/markdown';

/* Markdown is sanitised in a DOM, and the server has none of its own */
setMarkdownWindow(new JSDOM('').window as unknown as Parameters<typeof setMarkdownWindow>[0]);

/** How long a render may wait for the API before it gives up */
export const streamTimeout = 10_000;

/** The site's public address from PUBLIC_URL behind a proxy or else from the request */
const originOf = (request: Request) =>
  (process.env.PUBLIC_URL ?? new URL(request.url).origin).replace(/\/$/, '');

/**
 * Renders a screen to finished HTML after every load so search engines and
 * link previews get the content and tags then appends the store for hydration
 */
export default async function handleRequest(
  request: Request,
  status: number,
  headers: Headers,
  routerContext: EntryContext,
) {
  const runtime = await createRuntime(null);
  const loads = new LoadCache();
  let responseStatus = status;

  const cookies = request.headers.get('cookie');

  const info = {
    origin: originOf(request),
    zone: zoneFromCookies(cookies),
    signedIn: signedInFromCookies(cookies),
    setStatus: (next: number) => (responseStatus = next),
  };

  const html = await new Promise<string>((resolve, reject) => {
    const { pipe, abort } = renderToPipeableStream(
      <AppProviders runtime={runtime} loads={loads} request={info}>
        <ServerRouter context={routerContext} url={request.url} />
      </AppProviders>,
      {
        ...RENDER_OPTIONS,
        onAllReady() {
          const chunks: Buffer[] = [];
          const body = new PassThrough();

          body.on('data', (chunk: Buffer) => chunks.push(chunk));
          body.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
          pipe(body);
        },
        onShellError: reject,
        onError(error) {
          console.error(error);
        },
      },
    );

    setTimeout(() => abort(), streamTimeout + 1000);
  });

  const data = hydrationScript({
    state: runtime.store.get(),
    loaded: loads.readyKeys(),
    origin: info.origin,
    zone: info.zone,
    signedIn: info.signedIn,
  });

  headers.set('Content-Type', 'text/html; charset=utf-8');

  // A screen that couldn't load because the API was down isn't missing so say so and
  // search engines come back instead of dropping it
  if (responseStatus >= 400 && loads.errors().some((error) => OUTAGES.has(error))) {
    responseStatus = 503;
    headers.set('Retry-After', '60');
  }

  return new Response(html.replace('</body>', data + '</body>'), {
    status: responseStatus,
    headers,
  });
}
