# Hearth web

The React app people use. It renders public screens on the server with React
Router, so search engines and link previews see the content, and it runs as an
installable app in the browser after that.

## Run it

With the API running on port 4000, start the app from this folder.

```sh
pnpm install
pnpm dev
```

`make dev` at the root of the repo starts the API and this app together.

To try the app with sample data and no server, use the in-memory data instead.

```sh
VITE_HEARTH_DATA=mock pnpm dev
```

## Settings

`.env.example` lists them. Copy it to `.env` to change them.

| Variable             | What it does                                                              |
| -------------------- | ------------------------------------------------------------------------- |
| `VITE_HEARTH_DATA`   | `mock` runs on sample data in the browser, blank uses the API             |
| `VITE_API_URL`       | Where the API answers, `http://localhost:4000` by default                 |
| `VITE_TRANSCRIPTION` | With sample data, `off` shows an instance without transcripts or captions |
| `PUBLIC_URL`         | In production, the site's own address for links and share cards           |
| `API_INTERNAL_URL`   | In production, where the server reaches the API                           |

## Scripts

| Command        | What it does                                                                         |
| -------------- | ------------------------------------------------------------------------------------ |
| `pnpm dev`     | Starts the app with hot reload                                                       |
| `pnpm build`   | Checks types and builds for production                                               |
| `pnpm start`   | Serves the production build                                                          |
| `pnpm test`    | Runs the tests once, `pnpm test:watch` keeps them running                            |
| `pnpm check`   | Formatting, lint, types, unused code, tests and React Doctor. Run it before you push |
| `pnpm format`  | Formats everything with Prettier                                                     |
| `pnpm gen:api` | Regenerates the API client from the API's OpenAPI file                               |

## How it's laid out

| Folder              | What's in it                                                                    |
| ------------------- | ------------------------------------------------------------------------------- |
| `src/pages`         | One folder per screen, such as `post`, `chat` or `voice`                        |
| `src/shell`         | The frame around every screen, with the sidebar, bar, trays and dialogs         |
| `src/features`      | Pieces shared by several screens, such as the composer, Markdown and recordings |
| `src/design-system` | Buttons, fields, icons, emoji and the styles behind them                        |
| `src/domain`        | Types, selectors and the rules the screens follow                               |
| `src/data`          | The store and the gateway interface every screen talks to                       |
| `src/api`           | The gateway that talks to the API and its live socket                           |
| `src/mocks`         | The in-memory gateway and its sample data                                       |
| `src/runtime`       | Routes, sounds, haptics, keyboard shortcuts and the UI store                    |
| `src/generated`     | The API client and types made by orval. Never edit these by hand                |

Screens never call the API directly. They ask the gateway, which is the API
gateway against a server or the mock gateway on sample data. Both keep the
same store up to date, so every screen works the same either way.

## When the API changes

The API publishes its OpenAPI file, and orval turns it into the client in
`src/generated`. After changing an endpoint, run this at the root of the repo to write the file again and
regenerate the client.

```sh
make gen.api
```
