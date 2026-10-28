defmodule Hearth.Notifications do
  default = [Anonymous, MailMessage, Message, Notification, NotificationCreated, WebPushMessage]

  exports =
    case Mix.env() do
      :test -> default ++ [Delivery, PushSubscription, Worker.DeliverMail]
      _env -> default
    end

  use Boundary,
    deps: [
      Hearth.Accounts,
      Hearth.Auth,
      Hearth.Common,
      Hearth.Chat,
      Hearth.Communities,
      Hearth.Events,
      Hearth.Forum,
      Hearth.IAM,
      Hearth.Moderation,
      Hearth.PubSub,
      Hearth.Repo,
      Hearth.Transcripts,
      Hearth.Vault,
      Hearth.Voice
    ],
    exports: exports

  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.Notifications.Channel.InApp
  alias Hearth.Notifications.Channel.Mail
  alias Hearth.Notifications.Channel.WebPush, as: WebPushChannel
  alias Hearth.Notifications.Message
  alias Hearth.Notifications.Notification
  alias Hearth.Notifications.PushSubscription
  alias Hearth.Notifications.WebPush
  alias Hearth.PubSub
  alias Hearth.Repo.Page

  @otp_app :hearth
  @topic "notifications"
  # Badges show 99+ past this so counting further is wasted
  @most_unread 100
  @prune_batch 5_000

  @spec subscribe_to_pubsub() :: :ok | {:error, term()}
  def subscribe_to_pubsub, do: PubSub.subscribe(@topic)

  @doc false
  @spec broadcast_to_pubsub(struct()) :: :ok | {:error, term()}
  def broadcast_to_pubsub(event), do: PubSub.broadcast(@topic, event)

  @spec send(struct(), struct()) :: :ok | :error
  def send(%_{} = notifiable, %module{} = message) do
    case Common.implements?(message, Message) do
      true ->
        message
        |> module.via(notifiable)
        |> Enum.each(&channel(&1).send(message, notifiable))

      false ->
        :error
    end
  end

  @spec list_notifications(User.t(), keyword()) :: Page.t() | {:error, Flop.Meta.t()}
  def list_notifications(%User{id: id}, paging \\ []) when is_list(paging) do
    paging
    |> Keyword.put(:user_id, id)
    |> Notification.paginate()
  end

  @spec unread_count(User.t()) :: non_neg_integer()
  def unread_count(%User{id: id}), do: Notification.unread_count(id, @most_unread)

  # Deleted in batches so the table is never locked for long
  @spec prune_read(DateTime.t()) :: non_neg_integer()
  def prune_read(%DateTime{} = before), do: prune_read(before, 0)

  defp prune_read(before, total) do
    case Notification.prune_read(before, @prune_batch) do
      @prune_batch -> prune_read(before, total + @prune_batch)
      count -> total + count
    end
  end

  @spec mark_read(User.t(), T.id()) :: :ok
  def mark_read(%User{id: user_id}, id) when is_binary(id) do
    _count = Notification.mark_read(user_id, id)

    :ok
  end

  @spec mark_all_read(User.t()) :: :ok
  def mark_all_read(%User{id: user_id}) do
    _count = Notification.mark_read(user_id, nil)

    :ok
  end

  @spec push_enabled?() :: boolean()
  def push_enabled?, do: WebPush.enabled?()

  @spec vapid_public_key() :: nil | String.t()
  def vapid_public_key do
    case WebPush.vapid_keys() do
      %{public: public} -> public
      nil -> nil
    end
  end

  # Saving an endpoint again moves it to the new user since the device may have changed hands
  @spec link_push_sub(User.t(), map()) :: {:ok, PushSubscription.t()} | {:error, Changeset.t()}
  def link_push_sub(%User{id: id}, %{} = params) do
    params
    |> Map.put(:user_id, id)
    |> PushSubscription.link()
  end

  @spec unlink_push_sub(User.t(), String.t()) :: :ok
  def unlink_push_sub(%User{id: id}, endpoint) when is_binary(endpoint) do
    with %PushSubscription{} = subscription <-
           PushSubscription.get(user_id: id, endpoint: endpoint) do
      PushSubscription.delete(subscription)
    end

    :ok
  end

  @spec brand() :: String.t()
  def brand, do: Application.get_env(@otp_app, :instance_name, "Hearth")

  @spec brand_icon() :: String.t()
  def brand_icon do
    case Application.get_env(@otp_app, :instance_icon) do
      blank when blank in [nil, ""] -> url("/icon-192.png")
      "/" <> _rest = path -> url(path)
      icon -> icon
    end
  end

  @spec url(String.t()) :: String.t()
  def url("/" <> _rest = path) do
    @otp_app
    |> Application.fetch_env!(:public_url)
    |> String.trim_trailing("/")
    |> Kernel.<>(path)
  end

  @spec sender() :: {String.t(), String.t()}
  def sender do
    config = Application.fetch_env!(@otp_app, __MODULE__)

    {config[:from_name] || brand(), Keyword.fetch!(config, :from)}
  end

  @doc false
  def title(module),
    do: module |> template_name() |> String.replace("_", " ") |> String.capitalize()

  @doc false
  def template_name(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  for mod <- [Mail, WebPushChannel, InApp], name = mod.name() do
    defp channel(unquote(name)), do: unquote(mod)
  end
end
