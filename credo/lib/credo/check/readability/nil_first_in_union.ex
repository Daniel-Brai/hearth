if Code.ensure_loaded?(Credo.Check) do
  defmodule Credo.Check.Readability.NilFirstInUnion do
    use Credo.Check,
      base_priority: :normal,
      category: :readability,
      explanations: [
        check: """
        In typespecs, a type that may be nil starts with `nil`, so a reader
        sees at once that the value can be absent.

            @spec find(String.t()) :: nil | User.t()

        rather than `User.t() | nil`.
        """
      ]

    @attributes ~w[spec type typep opaque callback macrocallback]a

    @doc false
    @impl Credo.Check
    def run(%SourceFile{} = source_file, params) do
      ctx = Context.build(source_file, params, __MODULE__)
      result = Credo.Code.prewalk(source_file, &walk/2, ctx)
      result.issues
    end

    defp walk({:@, _meta, [{attribute, _attr_meta, [type]}]} = ast, ctx)
         when attribute in @attributes do
      {ast, check(type, ctx)}
    end

    defp walk(ast, ctx), do: {ast, ctx}

    # A union a | b | nil nests to the right so it is flattened once here
    # and its members are checked for unions of their own
    defp check({:|, meta, _sides} = union, ctx) do
      members = members(union)

      ctx =
        case Enum.find_index(members, &(&1 == nil)) do
          index when index in [nil, 0] -> ctx
          _later -> put_issue(ctx, issue_for(ctx, meta))
        end

      Enum.reduce(members, ctx, &check/2)
    end

    defp check({left, right}, ctx), do: check(right, check(left, ctx))
    defp check({_name, _meta, args}, ctx) when is_list(args), do: Enum.reduce(args, ctx, &check/2)
    defp check(list, ctx) when is_list(list), do: Enum.reduce(list, ctx, &check/2)
    defp check(_leaf, ctx), do: ctx

    defp members({:|, _meta, [left, right]}), do: members(left) ++ members(right)
    defp members(type), do: [type]

    defp issue_for(ctx, meta) do
      format_issue(
        ctx,
        message: "Start a union that may be nil with `nil`, as in `nil | String.t()`.",
        trigger: "|",
        line_no: meta[:line]
      )
    end
  end
end
