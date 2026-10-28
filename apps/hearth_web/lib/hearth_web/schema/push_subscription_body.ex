defmodule HearthWeb.Schema.PushSubscriptionBody do
  use JSV.Schema

  defschema %{
    title: "PushSubscriptionBody",
    type: :object,
    description: "The browser's push subscription with its keys flattened",
    required: [:endpoint, :p256dh, :auth],
    additionalProperties: false,
    properties: %{
      endpoint: string(maxLength: 2000),
      p256dh: string(maxLength: 100),
      auth: string(maxLength: 100)
    }
  }
end
