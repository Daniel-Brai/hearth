defmodule Hearth.PubSub.WebsocketEvent do
  # broadcast_as defaults to the module's last name, and broadcast_with to every field so override it to send less

  defstruct ~w[name channels data]a

  @type t :: %__MODULE__{
          name: String.t(),
          channels: [String.t()],
          data: term()
        }

  @callback broadcast_as(struct()) :: String.t()
  @callback broadcast_on(struct()) :: String.t() | [String.t()]
  @callback broadcast_with(struct()) :: map()

  defmacro __using__(_opts) do
    quote do
      @behaviour Hearth.PubSub.WebsocketEvent
      @before_compile Hearth.PubSub.WebsocketEvent
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      if not Module.defines?(__MODULE__, {:broadcast_as, 1}) do
        @impl Hearth.PubSub.WebsocketEvent
        def broadcast_as(%__MODULE__{} = _event) do
          __MODULE__
          |> Module.split()
          |> List.last()
        end
      end

      if not Module.defines?(__MODULE__, {:broadcast_with, 1}) do
        @impl Hearth.PubSub.WebsocketEvent
        def broadcast_with(%__MODULE__{} = event), do: Map.from_struct(event)
      end
    end
  end
end
