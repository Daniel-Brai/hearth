defmodule HearthWeb.InstanceJSON do
  def update_status(%{status: status}), do: status

  def show(%{settings: settings}) do
    Map.take(
      settings,
      ~w[
        name
        logo
        icon
        sign_in
        community_creation
        push_public_key
        upload_limits
        screening
        roles
        transcription
        voice
        recording
      ]a
    )
  end
end
