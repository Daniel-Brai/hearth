defmodule HearthWeb do
  use Boundary, deps: [Hearth], exports: []

  def static_paths, do: ~w(assets fonts images favicon.ico)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: HearthWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def api_controller do
    quote do
      use Phoenix.Controller, formats: [:json]

      use Oaskit.Controller

      import Plug.Conn
      import HearthWeb.Plugs.RateLimit, only: [rate_limit: 2]

      alias HearthWeb.Schema
      alias Oaskit.Spec.Reference

      # Validates and casts each request against its operation, and enforces
      # the operation's security, before the action runs.
      plug Oaskit.Plugs.ValidateRequest,
        security: HearthWeb.Plugs.Security,
        error_handler: HearthWeb.ValidationErrorHandler

      action_fallback HearthWeb.FallbackController

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      use Gettext, backend: HearthWeb.Gettext

      import Phoenix.HTML
      import HearthWeb.CoreComponents

      alias HearthWeb.Layouts
      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: HearthWeb.Endpoint,
        router: HearthWeb.Router,
        statics: HearthWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
