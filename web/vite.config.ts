/// <reference types="vitest/config" />
import tailwindcss from '@tailwindcss/vite';
import { reactRouter } from '@react-router/dev/vite';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vite';
import { VitePWA } from 'vite-plugin-pwa';

function gitCommit(): string | null {
  try {
    return execFileSync('git', ['rev-parse', '--short', 'HEAD'], {
      stdio: ['ignore', 'pipe', 'ignore'],
    })
      .toString()
      .trim();
  } catch {
    return null;
  }
}

const pkg = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8')) as {
  version: string;
};

const build = { version: pkg.version, commit: gitCommit(), builtAt: new Date().toISOString() };

export default defineConfig({
  define: { __HEARTH_BUILD__: JSON.stringify(build) },
  plugins: [
    // Vitest renders components on its own, without the router's build.
    !process.env.VITEST && reactRouter(),
    tailwindcss(),
    VitePWA({
      registerType: 'autoUpdate',
      // There is no index.html to add the script to. Entry.client registers the worker.
      injectRegister: null,
      outDir: 'build/client',
      includeAssets: [
        'favicon.svg',
        'favicon.ico',
        'favicon-16.png',
        'favicon-32.png',
        'favicon-96.png',
        'apple-touch-icon.png',
      ],
      manifest: {
        name: 'Hearth',
        short_name: 'Hearth',
        description: 'A forum, chat and voice home for your community.',
        theme_color: '#1d2433',
        background_color: '#ffffff',
        display: 'standalone',
        start_url: '/',
        icons: [
          { src: '/icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: '/icon-512.png', sizes: '512x512', type: 'image/png' },
          {
            src: '/icon-maskable-512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'maskable',
          },
          { src: '/favicon.svg', sizes: 'any', type: 'image/svg+xml' },
        ],
        shortcuts: [
          { name: 'Catch up', url: '/' },
          { name: 'Write a post', url: '/new' },
        ],
      },
      workbox: {
        // Screens are rendered by the server, so navigations go to it and fall back to
        // the last copy when offline, rather than to one static index.html.
        navigateFallback: null,
        importScripts: ['/push-sw.js'],
        // The emoji data, the emoji picker and the code highlighter load only when used,
        // so they are cached on first use below instead of downloaded on every first visit.
        globIgnores: ['**/native-*.js', '**/module-*.js', '**/highlight-*.js'],
        runtimeCaching: [
          {
            urlPattern: ({ request, url }) =>
              request.mode === 'navigate' && !/^\/(api|socket|webhooks)\//.test(url.pathname),
            handler: 'NetworkFirst',
            options: {
              cacheName: 'screens',
              networkTimeoutSeconds: 4,
              expiration: { maxEntries: 60, maxAgeSeconds: 60 * 60 * 24 * 7 },
            },
          },
          {
            urlPattern: ({ request, url }) =>
              request.destination === 'script' && url.pathname.startsWith('/assets/'),
            handler: 'CacheFirst',
            options: {
              cacheName: 'lazy-scripts',
              expiration: { maxEntries: 40, maxAgeSeconds: 60 * 60 * 24 * 90 },
            },
          },
          {
            urlPattern: ({ request }) => request.destination === 'image',
            handler: 'CacheFirst',
            options: {
              cacheName: 'images',
              expiration: { maxEntries: 200, maxAgeSeconds: 60 * 60 * 24 * 30 },
            },
          },
        ],
      },
      devOptions: { enabled: false },
    }),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
      // The Elixir umbrella's apps, for files the web app checks itself against (permissions.yml).
      '@apps': fileURLToPath(new URL('../apps', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    host: '127.0.0.1',
    strictPort: true,
    // Phoenix owns robots, sitemaps and share cards. In production Caddy, or scripts/serve.mjs, routes them there.
    proxy: Object.fromEntries(
      ['/robots.txt', '/sitemap.xml', '/sitemaps', '/og'].map((path) => [
        path,
        { target: process.env.VITE_API_URL ?? 'http://localhost:4000', changeOrigin: true },
      ]),
    ),
  },
  test: {
    environment: 'jsdom',
    // Each worker builds jsdom once and still runs every file in its own context
    pool: 'vmThreads',
    globals: false,
    setupFiles: ['./src/test/setup.ts'],
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    css: false,
  },
});
