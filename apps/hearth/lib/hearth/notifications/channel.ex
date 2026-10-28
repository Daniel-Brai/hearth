defmodule Hearth.Notifications.Channel do
  @callback name() :: atom()
  @callback send(message :: struct(), notifiable :: struct()) :: :ok | {:error, term()}
end
