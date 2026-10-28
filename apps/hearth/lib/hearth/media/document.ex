defmodule Hearth.Media.Document do
  @office %{
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" =>
      ~c"word/document.xml",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => ~c"xl/workbook.xml",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" =>
      ~c"ppt/presentation.xml"
  }

  @spec check(Path.t(), String.t()) :: :ok | {:error, :content_mismatch}
  def check(path, "application/pdf") do
    case read_start(path, 5) do
      "%PDF-" -> :ok
      _other -> {:error, :content_mismatch}
    end
  end

  def check(path, type) when is_map_key(@office, type) do
    main = Map.fetch!(@office, type)

    archive = String.to_charlist(path)

    case :zip.list_dir(archive) do
      {:ok, entries} ->
        found? = Enum.any?(entries, &match?({:zip_file, ^main, _info, _comment, _at, _size}, &1))
        if found?, do: :ok, else: {:error, :content_mismatch}

      {:error, _reason} ->
        {:error, :content_mismatch}
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  def check(path, type) when type in ~w[text/csv text/plain] do
    text = File.read!(path)

    case String.valid?(text) and not String.contains?(text, <<0>>) do
      true -> :ok
      false -> {:error, :content_mismatch}
    end
  end

  def check(_path, _type), do: {:error, :content_mismatch}

  # sobelow_skip ["Traversal.FileModule"]
  defp read_start(path, bytes) do
    File.open!(path, [:read, :binary], &IO.binread(&1, bytes))
  end
end
