defmodule Hearth.Notifications.WebPushMessage do
  @derive Jason.Encoder
  @enforce_keys [:title]
  defstruct [:title, :body, :tag, url: "/", options: []]

  @type t :: %__MODULE__{
          title: String.t(),
          body: nil | String.t(),
          tag: nil | String.t(),
          url: String.t(),
          options: keyword()
        }
end
