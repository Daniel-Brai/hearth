defmodule HearthWeb.UploadController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Common
  alias Hearth.Media
  alias Plug.Conn

  tags ["Uploads"]

  @id [in: :path, schema: %{type: :string, format: :uuid}]

  operation :create,
    summary: "Start an upload",
    description: "Answers with one signed PUT or a multipart upload for big files",
    security: [%{"bearer" => []}],
    parameters: [
      "idempotency-key": [
        in: :header,
        required: true,
        schema: %{type: :string, minLength: 8, maxLength: 128},
        description: "A key the client makes for this file, such as a UUID."
      ]
    ],
    request_body: Schema.RequestUploadBody,
    responses: [
      created: {Schema.Upload, description: "Created"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      too_many_requests: %Reference{"$ref": "#/components/responses/too_many_requests"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "name" => ~V[required|string|min:1|max:255],
    "content_type" => ~V[required|string|min:1|max:255],
    "byte_size" => ~V[required|integer|min:1],
    "sha256" => ~V[required|string|size:64],
    "purpose" => ~V[allowed:attachment,avatar,logo],
    "duration_ms" => ~V[integer|min:1]
  }

  def create(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn

    attrs =
      params
      |> Map.take(~w[name content_type byte_size sha256 purpose duration_ms])
      |> Common.atomize_string_keys()
      |> Map.put(:idempotency_key, header_param(conn, :"idempotency-key"))

    with {:ok, %{media: media, upload: upload}} <- Media.request_upload(auth, attrs) do
      conn
      |> put_status(:created)
      |> render(:create, media: media, upload: upload)
    end
  end

  operation :parts,
    parameters: [id: @id],
    summary: "List the parts already uploaded",
    description: "A resumed upload sends only the missing parts",
    security: [%{"bearer" => []}],
    responses: [
      ok: {Schema.Parts, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def parts(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, media} <- Media.fetch_own_media(auth, id),
         {:ok, parts} <- Media.list_parts(auth, media) do
      render(conn, :parts, parts: parts)
    end
  end

  operation :part_urls,
    parameters: [id: @id],
    summary: "Sign part URLs",
    description: "Each URL takes one PUT and works for 10 minutes",
    security: [%{"bearer" => []}],
    request_body: Schema.PartUrlsBody,
    responses: [
      ok: {Schema.PartUrls, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "numbers" => ~V[required|list|min:1|max:100],
    "numbers.*" => ~V[required|integer|between:1,10000]
  }

  def part_urls(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id, "numbers" => numbers} = params

    with {:ok, media} <- Media.fetch_own_media(auth, id),
         {:ok, urls} <- Media.part_urls(auth, media, numbers) do
      render(conn, :part_urls, urls: urls)
    end
  end

  operation :complete,
    parameters: [id: @id],
    summary: "Finish an upload",
    description: "A file that fails the checks is deleted",
    security: [%{"bearer" => []}],
    request_body: Schema.CompleteUploadBody,
    responses: [
      ok: {Schema.Media, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "parts" => ~V[list|max:10000],
    "parts.*.number" => ~V[required|integer|between:1,10000],
    "parts.*.etag" => ~V[required|string|min:1|max:128]
  }

  def complete(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id} = params

    parts = Enum.map(params["parts"] || [], &{&1["number"], &1["etag"]})

    with {:ok, media} <- Media.fetch_own_media(auth, id),
         {:ok, media} <- Media.complete_upload(auth, media, parts) do
      render(conn, :complete, media: media)
    end
  end
end
