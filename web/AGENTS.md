# Hearth web

The React PWA for Hearth. It holds the forum, chat, voice rooms and events of a self hosted community. Built with Vite, React 19, TypeScript, Tailwind 4, React Router 7 and Zustand.

## Commands

| Task            | Command                                                                                           |
| --------------- | ------------------------------------------------------------------------------------------------- |
| Dev             | `pnpm dev`, with `VITE_HEARTH_DATA=mock` for the in-memory data source                            |
| Build and serve | `pnpm build`, then `pnpm start` with `PORT`, `PUBLIC_URL` and `API_INTERNAL_URL`                  |
| Check           | `pnpm check` runs format, lint, types, knip, tests and react-doctor                               |
| Typecheck       | `pnpm typecheck`                                                                                  |
| Format          | `pnpm format`                                                                                     |
| Test            | `pnpm vitest run <file>`                                                                          |
| API types       | `pnpm gen:api` runs orval on the Phoenix OpenAPI spec                                             |
| Emoji glyph map | `pnpm gen:emoji` rebuilds `src/design-system/emoji/glyphs.json` after updating `@emoji-mart/data` |

## Layout

```
src/
  root.tsx        the document, theme script and head. routes.ts lists every screen
  entry.*.tsx     server render (waits for every load, appends the store) and browser hydration
  app/            route modules, runtime (data source), gateway and request context, structured data
  api/            the HTTP gateway and orval's fetch mutator
  data/           the HearthGateway interface, the Store snapshot and useAppState/useLoad
  domain/         types, pure selectors, events, links, formatting. No React, no transport.
  mocks/          the in-memory gateway and its seed. Only app/runtime.ts imports them, dynamically, so API builds never ship them. Product constants live in domain/catalog.ts
  design-system/  tokens, base and component CSS, icons, React components. Knows nothing about the domain.
  features/       pieces shared across screens, such as markdown rendering, the composer, previews and images
  shell/          the app frame with the sidebar, bar, header, dialogs, key handling and session hooks
  pages/          one folder per screen. `shared/` holds rows and cards used by several screens
  runtime/        routes, keys, sounds, theme, brand, the UI store
```

Dependencies flow `pages -> shell/features -> design-system/domain/data`. The design system never imports from `domain` beyond `format` and `types`, and `domain` never imports React.

## Data

Views read through `useAppState(selector)` and change things through `useGateway()`. Selectors live in `domain/selectors/`, one file per subject (`people`, `communities`, `access`, `posts`, `rooms`, `moderation`, `notifications`, `events`), and are imported from `@/domain/selectors`. They take the `AppState` snapshot. Rules about who may do what go in `access`, which only `communities` sits below, so the files never import each other in a circle. A selector result is compared shallowly, so return primitives, arrays or flat objects, never a fresh nested structure for the same data.

`HearthGateway` in `data/gateway.ts` is implemented twice. `MockGateway` answers from memory and `ApiGateway` talks to Phoenix. Both check the same rules (`canDo`, ownership, moderation level) and fill the same store. A screen calls `useLoad(() => gateway.load.x(id), 'x:' + id)` for what it is about to show. The first load of a key suspends, so the previous screen stays up until the new one is ready. Never render a screen-level loading skeleton. The result is `ready` or `error`.

Every write returns `Result<T>`. Branch on `ok`, and show `error` in a toast or next to the field. Nothing throws for an expected failure.

## Server rendering

React Router framework mode renders the public screens (home, community, tag, post, events, event, profile) on the server with the same components, gateway and store as the browser. `entry.server.tsx` gives each request its own store, load cache and request context, waits for every `useLoad`, then appends the store so `entry.client.tsx` hydrates from identical data. Screens under the `standalone` and `protected` layouts run in the browser only, through `clientLoader.hydrate` with a skeleton fallback.

- Anything a render reads must be the same on both sides. No `window`, `document`, storage, `navigator` or `Date.now()` driven text during render. Use `useHydrated()` for parts that exist only in the browser, `useOrigin()` for absolute links and `useDisplayZone()` when formatting times.
- Read the store with `useAppState` or `useStore`, never `getStore()` in render. The server runs many stores at once.
- Search data goes through `PageMeta`, with `noindex`, `jsonLd` from `useStructuredData` and the share image from `shareImage`.

## Conventions

- `@/` imports only. Same-folder `./` is fine.
- Absent values are `null`, never `''`. Optional props are `prop?: T | undefined`.
- No `any`. Discriminated unions and exhaustive `switch`. `satisfies` on data literals.
- No empty `catch`. Check first, or handle it by disabling the feature, reporting once or returning a result.
- Regexes are a last resort. Prefer string, URL and built in APIs (`Intl.DateTimeFormat`, `slugify` in `runtime/routes.ts`, marked's lexer). Keep libraries off the first load unless every screen needs them.
- CSS lives where it loads. Styles used by one lazily loaded screen or dialog go in a `.css` file beside its entry (`pages/events/EventsPage.css`), imported by that entry, so they arrive with its chunk. Anything the shell or more than one chunk uses stays in `design-system/styles/components.css`.
- Comments only for a rule, constraint or surprise, as TSDoc on the declaration. Nothing that restates the code, nothing about where code came from.
- Blank lines between logical steps. `pnpm format` before handing back.
- React uses lazy routes and `useAppState` selectors. No `forwardRef`, since ref is a prop. React Compiler is on, so skip manual memo unless a profile says otherwise.
- UI copy is plain and short. Every empty state says why it is empty and what to do next. Count badges use `cap()`.
- Screen-level shortcuts register with `usePageKeys`. Every icon button has `aria-label` and usually `data-tip`.
- Prose in comments and docs stays plain. No colons, semicolons or em dashes where a full stop does the job.

## Design system

`design-system/styles/components.css` holds the component classes (`.btn`, `.panel`, `.post-row`, `.chat`, `.message`, `.dialog`, `.popup`, `.empty` and more). React components in `design-system/components` wrap the common ones. For a one-off, use the class directly with Tailwind utilities for layout. Utilities win over component classes.

Colors come from tokens only (`var(--color-ink)`, `var(--hue-blue)`), never a raw color. `tintStyle(hue)` sets `--tint` for pills, marks and swatches.
