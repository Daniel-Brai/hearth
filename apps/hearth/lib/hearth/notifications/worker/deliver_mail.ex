defmodule Hearth.Notifications.Worker.DeliverMail do
  use Oban.Worker, queue: :mail, max_attempts: 10

  alias Hearth.Common
  alias Hearth.Notifications
  alias Hearth.Notifications.Delivery
  alias Hearth.Notifications.Mailer
  alias Hearth.Notifications.SealedArgs
  alias Swoosh.Email

  # Only user_id and template stay readable in the job, the rest is sealed
  @spec enqueue(map(), keyword()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(%{to: [_name, _email]} = mail, opts \\ []) do
    {readable, secret} = Map.split(mail, [:user_id, :template])

    readable
    |> Map.put(:sealed, SealedArgs.seal(secret))
    |> new(opts)
    |> Oban.insert()
  end

  @spec mail(Oban.Job.t() | map()) :: map()
  def mail(%Oban.Job{args: args}), do: mail(args)
  def mail(%{"sealed" => sealed} = args), do: Map.merge(args, SealedArgs.open!(sealed))

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    args = mail(args)
    %{"to" => [name, address], "subject" => subject, "html" => html, "text" => text} = args

    email =
      Email.new(
        from: Notifications.sender(),
        to: {name, address},
        subject: subject,
        html_body: html,
        text_body: text
      )

    result = Common.span("mail.deliver", %{}, fn -> Mailer.deliver(email) end)
    record(args, result)

    case result do
      {:ok, _meta} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp record(args, result) do
    outcome =
      case result do
        {:ok, meta} -> %{status: :sent, provider_message_id: provider_id(meta)}
        {:error, reason} -> %{status: :failed, error: inspect(reason)}
      end

    params =
      Map.merge(outcome, %{
        user_id: args["user_id"],
        template: args["template"],
        to: List.last(args["to"])
      })

    Delivery.insert(%Delivery{}, params)
  end

  defp provider_id(%{id: id}) when is_binary(id), do: id
  defp provider_id(_meta), do: nil
end
