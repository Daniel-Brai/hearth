# Conventions

How work gets committed, checked and released in Hearth, and the code style the checks enforce.

## At a glance

| When                       | What runs                                                                                | Configured in                  |
| -------------------------- | ---------------------------------------------------------------------------------------- | ------------------------------ |
| You write a commit message | Conventional Commits check (`mix git_ops.check_message`)                                 | `config/dev.exs`, `:git_hooks` |
| `git commit`               | Unused lock entries removed, formatting checked, `mix credo --strict`, `mix.lock` staged | `config/dev.exs`, `:git_hooks` |
| `git push`                 | `mix dialyzer`, `mix test --max-failures 1`, `mix scan`, `pnpm --dir web run check`      | `config/dev.exs`, `:git_hooks` |
| A release                  | Next version, `CHANGELOG.md`, tag (`mix git_ops.release`)                                | `config/dev.exs`, `:git_ops`   |

All of these tools are development dependencies of the umbrella root (`mix.exs`), so they never ship in the release.

## Commit messages

Commits follow [Conventional Commits](https://www.conventionalcommits.org), in this shape.

```
type(optional scope)!: short description in the imperative

Optional body that says why the change was made.

BREAKING CHANGE: optional footer describing what breaks.
```

Some examples.

```
feat(chat): edit messages in the message box
fix(uploads): refuse documents whose contents do not match their extension
chore: update dependencies
feat(api)!: version the API by date in the Hearth-Version header
```

| Type                   | Use it for                                        | In the changelog         | Version bump |
| ---------------------- | ------------------------------------------------- | ------------------------ | ------------ |
| `feat`                 | Something people can now do                       | Features                 | minor        |
| `fix`                  | Something that was broken now works               | Bug Fixes                | patch        |
| `improvement`          | A better version of something that already worked | Improvements             | patch        |
| `perf`                 | Faster or lighter, same behaviour                 | Performance Improvements | patch        |
| `refactor`             | Code changes with no change in behaviour          | hidden                   | none         |
| `test`                 | Tests only                                        | hidden                   | none         |
| `docs`                 | Documentation only                                | hidden                   | none         |
| `style`                | Formatting only                                   | hidden                   | none         |
| `build`, `ci`, `chore` | Tooling, CI, dependencies, housekeeping           | hidden                   | none         |

- A `!` after the type or scope, or a `BREAKING CHANGE:` footer, marks a breaking change and bumps the major version.
- Scopes are optional and name the area. That's an umbrella app or context (`forum`, `chat`, `voice`, `media`, `iam`), or `web` for the React app.
- The commit-msg hook rejects messages that do not follow the format.
- Pull request titles follow the same format. A squash merge on GitHub uses the title as the commit message, and local hooks never see it.

## Git hooks

[git_hooks](https://hex.pm/packages/git_hooks) installs the hooks into `.git/hooks` when the project compiles in dev, and `mix setup` installs them on a fresh clone. To install them again after changing the configuration, run this.

```bash
mix git_hooks.install
```

- **Commit** runs the quick checks. Anything that fails here is cheap to fix before it is recorded.
- **Push** runs the slow checks. Those are dialyzer, the full Elixir test suite with Postgres running, `mix scan` and the web app's `pnpm run check`.
- The pre-commit hook checks formatting with `--check-formatted` and does not rewrite files. Run `mix format` yourself, and `pnpm format` in `web/`.

To run a hook's checks without committing or pushing, use one of these.

```bash
mix git_hooks.run pre_commit
```

```bash
mix git_hooks.run all
```

`git commit --no-verify` skips the hooks. Keep it for emergencies. CI runs the same checks, so it only moves the failure later.

## Releases and the changelog

[git_ops](https://hex.pm/packages/git_ops) reads the commits since the last tag, picks the next version from their types, adds a section to `CHANGELOG.md`, updates `@version` in the root `mix.exs`, commits and tags `vX.Y.Z`.

The first release needs at least one commit.

```bash
mix git_ops.release --initial
```

Every release after that is previewed first, then made and pushed.

```bash
mix git_ops.release --dry-run
```

```bash
mix git_ops.release
```

```bash
git push --follow-tags
```

- The version lives only in `@version` in the root `mix.exs`. The release built from the umbrella uses it. The apps' own `version:` fields are not bumped.
- Once the repository is on GitHub, set `repository_url` in the `:git_ops` config so changelog entries link to their commits.

## Elixir checks

### Formatting

`mix format` from the umbrella root formats every app, including `.heex` templates. Unformatted code fails the pre-commit hook.

### Credo

`mix credo` runs in strict mode over every app's `lib/`, `test/` and `priv/repo/`, since `.credo.exs` sets `strict: true`.

These are the rules that most shape everyday code.

| Rule                                                                                                                               | Write                                                                          | Not                                                                             |
| ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| No one-step pipelines (`SinglePipe`)                                                                                               | `String.trim(name)`                                                            | `name \|> String.trim()`                                                        |
| Pipelines start with a value (`PipeChainStart`)                                                                                    | `:get \|> conn("/") \|> put_req_header(...)`                                   | `conn(:get, "/") \|> put_req_header(...)`                                       |
| No calls nested in calls (`NestedFunctionCalls`)                                                                                   | `request = conn(:get, "/")` then `Plug.call(request, opts)`                    | `Plug.call(conn(:get, "/"), opts)`                                              |
| No rebinding a name (`VariableRebinding`)                                                                                          | `request = ...`, then `conn = ...`                                             | `conn = ...`, then `conn = ...`                                                 |
| Static lists use the word sigil (`UseWordSigil`, custom), including option values such as `values:`                                | `~w[html json]`, `~w[get post put]a`, `values: ~w[sent failed bounced]a`       | `["html", "json"]`, `[:get, :post, :put]`, `values: [:sent, :failed, :bounced]` |
| A type that may be nil starts with `nil` (`NilFirstInUnion`, custom), in `@spec`, `@type` and `@callback`, keyword fields included | `nil \| String.t()`, `name: nil \| T.id()`                                     | `String.t() \| nil`                                                             |
| Aliases at the top, in order (`AliasUsage`, `AliasOrder`, `StrictModuleLayout`)                                                    | `alias Ecto.Adapters.SQL.Sandbox` at the top, then `Sandbox.start_owner!(...)` | `Ecto.Adapters.SQL.Sandbox.start_owner!(...)` in the body                       |
| `@impl` names the behaviour (`ImplTrue`)                                                                                           | `@impl Plug`                                                                   | `@impl true`                                                                    |
| No debugging leftovers (`Dbg`, `IoInspect`, `IoPuts`)                                                                              | `Logger.debug/1`                                                               | `dbg/1`, `IO.inspect/2`, `IO.puts/1`                                            |
| No `Mix.env()` at runtime (`MixEnv`)                                                                                               | `Application.compile_env/3` or config                                          | `Mix.env()` in `lib/`                                                           |

When nesting and pipe rules pull against each other, give each intermediate value its own name.

Write `@spec` and `@doc` for public functions only. Private functions get neither. Their names and the public function's spec carry the meaning.

Leave out `@moduledoc`, `@doc` and `@typedoc` when the name already makes it clear. `Hearth.Repo.Page`, `valid_id?/1` and `new_id/0` need none. Write one only for what the name cannot say, such as a rule (`slugify/1` matches the web app), a reason (why ids are monotonic), the options a macro takes, or an example that runs as a doctest.

Keep doc prose plain. No colons, semicolons or em dashes where a full stop does the job.

To see why something was flagged, pass Credo the file and line from its report.

```bash
mix credo explain apps/hearth_web/lib/hearth_web/endpoint.ex:12
```

To accept one finding on purpose, disable that check for that line only, with the reason in the comment above it.

```elixir
# Phoenix generates this signature and the attributes depend on it.
# credo:disable-for-next-line Credo.Check.Readability.NestedFunctionCalls
```

Custom checks live in `credo/lib/credo/check/` and are loaded through `requires:` in `.credo.exs`. Wrap each one in `if Code.ensure_loaded?(Credo.Check) do ... end`, because Credo is only present in dev and test.

### Dialyzer

`mix dialyzer` type checks the umbrella. The first run builds a cache of the dependencies' types and takes a couple of minutes. Later runs take seconds. Hearth runs without `:no_opaque`, so add it to the `dialyzer:` config only if opaque type warnings appear that the code cannot fix.

### Security scan

`mix scan` runs two checks.

- `mix deps.audit` checks `mix.lock` against known security advisories.
- `mix sobelow --skip` runs Sobelow, Phoenix's security scanner, in every app. Every app lists `:sobelow` in its own deps because it runs per app.

A finding accepted on purpose gets a `# sobelow_skip ["Check.Name"]` comment above the code, with the reason. The `browser` pipeline skips `Config.CSP` because `HearthWeb.Plugs.ContentSecurityPolicy` sets the policy with a nonce per request, which Sobelow cannot see.

## Configuration

`config/` is split by area.

```
config/
├── config.exs, dev.exs, test.exs, prod.exs   # logger, git hooks, imports
├── runtime.exs                                # only what needs logic
├── accounts/  auth/  buffer/  communities/  hearth/  jobs/  media/
│   notifications/  repo/  storage/  web/
│   └── config.exs + dev.exs / test.exs / prod.exs as needed
```

- `config.exs` imports the environment file first, then each area's `config.exs`, which imports its own environment file.
- A value read from an environment variable is written where it belongs as `{:system, "NAME"}` (required), `{:system, "NAME", default}` or `{:system, :integer, "NAME", default}`. [Confex](https://hex.pm/packages/confex) resolves them when each app starts (`Confex.resolve_env!/1` in `Hearth.Application` and `HearthWeb.Application`), so a release reads them at boot.
- `runtime.exs` keeps only what a lookup can't express. That's choosing the mail adapter from `MAIL_PROVIDER`, the Google and GitHub providers that are on, and IPv6 for the database.
- A new context with settings gets its own folder and an `import_config` line in `config.exs`.

## Tests

- Failure cases come first. In every module and every `describe`, write the refusals, invalid input and `nil` or `:error` results before the cases that succeed. Edge cases that must not match tend to find the bugs.
- One `describe` per public function, named `"function/arity"`. Test names are short, lowercase phrases that say what happens. Failures start with `fails` or `returns` (`"fails if user not authorized"`, `"returns not found"`, `"returns nil if no link"`), and successes are just the verb (`"get business"`, `"paginate entries"`, `"joins id and slug"`). The assertions show the details, so the name does not repeat them.
- Plug tests use `Plug.Test` directly. Build the request on its own line, take options from the plug's own `init/1`, and call the plug inside `assert`, which rebinds the result without breaking `VariableRebinding`.

  ```elixir
  conn = conn(:get, "/")

  assert conn = ContentSecurityPolicy.call(conn, ContentSecurityPolicy.init([]))
  ```

- Test files end in `_test.exs`. A `_test.ex` file never runs, and Credo flags it.
- Skipping a test needs a comment saying why (`SkipTestWithoutComment`).
- Tests that touch the database go through `Hearth.DataCase` or `HearthWeb.ConnCase`. Postgres must be running.

## Boundaries

Each context in `apps/hearth` is a [Boundary](https://hexdocs.pm/boundary). A call into a module that a boundary does not export is a compile warning, and warnings fail `mix compile --warnings-as-errors`. When a call is refused, decide whether the callee should export the module or whether the caller should go through the context's public functions. Do not export a schema just to make the warning go away.

A context's facade in `lib/hearth/<context>.ex` stays thin.

- It checks permissions, calls schema functions and commands, preloads, and broadcasts events. It never imports `Ecto.Query` or calls `Repo` directly.
- Each query is a named function on the schema that owns the table, such as `Request.list/1` or `Ban.active?/2`. `Hearth.Repo.Schema` already gives every schema `get/1`, `all/1`, `exists?/1`, `paginate/1`, `insert/2`, `update/2` and `delete/1`.
- A write that touches more than one table is a command, `Context.Command.Name.execute/n`, with its own `Repo.transact/1`.
- A context never reads another context's tables. It calls that context's facade, the way Chat asks `Communities.get_room/1` for a room.
- Data that is always read and replaced with its owner, is never queried on its own and has no foreign keys pointing at it is an embedded schema in a jsonb column (`users.settings`, `users.privacy`, `Common.Link` lists), not a table.
- A run of steps where each takes what the last returned and any may fail is a railway with [Rop](https://github.com/ruby2elixir/rop), as in `ensure_under_limits(id) >>> insert(params) >>> maybe_multipart()`. Each step returns `{:ok, value}` or `{:error, reason}`, and the first error ends the run. Start the chain with a plain call, not `|>`, so the formatter keeps it flat. Keep `with` for steps that need several earlier results by name.
- A status with rules about what may follow what is an [XFsm](https://hexdocs.pm/xfsm) machine in the context, such as `Media.Lifecycle`. When the steps happen in HTTP calls and jobs on any node, the machine is built from the row's current status for one event and thrown away, and the row is updated only if it is still at that status. A long-lived process per record with timers is for when the record lives on one node, in a supervisor and registry.

## API

Controllers in `hearth_web` use `use HearthWeb, :api_controller`, which validates each request against its oaskit operation and falls back to `HearthWeb.FallbackController`.

- Every `operation` has a short `summary` written like a test name ("Starts an upload"), so it reads well in `/docs`, `/redoc` and the generated client. Add a `description` only when the behaviour isn't obvious.
- Read the signed in person from the action head with `def create(%Conn{assigns: %{auth: %{}}} = conn, params)`, then `%Conn{assigns: %{auth: auth}} = conn`.
- Render through the view named after the controller, one function per action. `render(conn, :create, media: media)` goes to `UploadJSON.create/1`. Don't `put_view`.
- Return `{:error, reason}` from the context and let the fallback answer. Reasons become the error's `code`.
- Limit an action with `rate_limit :action, limit: 10, scale: :timer.minutes(15)`, adding `by: :user` or `by: {:body, :email}` when the address isn't the right key.
- Tests use `describe "create"`, failure cases first, and `conn |> auth_conn(user) |> post(...) |> valid_response(422)`. `ConnCase` already sends JSON and `Hearth-Version`.

## Web app

The React app in `web/` has its own conventions in `web/AGENTS.md`. The pre-push hook runs its check.

```bash
pnpm --dir web run check
```

It covers formatting, oxlint, TypeScript, knip, the tests and react-doctor.
