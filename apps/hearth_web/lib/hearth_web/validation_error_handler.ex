defmodule HearthWeb.ValidationErrorHandler do
  @behaviour Oaskit.ErrorHandler

  alias HearthWeb.ErrorResponse
  alias Oaskit.Errors.InvalidBodyError
  alias Oaskit.Errors.UnsupportedMediaTypeError

  @impl Oaskit.ErrorHandler
  def handle_error(conn, %UnsupportedMediaTypeError{}, _opts) do
    ErrorResponse.halt(conn, :unsupported_media_type, :unsupported_media_type)
  end

  # Each action's @validate rules check the request and say what is wrong with it
  def handle_error(conn, %InvalidBodyError{}, _opts), do: conn
  def handle_error(conn, {:parameters_errors, _errors}, _opts), do: conn
end
