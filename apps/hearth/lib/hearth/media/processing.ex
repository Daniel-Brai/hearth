defmodule Hearth.Media.Processing do
  # Steps both media workers share so a lost or refused file ends the same way in each

  alias Hearth.Media.Asset
  alias Hearth.Media.Command.FailMedia
  alias Hearth.Storage

  @type cancel :: {:error, {:cancel, String.t(), atom()}}

  @spec download(Asset.t(), Path.t()) :: :ok | cancel() | {:error, term()}
  def download(%Asset{} = media, path) do
    case Storage.download(media.bucket_key, path) do
      :ok -> :ok
      {:error, :not_found} -> cancel_with("The file was lost before it was processed.", :missing)
      error -> error
    end
  end

  @spec cancel_with(String.t(), atom()) :: cancel()
  def cancel_with(failure, reason), do: {:error, {:cancel, failure, reason}}

  # A cancelled file is failed for its uploader and the job stops without a retry
  @spec outcome(Asset.t(), {:ok, term()} | {:error, term()}) ::
          :ok | {:cancel, atom()} | {:error, term()}
  def outcome(_media, {:ok, _done}), do: :ok

  def outcome(media, {:error, {:cancel, failure, reason}}) do
    _failed = FailMedia.execute(media, failure)
    {:cancel, reason}
  end

  def outcome(_media, {:error, _reason} = error), do: error
end
