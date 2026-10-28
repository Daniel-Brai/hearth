defmodule HearthWeb.Schema.NotificationPage do
  use JSV.Schema

  alias HearthWeb.Schema.Notification
  alias HearthWeb.Schema.PageMeta

  defschema %{
    title: "NotificationPage",
    type: :object,
    required: [:data, :meta, :unread],
    properties: %{
      data: array_of(Notification),
      meta: PageMeta,
      unread: non_neg_integer(description: "Across all pages")
    }
  }
end
