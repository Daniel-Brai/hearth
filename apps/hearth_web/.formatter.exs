[
  import_deps: [:jsv, :oaskit, :phoenix],
  locals_without_parens: [rate_limit: 2],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}"]
]
