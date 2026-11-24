defmodule Hearth.Media.Worker.DeleteMedia do
  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [period: 300, keys: [:media_id], states: :incomplete]

  alias Hearth.Media.Asset
  alias Hearth.Media.Command.DeleteMedia

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_id" => media_id}}) do
    [id: media_id]
    |> Asset.get()
    |> delete()
  end

  defp delete(nil), do: :ok
  defp delete(%Asset{} = media), do: with({:ok, _media} <- DeleteMedia.execute(media), do: :ok)
end
