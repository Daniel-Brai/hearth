defmodule Hearth.Auth.EmailInput do
  use Ecto.Schema

  import Ecto.Changeset
  import Hearth.Repo.Changeset

  alias Ecto.Changeset
  alias Hearth.Common

  @primary_key false

  embedded_schema do
    field :email, :string
  end

  @spec cast(String.t()) :: {:ok, String.t()} | {:error, Changeset.t()}
  def cast(email) when is_binary(email) do
    %__MODULE__{}
    |> cast(%{email: email}, [:email])
    |> update_change(:email, &Common.normalize/1)
    |> validate_required([:email])
    |> validate_email(:email)
    |> apply_action(:validate)
    |> then(fn
      {:ok, %__MODULE__{email: email}} -> {:ok, email}
      {:error, _changeset} = error -> error
    end)
  end

  @spec cast_new(String.t(), String.t()) :: {:ok, String.t()} | {:error, Changeset.t()}
  def cast_new(email, current) when is_binary(email) do
    with {:ok, email} <- cast(email) do
      case email == current do
        true -> {:error, same(email)}
        false -> {:ok, email}
      end
    end
  end

  defp same(email) do
    %__MODULE__{}
    |> cast(%{email: email}, [:email])
    |> add_error(:email, "is already your email")
    |> Map.put(:action, :validate)
  end
end
