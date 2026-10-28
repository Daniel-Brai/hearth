defmodule Hearth.Auth.Provider do
  # A provider is on only when its client id and secret are set

  alias Assent.Strategy.Github
  alias Assent.Strategy.Google

  @strategies %{github: Github, google: Google}

  @type t :: :github | :google

  @spec enabled() :: [t()]
  def enabled do
    configured()
    |> Keyword.keys()
    |> Enum.filter(&Map.has_key?(@strategies, &1))
    |> Enum.sort()
  end

  @spec cast(term()) :: {:ok, t()} | {:error, :not_found}
  def cast(name) when is_binary(name) or is_atom(name) do
    case Enum.find(enabled(), &(Atom.to_string(&1) == to_string(name))) do
      nil -> {:error, :not_found}
      provider -> {:ok, provider}
    end
  end

  @spec authorize_url(t(), String.t()) :: {:ok, %{url: String.t(), session_params: map()}}
  def authorize_url(provider, redirect_uri) do
    config = config(provider, redirect_uri)

    @strategies
    |> Map.fetch!(provider)
    |> then(& &1.authorize_url(config))
  end

  @spec callback(t(), String.t(), map(), map()) :: {:ok, map()} | {:error, term()}
  def callback(provider, redirect_uri, %{} = params, %{} = session_params) do
    config =
      provider
      |> config(redirect_uri)
      |> Keyword.put(:session_params, session_params)

    strategy = Map.fetch!(@strategies, provider)

    with {:ok, %{user: claims}} <- strategy.callback(config, params) do
      {:ok, claims}
    end
  end

  defp config(provider, redirect_uri) do
    configured()
    |> Keyword.fetch!(provider)
    |> Keyword.merge(redirect_uri: redirect_uri, http_adapter: Assent.HTTPAdapter.Req)
  end

  defp configured do
    :hearth
    |> Application.get_env(Hearth.Auth, [])
    |> Keyword.get(:providers, [])
  end
end
