if Code.ensure_loaded?(Credo.Check) do
  defmodule Credo.Check.Refactor.UseWordSigil do
    use Credo.Check,
      base_priority: :low,
      category: :refactor,
      param_defaults: [
        atom_min_length: 3,
        string_min_length: 2
      ],
      explanations: [
        check: "Lists of static atoms or strings should use the word sigil `~w[]` for brevity.",
        params: [
          atom_min_length: "The minimum length of a static list of atoms.",
          string_min_length: "The minimum length of a static list of strings."
        ]
      ]

    @doc false
    @impl Credo.Check
    def run(%SourceFile{} = source_file, params) do
      ctx = Context.build(source_file, params, __MODULE__)
      result = Credo.Code.prewalk(source_file, &walk/2, ctx)
      result.issues
    end

    # An interpolated sigil has no fixed number of words
    defp walk({:sigil_w, _meta, [{:<<>>, _parts_meta, parts}, _modifier]} = ast, ctx)
         when length(parts) != 1 or not is_binary(hd(parts)) do
      {ast, ctx}
    end

    defp walk({:sigil_w, _meta, args} = ast, ctx) do
      [{:<<>>, meta, [words]}, modifier] = args

      type =
        case modifier do
          [] -> :string
          ~c'a' -> :atom
        end

      parts = String.split(words)
      min_length = detect_min_length(type, ctx)

      case Enum.count(parts) >= min_length do
        true -> {ast, ctx}
        false -> {ast, put_issue(ctx, issue_for(ctx, type, parts, meta))}
      end
    end

    defp walk({_, meta, args} = ast, ctx) when is_list(args) do
      ctx =
        Enum.reduce(args, ctx, fn
          arg, acc when is_list(arg) -> check_list(acc, arg, meta)
          _arg, acc -> acc
        end)

      {ast, ctx}
    end

    defp walk(ast, ctx), do: {ast, ctx}

    # Options such as values: [:a, :b, :c] are checked too
    # meaning each value of a keyword list passed to a call
    defp check_list(ctx, list, meta) do
      case Keyword.keyword?(list) and list != [] do
        true -> Enum.reduce(list, ctx, fn {_key, value}, acc -> check_value(acc, value, meta) end)
        false -> check_static(ctx, list, meta)
      end
    end

    defp check_value(ctx, value, meta) when is_list(value), do: check_static(ctx, value, meta)
    defp check_value(ctx, _value, _meta), do: ctx

    defp check_static(ctx, list, meta) do
      min_length = detect_min_length(list, ctx)

      case Enum.count(list) >= min_length and static_terms?(list) do
        false -> ctx
        true -> put_issue(ctx, issue_for(ctx, list, meta))
      end
    end

    # A word list can't hold an empty string or one with spaces so lists that
    # do are left alone
    defp static_terms?(list) do
      Enum.all?(list, &word?/1) or Enum.all?(list, &(is_atom(&1) and &1 != nil))
    end

    defp word?(value) when is_binary(value), do: value != "" and String.split(value) == [value]
    defp word?(_value), do: false

    defp detect_min_length(list, ctx) when is_list(list) do
      detect_min_length(detect_type(list), ctx)
    end

    defp detect_min_length(type, ctx) do
      case type do
        :atom -> ctx.params.atom_min_length
        :string -> ctx.params.string_min_length
      end
    end

    defp detect_type(list) do
      case List.first(list) do
        value when is_atom(value) and value != nil -> :atom
        _ -> :string
      end
    end

    defp issue_for(ctx, list, meta) do
      {suffix, type} =
        case List.first(list) do
          value when is_atom(value) and value != nil -> {"]a", "atoms"}
          _ -> {"]", "strings"}
        end

      suggestion = "~w[" <> Enum.join(list, " ") <> suffix

      format_issue(
        ctx,
        message: "Use the word sigil `#{suggestion}` instead of a static list of #{type}.",
        trigger: hd(list),
        line_no: meta[:line]
      )
    end

    defp issue_for(ctx, type, list, meta) do
      suggestion =
        case type do
          :atom -> "[" <> Enum.map_join(list, ", ", &":#{&1}") <> "]"
          :string -> "[" <> Enum.map_join(list, ", ", &"\"#{&1}\"") <> "]"
        end

      format_issue(
        ctx,
        message: "Use `#{suggestion}` instead of a word list sigil.",
        trigger: hd(list),
        line_no: meta[:line]
      )
    end
  end
end
