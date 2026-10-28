defmodule Hearth.Repo.Schema do
  alias Hearth.Common.Id

  # A list filter matches any of its values and nil matches a missing one
  # update/2 passes on only the fields in @changeable

  defmacro __using__(opts \\ []) do
    # Id alone, since a call to Common here would make every schema recompile with any of Common
    id_options = Id.options()

    quote bind_quoted: [opts: opts, id_options: id_options] do
      use Ecto.Schema

      import Ecto.Query

      alias Hearth.Repo
      alias Hearth.Repo.Page

      @before_compile Hearth.Repo.Schema

      @schema_prefix opts[:prefix]
      @primary_key Keyword.get(opts, :primary_key, {:id, Ecto.UUID, autogenerate: id_options})
      @foreign_key_type Ecto.UUID
      @timestamps_opts [type: :utc_datetime_usec]

      Module.register_attribute(__MODULE__, :changeable, [])

      @spec get(keyword()) :: nil | Ecto.Schema.t()
      def get(opts) when is_list(opts) do
        opts
        |> query_from()
        |> Repo.one()
      end

      @spec all(keyword()) :: [Ecto.Schema.t()]
      def all(opts \\ []) when is_list(opts) do
        opts
        |> query_from()
        |> Repo.all()
      end

      @spec exists?(keyword()) :: boolean()
      def exists?(opts) when is_list(opts) do
        opts
        |> query_from()
        |> Repo.exists?()
      end

      @spec stream(keyword()) :: Enum.t()
      def stream(opts \\ []) when is_list(opts) do
        {stream_opts, filters} = Keyword.split(opts, [:max_rows])

        filters
        |> query_from()
        |> Repo.stream(stream_opts)
      end

      @pagination_opts ~w[filters after before limit order_by order_directions]a

      @spec paginate(keyword()) :: Page.t() | {:error, Flop.Meta.t()}
      def paginate(opts \\ []) when is_list(opts) do
        {flop_opts, filters} = Keyword.split(opts, @pagination_opts)

        limit_key =
          case flop_opts[:before] do
            nil -> :first
            _cursor -> :last
          end

        params =
          flop_opts
          |> Keyword.delete(:limit)
          |> Keyword.put(limit_key, flop_opts[:limit])
          |> Map.new()

        query = query_from(filters)

        with {:ok, flop} <- Repo.Flop.validate(params, for: __MODULE__),
             query = Flop.with_named_bindings(query, flop, &join_assocs/2, for: __MODULE__),
             {data, meta} <- Repo.Flop.run(query, flop, for: __MODULE__) do
          %Page{data: data, meta: meta}
        end
      end

      @spec delete(Ecto.Schema.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
      if opts[:soft_delete?] do
        def delete(%__MODULE__{} = schema) do
          schema
          |> Ecto.Changeset.change(deleted_at: DateTime.utc_now())
          |> Repo.update()
        end
      else
        def delete(%__MODULE__{} = schema), do: Repo.delete(schema)
      end

      defp query_from(opts, query \\ __MODULE__) do
        Enum.reduce(opts, query, fn
          {:preload, assocs}, query ->
            preload(query, ^assocs)

          {key, nil}, query ->
            where(query, [x], is_nil(field(x, ^key)))

          {key, values}, query when is_list(values) ->
            where(query, [x], field(x, ^key) in ^values)

          {key, value}, query ->
            where(query, [x], field(x, ^key) == ^value)
        end)
      end

      defp join_assocs(query, binding) do
        join(query, :left, [x], assoc in assoc(x, ^binding), as: ^binding)
      end

      defoverridable get: 1, exists?: 1, query_from: 2, join_assocs: 2
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @changeable_fields @changeable || []
      @changeable_keys @changeable_fields ++ Enum.map(@changeable_fields, &Atom.to_string/1)

      if Module.defines?(__MODULE__, {:changeset, 2}) and
           not Module.defines?(__MODULE__, {:insert, 2}) do
        @spec insert(struct(), map()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
        def insert(%__MODULE__{} = schema, %{} = params) do
          schema
          |> changeset(params)
          |> Hearth.Repo.insert()
        end
      end

      if Module.defines?(__MODULE__, {:changeset, 2}) and
           not Module.defines?(__MODULE__, {:update, 2}) do
        @spec update(struct(), map()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
        def update(%__MODULE__{} = schema, %{} = params) do
          changes = Map.take(params, @changeable_keys)

          schema
          |> changeset(changes)
          |> Hearth.Repo.update()
        end
      end
    end
  end
end
