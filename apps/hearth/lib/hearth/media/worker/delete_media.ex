defmodule Hearth.Media.Worker.DeleteMedia do
  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [period: 300, keys: [:media_id], states: :incomplete]

  alias Hearth.Media.Asset
  alias Hearth.Media.Command.DeleteMedia

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_id" => media_id}}) do
    case Asset.get(id: media_id) do
      nil -> :ok
      %Asset{} = media -> with {:ok, _media} <- DeleteMedia.execute(media), do: :ok
    end
  end
end
