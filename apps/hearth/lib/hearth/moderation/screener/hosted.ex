defmodule Hearth.Moderation.Screener.Hosted do
  @behaviour Hearth.Moderation.Screener

  alias Hearth.Moderation.Screener.Hosted.ApiError
  alias Hearth.Moderation.Screener.Hosted.Assessment
  alias Hearth.Moderation.Verdict

  @app :hearth
  @req_options Application.compile_env(@app, [__MODULE__, :req_options], [])

  @instructions """
  You check what people post in an online community. Decide whether the content \
  breaks the rules: violence or threats, hate, harassment or insults, sexual content, \
  self harm, illegal acts, or personal data about someone else. Spam and advertising \
  count only when obvious. Answer `safe` when it breaks none, `controversial` when it \
  depends on context, `unsafe` when it clearly breaks one. `score` is how likely it \
  breaks a rule, from 0 to 1. `categories` names the rules it may break. `reason` is \
  one short sentence for a moderator, or null when it is safe.\
  """

  # Images are sent this size at most, to keep requests small
  @image_side 768

  @impl Hearth.Moderation.Screener
  def screen_text(text, opts) do
    complete([%{"type" => "text", "text" => text}], opts)
  end

  @impl Hearth.Moderation.Screener
  def screen_image(bytes, opts) do
    with {:ok, image} <- Image.from_binary(bytes),
         {:ok, small} <- Image.thumbnail(image, @image_side),
         {:ok, jpeg} <- Image.write(small, :memory, suffix: ".jpg") do
      url = "data:image/jpeg;base64," <> Base.encode64(jpeg)
      complete([%{"type" => "image_url", "image_url" => %{"url" => url}}], opts)
    else
      {:error, _reason} -> {:error, :unreadable}
    end
  end

  @spec complete([map()], keyword()) ::
          {:ok, Verdict.t()} | {:error, :malformed | ApiError.t() | Exception.t()}
  defp complete(content, opts) do
    request = build(url: "/chat/completions", json: body(content, opts[:guidelines]))

    with {:ok, response} <- Req.post(request) do
      parse_result(response)
    end
  end

  def build(opts) do
    opts
    |> Keyword.merge(@req_options)
    |> Keyword.put(:base_url, config(:base_url))
    |> Keyword.put(:auth, {:bearer, config(:api_key)})
    |> Keyword.put(:receive_timeout, config(:receive_timeout))
    |> Req.new()
  end

  def parse_result(response) do
    case response do
      %Req.Response{status: 200, body: %{"choices" => [%{"message" => message} | _rest]}} ->
        assessment(message)

      %Req.Response{status: status, body: body} ->
        {:error, error(status, body)}
    end
  end

  defp body(content, guidelines) do
    %{
      "model" => config(:model),
      "temperature" => 0,
      "messages" => [
        %{"role" => "system", "content" => instructions(guidelines)},
        %{"role" => "user", "content" => content}
      ],
      "response_format" => %{
        "type" => "json_schema",
        "json_schema" => %{"name" => "verdict", "strict" => true, "schema" => Assessment.schema()}
      }
    }
  end

  defp instructions(nil), do: @instructions

  defp instructions(guidelines) do
    @instructions <> "\n\nThis community's own guidelines:\n" <> guidelines
  end

  defp assessment(%{"content" => content}) when is_binary(content) do
    {:ok, content |> Jason.decode!() |> Assessment.from!()}
  rescue
    _error in [Jason.DecodeError, ArgumentError, MatchError, KeyError] -> {:error, :malformed}
  end

  defp assessment(_message), do: {:error, :malformed}

  defp error(status, %{} = body), do: body |> Map.put("status", status) |> ApiError.from!()
  defp error(status, _body), do: ApiError.from!(%{"status" => status})

  defp config(key), do: @app |> Application.fetch_env!(__MODULE__) |> Keyword.fetch!(key)
end
