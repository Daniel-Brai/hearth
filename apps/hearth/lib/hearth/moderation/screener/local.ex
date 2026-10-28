defmodule Hearth.Moderation.Screener.Local do
  # Until the models are up a call answers {:error, :not_ready} and the job retries

  @behaviour Hearth.Moderation.Screener

  use Supervisor

  alias Hearth.Moderation.Screener.ImageModel
  alias Hearth.Moderation.Screener.TextModel

  require Logger

  @impl Hearth.Moderation.Screener
  def screen_text(text, _opts), do: TextModel.predict(text)

  @impl Hearth.Moderation.Screener
  def screen_image(bytes, _opts), do: ImageModel.predict(bytes)

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl Supervisor
  def init(_opts) do
    children = [
      {DynamicSupervisor, name: __MODULE__.Servings, strategy: :one_for_one},
      Supervisor.child_spec({Task, &start_servings/0}, restart: :transient)
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp start_servings do
    for {module, key} <- [{TextModel, :text_model}, {ImageModel, :image_model}] do
      repo = config(key)
      {time, serving} = :timer.tc(fn -> module.serving(repo, config(:batch_size)) end)

      {:ok, _pid} =
        DynamicSupervisor.start_child(
          __MODULE__.Servings,
          {Nx.Serving,
           serving: serving,
           name: module,
           batch_size: config(:batch_size),
           batch_timeout: config(:batch_timeout)}
        )

      Logger.info("Screening model #{repo} is up after #{div(time, 1_000)} ms")
    end
  end

  defp config(key), do: :hearth |> Application.fetch_env!(__MODULE__) |> Keyword.fetch!(key)
end
