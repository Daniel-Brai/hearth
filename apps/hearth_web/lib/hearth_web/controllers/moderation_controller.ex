defmodule HearthWeb.ModerationController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Moderation
  alias HearthWeb.Attachments
  alias HearthWeb.Authors
  alias HearthWeb.Paging
  alias Plug.Conn

  tags ["Moderation"]

  @id [in: :path, schema: %{type: :string, format: :uuid}]
  @community_id [in: :path, schema: %{type: :string, format: :uuid}]
  @status [in: :query, schema: %{type: :string, enum: ~w[pending kept removed dismissed]}]

  @decided [
    ok: {Schema.QueueItem, description: "OK"},
    bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
    unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
    forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
    not_found: %Reference{"$ref": "#/components/responses/not_found"},
    unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
  ]

  operation :queue,
    summary: "List a community's moderation queue",
    description: "Needs content.remove in the community",
    security: [%{"bearer" => []}],
    parameters: [community_id: @community_id, status: @status] ++ Schema.paging(),
    responses: [
      ok: {Schema.page(Schema.QueueItem), description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "status" => ~V[allowed:pending,kept,removed,dismissed],
    "limit" => ~V[between:1,50],
    "after" => ~V[string],
    "before" => ~V[string]
  }

  def queue(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"community_id" => community_id} = params

    opts = [status: Common.to_atom(params["status"] || "pending")] ++ Paging.opts(conn)

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, page} <- Moderation.list_queue(auth, community, opts) do
      render(conn, :queue, [page: page] ++ details(page.data))
    end
  end

  operation :instance_queue,
    summary: "List reported direct messages",
    description: "For instance admins",
    security: [%{"bearer" => []}],
    parameters: [status: @status] ++ Schema.paging(),
    responses: [
      ok: {Schema.page(Schema.QueueItem), description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "status" => ~V[allowed:pending,kept,removed,dismissed],
    "limit" => ~V[between:1,50],
    "after" => ~V[string],
    "before" => ~V[string]
  }

  def instance_queue(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn

    opts = [status: Common.to_atom(params["status"] || "pending")] ++ Paging.opts(conn)

    with {:ok, page} <- Moderation.list_instance_queue(auth, opts) do
      render(conn, :queue, [page: page] ++ details(page.data))
    end
  end

  operation :screening_summary,
    summary: "Show what screening did each day",
    description: "For instance admins tuning the threshold",
    security: [%{"bearer" => []}],
    parameters: [days: [in: :query, schema: %{type: :integer, minimum: 1, maximum: 365}]],
    responses: [
      ok: {Schema.ScreeningSummary, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"days" => ~V[between:1,365]}

  def screening_summary(%Conn{assigns: %{auth: %{}}} = conn, _params) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, summary} <- Moderation.screening_summary(auth, query_param(conn, :days) || 30) do
      render(conn, :screening_summary, summary: summary)
    end
  end

  operation :counts,
    summary: "Count what waits in each queue I work",
    security: [%{"bearer" => []}],
    responses: [
      ok: {Schema.QueueCounts, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
    ]

  def counts(%Conn{assigns: %{auth: %{}}} = conn, _params) do
    %Conn{assigns: %{auth: auth}} = conn

    render(conn, :counts, counts: Moderation.queue_counts(auth))
  end

  operation :keep,
    summary: "Keep a queue item's content up",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.ReasonBody,
    responses: @decided

  @validate %{
    "id" => ~V[required|uuid],
    "reason" => ~V[string|max:500]
  }

  def keep(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id} = params

    with {:ok, item} <- Moderation.get_item(id),
         {:ok, item} <- Moderation.keep(auth, item, params["reason"]) do
      render(conn, :show, [item: item] ++ details([item]))
    end
  end

  operation :remove,
    summary: "Remove a queue item's content",
    description: "The reason shows in the public log",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.RemoveBody,
    responses: @decided

  @validate %{
    "id" => ~V[required|uuid],
    "reason" => ~V[required|string|min:1|max:500]
  }

  def remove(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id, "reason" => reason} = params

    with {:ok, item} <- Moderation.get_item(id),
         {:ok, item} <- Moderation.remove(auth, item, reason) do
      render(conn, :show, [item: item] ++ details([item]))
    end
  end

  operation :undo,
    summary: "Reopen a decided queue item",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: @decided

  @validate %{"id" => ~V[required|uuid]}

  def undo(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, item} <- Moderation.get_item(id),
         {:ok, item} <- Moderation.undo(auth, item) do
      render(conn, :show, [item: item] ++ details([item]))
    end
  end

  operation :ban_author,
    summary: "Remove a queue item's content and ban its author",
    description: "Needs content.remove and member.ban",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.BanAuthorBody,
    responses: [
      created: {Schema.Ban, description: "Created"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "reason" => ~V[required|string|min:1|max:500],
    "expires_at" => ~V[string]
  }

  def ban_author(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id} = params

    changes = params |> Map.take(~w[reason expires_at]) |> Common.atomize_string_keys()

    with {:ok, item} <- Moderation.get_item(id),
         {:ok, ban} <- Moderation.ban_author(auth, item, changes) do
      conn
      |> put_status(:created)
      |> put_view(json: HearthWeb.BanJSON)
      |> render(:show, ban: ban, people: Authors.people([ban.user_id, ban.banned_by_id]))
    end
  end

  operation :remove_content,
    summary: "Remove a post, reply or message",
    description: "Needs content.remove in its community, or instance admin for a direct message",
    security: [%{"bearer" => []}],
    request_body: Schema.ModerateContentBody,
    responses: [
      ok: {Schema.ModeratedContent, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "subject_type" => ~V[required|allowed:post,reply,message],
    "subject_id" => ~V[required|uuid],
    "reason" => ~V[required|string|min:1|max:500]
  }

  def remove_content(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"subject_type" => type, "subject_id" => id, "reason" => reason} = params

    with {:ok, subject} <- Moderation.remove_content(auth, Common.to_atom(type), id, reason) do
      render(conn, :content, subject: subject)
    end
  end

  operation :restore_content,
    summary: "Put removed content back up",
    security: [%{"bearer" => []}],
    request_body: Schema.ModerateContentBody,
    responses: [
      ok: {Schema.ModeratedContent, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "subject_type" => ~V[required|allowed:post,reply,message],
    "subject_id" => ~V[required|uuid],
    "reason" => ~V[string|max:500]
  }

  def restore_content(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"subject_type" => type, "subject_id" => id} = params

    with {:ok, subject} <- Moderation.restore_content(auth, Common.to_atom(type), id) do
      render(conn, :content, subject: subject)
    end
  end

  operation :community_level,
    summary: "Set a community's moderation level",
    description: "Needs community.update",
    security: [%{"bearer" => []}],
    parameters: [community_id: @community_id],
    request_body: Schema.LevelBody,
    responses: [
      ok: {Schema.ModerationLevel, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "level" => ~V[required|allowed:full,reports,none]
  }

  def community_level(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"community_id" => id, "level" => level} = params

    with {:ok, community} <- Communities.get_community(id: id, archived_at: nil),
         {:ok, community} <- Moderation.set_level(auth, community, Common.to_atom(level)) do
      render(conn, :level, level: community.moderation, effective: community.moderation)
    end
  end

  operation :room_level,
    summary: "Set a room's moderation level",
    description:
      "Needs room.update. A room can only go lower than its community and null follows it",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.LevelBody,
    responses: [
      ok: {Schema.ModerationLevel, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "level" => ~V[allowed:full,reports,none]
  }

  def room_level(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id} = params

    with {:ok, room} <- Communities.view_room(auth, id: id),
         {:ok, room} <- Moderation.set_level(auth, room, Common.to_atom(params["level"])),
         {:ok, community} <- Communities.get_community(id: room.community_id) do
      render(conn, :level, level: room.moderation, effective: Moderation.level(community, room))
    end
  end

  operation :log,
    summary: "List a community's public moderation log",
    parameters: [community_id: @community_id] ++ Schema.paging(),
    responses: [
      ok: {Schema.page(Schema.ModerationAction), description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "limit" => ~V[between:1,50],
    "after" => ~V[string],
    "before" => ~V[string]
  }

  def log(%Conn{assigns: %{auth: auth}} = conn, %{"community_id" => id}) do
    with {:ok, community} <- Communities.get_community(id: id, archived_at: nil),
         true <- Communities.readable?(community, auth),
         %{data: actions} = page <- Moderation.list_log(community, Paging.opts(conn)) do
      people = actions |> Enum.flat_map(&[&1.actor_id, &1.target_id]) |> Authors.people()

      render(conn, :log, page: page, people: people)
    else
      false -> {:error, :not_found}
      error -> error
    end
  end

  defp details(items) do
    subjects = Moderation.subjects(items)
    contents = Map.values(subjects)

    ids =
      Enum.flat_map(items, &[&1.author_id, &1.reviewed_by_id]) ++
        Enum.map(contents, & &1.author_id)

    attachments =
      contents
      |> Enum.group_by(& &1.type, & &1.content)
      |> Enum.reduce(%{}, fn {type, list}, acc -> Map.merge(acc, Attachments.load(list, type)) end)

    [
      subjects: subjects,
      reports: Moderation.reports(items),
      people: Authors.people(ids),
      attachments: attachments
    ]
  end
end
