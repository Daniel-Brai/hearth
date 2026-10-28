# Hearth

The domain of Hearth. Every rule, every write and every background job lives
here. The API in `apps/hearth_web` only checks requests, calls into this app
and shapes the replies. Nothing in this app knows about HTTP.

## Contexts

Each area is a context with one public module, such as `Hearth.Forum` or
`Hearth.Voice`. Each one is a [Boundary](https://hex.pm/packages/boundary)
that declares what it depends on and what it exports, and the compiler
refuses a call that crosses a boundary it shouldn't.

| Context | What it owns |
| --- | --- |
| `Accounts`, `Auth` | People, settings, sign in by email code or Google and GitHub, tokens |
| `Communities`, `IAM` | Communities, rooms, invites, requests, bans, roles and permissions |
| `Forum` | Posts, replies, tags, drafts, reactions, reads and watches |
| `Chat` | Room and direct messages, reactions and read markers |
| `Events` | Scheduled events, interest and reminders |
| `Voice`, `RTC` | Live voice sessions, stage and open rooms, screen share and recordings |
| `Transcripts`, `AI` | Transcripts of recordings, with Whisper running on your own machines |
| `Media`, `Storage` | Uploads, image and video processing, and local or S3 storage |
| `Moderation` | Reports, the review queue, screening and the public log |
| `Notifications` | In app notices, email, digests and web push |
| `Instance` | Instance settings and the check for new releases |
| `Common` | Small shared helpers, ids, slugs, Markdown and tracing spans |

## Inside a context

- The public module is a thin facade. It checks permissions and passes the
  work on, and it never touches `Repo` or builds a query itself.
- Schemas own their queries.
- `command/` holds writes that touch more than one table, run in a transaction.
- `worker/` holds Oban jobs.
- `event/` holds events broadcast to clients over the socket.
- `listener/` reacts to events from other contexts.
- Status rules, such as a recording moving from recording to processing to
  ready, are XFsm machines.

## Roles

One release runs on every node. `HEARTH_ROLES` decides what each node does,
and every node still joins the cluster and runs the database, PubSub and Oban.

| Role | What it runs |
| --- | --- |
| `web` | The API, mail, digests and push |
| `rtc` | Voice sessions and the WebRTC connections to browsers |
| `media` | ffmpeg and image work for uploads, recordings and exports |
| `ai` | Transcription and content screening models |

A blank `HEARTH_ROLES` runs `web`, `media` and `ai`. Each Oban queue belongs to
one role, and a node only works the queues of its roles.

## Configuration

Settings live in `config/<area>/` at the root of the umbrella. Each one reads
its environment variable through Confex when the app starts. `.env.example`
at the root lists them all.

## Tests

Run these from the root of the umbrella.

```sh
mix test apps/hearth/test                  # this app
mix test apps/hearth/test/hearth/voice     # one context
```

Shared setup, such as making a community or a running voice session, lives
in `Hearth.TestUtils` in `test/support`.
