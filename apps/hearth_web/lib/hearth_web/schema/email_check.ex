defmodule HearthWeb.Schema.EmailCheck do
  use JSV.Schema

  defschema %{
    title: "EmailCheck",
    type: :object,
    required: [:email, :status],
    properties: %{
      email: string(),
      status:
        enum(~w[reachable unreachable unknown invalid],
          description:
            "Invalid isn't an address, unreachable has no mail server, unknown means DNS didn't answer in time"
        )
    }
  }
end
