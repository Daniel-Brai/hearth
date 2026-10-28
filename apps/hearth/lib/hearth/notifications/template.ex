defmodule Hearth.Notifications.Template do
  alias Phoenix.HTML
  alias Phoenix.LiveView.Rendered

  @spec to_string(Rendered.t()) :: String.t()
  def to_string(%Rendered{} = rendered) do
    rendered
    |> HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  @spec to_html(Rendered.t()) :: {:ok, String.t()} | {:error, String.t()}
  def to_html(%Rendered{} = rendered) do
    rendered
    |> __MODULE__.to_string()
    |> Mjml.to_html(keep_comments: false)
  end
end
