defmodule HearthWeb.EventController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Events
  alias Hearth.IAM
  alias Plug.Conn

  tags ["Events"]

  @id [in: :path, schema: %{type: :string, format: :uuid}]

  operation :index,
    summary: "List upcoming events",
    description: "Without a community it lists every community the person joined",
    parameters: [community_id: [in: :query, schema: %{type: :string, format: :uuid}]],
    responses: [
      ok: {%{type: :array, items: Schema.CommunityEvent}, description: "OK"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"community_id" => ~V[uuid]}

  def index(%Conn{assigns: %{auth: auth}} = conn, params) do
    with {:ok, community_ids} <- community_ids(params["community_id"], auth) do
      events = Events.list_visible_upcoming(auth, community_ids)

      render(conn, :index, events: events, interested: Events.interested_ids(events))
    end
  end

  operation :create,
    summary: "Schedule an event",
    description: "Needs event.create in the community",
    security: [%{"bearer" => []}],
    parameters: [community_id: @id],
    request_body: Schema.ScheduleEventBody,
    responses: [
      created: {Schema.CommunityEvent, description: "Created"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "notify" => ~V[boolean],
    "title" => ~V[required|string|min:1|max:120],
    "description" => ~V[string|max:4000],
    "starts_at" => ~V[required|string],
    "duration_min" => ~V[required|integer|between:5,720],
    "timezone" => ~V[required|string|max:64],
    "repeat" => ~V[allowed:none,daily,weekly,biweekly,monthly],
    "place" => ~V[required|allowed:room,link],
    "room_id" => ~V[uuid],
    "url" => ~V[string|max:2000],
    "talk_mode" => ~V[allowed:stage,open]
  }

  def create(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"community_id" => community_id} = params

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, event} <-
           Events.schedule_event(auth, community, changes(params),
             notify: params["notify"] == true
           ) do
      conn |> put_status(:created) |> render_event(event)
    end
  end

  operation :update,
    summary: "Change an event",
    description: "For the host or anyone with event.create",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.UpdateEventBody,
    responses: [
      ok: {Schema.CommunityEvent, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "title" => ~V[string|min:1|max:120],
    "description" => ~V[string|max:4000],
    "starts_at" => ~V[string],
    "duration_min" => ~V[integer|between:5,720],
    "timezone" => ~V[string|max:64],
    "repeat" => ~V[allowed:none,daily,weekly,biweekly,monthly],
    "place" => ~V[allowed:room,link],
    "room_id" => ~V[uuid],
    "url" => ~V[string|max:2000],
    "talk_mode" => ~V[allowed:stage,open]
  }

  def update(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id} = params

    with {:ok, event} <- find_event(id, auth),
         {:ok, event} <- Events.update_event(auth, event, changes(params)) do
      render_event(conn, event)
    end
  end

  operation :cancel,
    summary: "Call an event off or bring it back",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.CancelBody,
    responses: [
      ok: {Schema.CommunityEvent, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid], "cancelled" => ~V[required|boolean]}

  def cancel(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id, "cancelled" => cancelled} = params

    with {:ok, event} <- find_event(id, auth),
         {:ok, event} <- set_cancelled(auth, event, cancelled) do
      render_event(conn, event)
    end
  end

  operation :delete,
    summary: "Delete an event",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def delete(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, event} <- find_event(id, auth),
         {:ok, _event} <- Events.delete_event(auth, event) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :interest,
    summary: "Mark interest in an event or take it back",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      ok: {Schema.Toggle, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def interest(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, event} <- find_event(id, auth),
         {:ok, state} <- Events.toggle_interest(auth, event) do
      render(conn, :interest, on: state == :interested)
    end
  end

  defp community_ids(nil, nil), do: {:ok, []}
  defp community_ids(nil, auth), do: {:ok, IAM.community_ids(auth)}

  defp community_ids(community_id, auth) do
    with {:ok, community} <- find_community(community_id, auth), do: {:ok, [community.id]}
  end

  # Only the fields sent, so the rest stay as they were
  defp changes(params) do
    params
    |> Map.take(
      ~w[title description starts_at duration_min timezone repeat place room_id url talk_mode]
    )
    |> Common.atomize_string_keys()
  end

  defp set_cancelled(auth, event, true), do: Events.cancel_event(auth, event)
  defp set_cancelled(auth, event, false), do: Events.restore_event(auth, event)

  defp render_event(conn, event),
    do: render(conn, :show, event: event, interested: Events.interested_ids([event]))

  defp find_community(id, auth) do
    with {:ok, community} <- Communities.get_community(id: id, archived_at: nil),
         true <- Communities.readable?(community, auth) do
      {:ok, community}
    else
      false -> {:error, :not_found}
      error -> error
    end
  end

  defp find_event(id, auth) do
    with {:ok, event} <- Events.get_event(id: id),
         {:ok, _community} <- find_community(event.community_id, auth) do
      {:ok, event}
    end
  end
end
