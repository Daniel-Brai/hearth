// PORT defaults to 3000
// HOST defaults to 0.0.0.0
// API_INTERNAL_URL is where the API answers
// PUBLIC_URL is the site's own address in links and tags
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { createServer } from 'node:http';
import { extname, join, normalize, sep } from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath } from 'node:url';
import { constants, createBrotliCompress, createGzip } from 'node:zlib';

// React reads this when it is first imported so it is set before anything that loads it
process.env.NODE_ENV ??= 'production';

const { createRequestHandler } = await import('react-router');

const root = fileURLToPath(new URL('../build/client', import.meta.url));
const build = await import(new URL('../build/server/index.js', import.meta.url).href);
const api = (process.env.API_INTERNAL_URL ?? 'http://localhost:4000').replace(/\/$/, '');

const TYPES = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.txt': 'text/plain; charset=utf-8',
  '.webmanifest': 'application/manifest+json',
  '.webp': 'image/webp',
  '.woff2': 'font/woff2',
};

const render = createRequestHandler(build, 'production');

const COMPRESSIBLE = /^(text\/|application\/(json|xml|javascript|manifest\+json)|image\/svg\+xml)/;

function encodingFor(req, type) {
  if (!COMPRESSIBLE.test(type ?? '')) return null;

  const accepted = String(req.headers['accept-encoding'] ?? '');
  if (/\bbr\b/.test(accepted)) return 'br';
  if (/\bgzip\b/.test(accepted)) return 'gzip';

  return null;
}

const compressor = (encoding) =>
  encoding === 'br'
    ? createBrotliCompress({ params: { [constants.BROTLI_PARAM_QUALITY]: 5 } })
    : createGzip();

async function send(res, body, encoding) {
  if (!encoding) return pipeline(body, res);

  return pipeline(body, compressor(encoding), res);
}

function toRequest(req) {
  const url = new URL(req.url ?? '/', process.env.PUBLIC_URL ?? `http://${req.headers.host}`);
  const headers = new Headers();

  for (const [name, value] of Object.entries(req.headers)) {
    for (const each of [value].flat()) if (each !== undefined) headers.append(name, each);
  }

  const hasBody = req.method !== 'GET' && req.method !== 'HEAD';

  return new Request(url, {
    method: req.method,
    headers,
    ...(hasBody ? { body: Readable.toWeb(req), duplex: 'half' } : {}),
  });
}

async function renderPage(req, res) {
  const response = await render(toRequest(req));
  const type = response.headers.get('content-type');
  const encoding = response.body ? encodingFor(req, type) : null;
  const headers = {};

  response.headers.forEach((value, name) => {
    if (name !== 'set-cookie' && !(encoding && name === 'content-length')) headers[name] = value;
  });

  const cookies = response.headers.getSetCookie();
  if (cookies.length) headers['set-cookie'] = cookies;
  if (encoding) headers['content-encoding'] = encoding;
  headers.vary = 'Accept-Encoding';

  res.writeHead(response.status, headers);
  if (!response.body || req.method === 'HEAD') return res.end();

  return send(res, Readable.fromWeb(response.body), encoding);
}

async function fileFor(pathname) {
  const path = normalize(join(root, decodeURIComponent(pathname)));
  if (!path.startsWith(root + sep)) return null;

  const info = await stat(path).catch(() => null);

  return info?.isFile() ? { path, size: info.size } : null;
}

const fromApi = (pathname) =>
  pathname === '/robots.txt' ||
  pathname === '/sitemap.xml' ||
  pathname.startsWith('/sitemaps/') ||
  pathname.startsWith('/og/');

async function proxy(req, res) {
  // Share cards answer with a redirect to the stored image, which goes back to the browser as is
  const answer = await fetch(api + req.url, {
    headers: { accept: req.headers.accept ?? '*/*' },
    redirect: 'manual',
  });
  const location = answer.headers.get('location');
  res.writeHead(answer.status, {
    'content-type': answer.headers.get('content-type') ?? 'text/plain',
    'cache-control': answer.headers.get('cache-control') ?? 'public, max-age=3600',
    ...(location ? { location } : {}),
  });
  res.end(Buffer.from(await answer.arrayBuffer()));
}

const server = createServer(async (req, res) => {
  const { pathname } = new URL(req.url ?? '/', 'http://localhost');

  try {
    if (fromApi(pathname)) return await proxy(req, res);

    const file = await fileFor(pathname);
    if (file && (req.method === 'GET' || req.method === 'HEAD')) {
      const type = TYPES[extname(file.path)] ?? 'application/octet-stream';
      const encoding = encodingFor(req, type);

      res.writeHead(200, {
        'content-type': type,
        ...(encoding ? { 'content-encoding': encoding } : { 'content-length': file.size }),
        vary: 'Accept-Encoding',
        // Built assets carry a content hash in their names so they never change
        'cache-control': pathname.startsWith('/assets/')
          ? 'public, max-age=31536000, immutable'
          : 'public, max-age=3600',
      });
      if (req.method === 'HEAD') return res.end();
      return await send(res, createReadStream(file.path), encoding);
    }

    return await renderPage(req, res);
  } catch (error) {
    console.error(error);
    if (!res.headersSent) res.writeHead(502, { 'content-type': 'text/plain' });
    res.end('Something went wrong.');
  }
});

const port = Number(process.env.PORT ?? 3000);
const host = process.env.HOST ?? '0.0.0.0';

server.listen(port, host, () => console.log(`Hearth web on http://${host}:${port}`));
