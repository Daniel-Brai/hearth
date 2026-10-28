defmodule HearthWeb.OpenAPISpec do
  use Oaskit

  alias HearthWeb.Plugs.ApiVersion
  alias HearthWeb.RefreshCookie
  alias HearthWeb.Schema
  alias Oaskit.Spec.Components
  alias Oaskit.Spec.Contact
  alias Oaskit.Spec.Header
  alias Oaskit.Spec.Info
  alias Oaskit.Spec.License
  alias Oaskit.Spec.MediaType
  alias Oaskit.Spec.OpenAPI
  alias Oaskit.Spec.Paths
  alias Oaskit.Spec.Response
  alias Oaskit.Spec.SecurityScheme
  alias Oaskit.Spec.Server
  alias Oaskit.Spec.Tag

  @source_url Mix.Project.config()[:source_url]

  @description """
  The API for a Hearth community instance.

  **Versions.** Send the date your client was built against in
  `Hearth-Version`. Without it, the oldest supported version answers; the
  response says which version answered in the same header.

  **Signing in.** Signing in returns a 15 minute access token to send as
  `Authorization: Bearer <token>`, and sets an HttpOnly refresh cookie for
  `/api/auth`. `POST /api/auth/refresh` swaps the cookie for a new access
  token and a new cookie; each refresh cookie works once.

  **Errors.** Every error has a `message`, usually a `code` to act on, and
  for 422 the failing fields under `errors`.
  """

  @impl Oaskit
  def spec do
    %OpenAPI{
      # Swagger UI doesn't know the dialect id 3.1.1 introduced
      openapi: "3.1.0",
      jsonSchemaDialect: "https://spec.openapis.org/oas/3.1/dialect/base",
      info: %Info{
        title: "Hearth",
        version: ApiVersion.latest(),
        description: @description,
        contact: %Contact{name: "Hearth", url: @source_url},
        license: %License{name: "MIT", identifier: "MIT"}
      },
      # Relative so the docs try requests against the server that serves them
      servers: [%Server{url: "/"}],
      paths: Paths.from_router(HearthWeb.Router, filter: &documented?/1),
      tags: [
        %Tag{name: "Instance", description: "What this instance has set up."},
        %Tag{name: "Auth", description: "Signing in and out."},
        %Tag{name: "Uploads", description: "Sending files straight to storage."},
        %Tag{name: "Media", description: "Uploaded files."},
        %Tag{name: "Communities", description: "Communities, their rooms and invites."},
        %Tag{name: "Forum", description: "Posts and their replies."},
        %Tag{name: "Chat", description: "Messages in rooms and conversations."},
        %Tag{name: "Voice", description: "Live voice sessions in voice rooms."}
      ],
      components: %Components{
        schemas: Schema.Event.components(),
        securitySchemes: %{
          "bearer" => %SecurityScheme{type: "http", scheme: "bearer", bearerFormat: "JWT"},
          "refresh_cookie" => %SecurityScheme{
            type: "apiKey",
            in: "cookie",
            name: RefreshCookie.name()
          }
        },
        responses: %{
          "bad_request" => response("Bad Request", Schema.Message),
          "forbidden" => response("Forbidden", Schema.Message),
          "not_found" => response("Not Found", Schema.Message),
          "unauthorized" => response("Unauthorized", Schema.Message),
          "unprocessable_content" => response("Unprocessable Content", Schema.Errors),
          "no_content" => %Response{description: "No Content"},
          "too_many_requests" => %Response{
            description: "Too Many Requests",
            headers: %{
              "retry-after" => %Header{
                description: "Seconds to wait before trying again.",
                schema: %{type: :integer}
              }
            },
            content: %{"application/json" => %MediaType{schema: Schema.Message}}
          }
        }
      }
    }
  end

  # Keyed to the loaded code so a changed operation shows without a restart
  if Mix.env() == :dev do
    @impl Oaskit
    def cache_variant do
      plugs = HearthWeb.Router |> Phoenix.Router.routes() |> Enum.map(& &1.plug) |> Enum.uniq()
      {:ok, modules} = :application.get_key(:hearth_web, :modules)

      schemas =
        Enum.filter(modules, &String.starts_with?(Atom.to_string(&1), "Elixir.HearthWeb.Schema."))

      [__MODULE__, HearthWeb.Router | plugs ++ schemas]
      |> Enum.map(& &1.module_info(:md5))
      |> :erlang.md5()
    end
  end

  # Provider sign in is browser redirects, not a JSON operation
  defp documented?(%{path: "/api/auth/oauth/" <> _rest}), do: false

  defp documented?(route) do
    String.starts_with?(route.path, "/api/")
  end

  defp response(description, schema) do
    %Response{
      description: description,
      content: %{"application/json" => %MediaType{schema: schema}}
    }
  end
end
