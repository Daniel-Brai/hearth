defmodule HearthWeb.TranscriptController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Communities
  alias Hearth.Transcripts
  alias HearthWeb.Authors
  alias Plug.Conn

  tags ["Voice"]

  @id [in: :path, schema: %{type: :string, format: :uuid}]

  operation :show,
    summary: "Show a voice session's transcript",
    description: "For members of the community while transcription is on",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      ok: {Schema.Transcript, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def show(%Conn{assigns: %{auth: auth}} = conn, %{"id" => id}) do
    with {:ok, view} <- Transcripts.get_for_session(auth, id),
         {:ok, room} <- Communities.view_room(auth, id: view.session.room_id) do
      people = view.transcript.speakers |> Enum.map(& &1.user_id) |> Authors.people()

      render(conn, :show,
        view: view,
        room: room,
        people: people,
        editable: Transcripts.editable_speaker_ids(auth, view.transcript)
      )
    end
  end

  operation :update_segment,
    summary: "Fix a line of a transcript",
    description: "The person who said it can, and so can anyone with content.remove",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.EditSegmentBody,
    responses: [
      ok: {Schema.TranscriptSegment, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid], "text" => ~V[required|string|max:5000]}

  def update_segment(%Conn{assigns: %{auth: auth}} = conn, %{"id" => id, "text" => text}) do
    with {:ok, segment} <- Transcripts.edit_segment(auth, id, %{text: text}) do
      render(conn, :update_segment, segment: segment)
    end
  end
end
