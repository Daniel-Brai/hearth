import Config

# Commit messages follow Conventional Commits, which mix git_ops.release reads to pick the next version
config :git_ops,
  mix_project: Mix.Project.get!(),
  repository_url: "https://github.com/daniel-brai/hearth",
  changelog_file: "CHANGELOG.md",
  manage_mix_version?: true,
  manage_readme_version: false,
  version_tag_prefix: "v"

config :git_hooks,
  hooks: [
    commit_msg: [
      tasks: [
        {:cmd, "mix git_ops.check_message", include_hook_args: true}
      ]
    ],
    pre_commit: [
      tasks: [
        {:mix_task, :"deps.unlock", ["--unused"]},
        {:mix_task, :format, ["--check-formatted"]},
        {:mix_task, :credo, ["--strict"]},
        {:cmd, "git add mix.lock"}
      ]
    ],
    pre_push: [
      tasks: [
        {:mix_task, :dialyzer},
        {:mix_task, :test, ~w[--color --max-failures 1]},
        {:cmd, "mix scan"},
        {:cmd, "pnpm --dir web run check"}
      ]
    ]
  ]

config :logger, :default_formatter, format: "[$level] $metadata$message\n"
