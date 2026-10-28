defmodule Hearth.Notifications.CatchUp do
  use Hearth.Notifications.Message

  alias Hearth.Accounts.User
  alias Hearth.Notifications
  alias Hearth.Notifications.MailMessage
  alias Hearth.Notifications.Notices

  @fields [:period, :communities]
  @enforce_keys @fields
  defstruct @fields

  @type entry :: %{post: map(), author: nil | User.t()}

  @type t :: %__MODULE__{
          period: :daily | :weekly,
          communities: [%{community: map(), posts: [entry()], more: non_neg_integer()}]
        }

  @impl Hearth.Notifications.Message
  def via(%__MODULE__{}, %User{settings: %{digest: :off}}), do: []
  def via(%__MODULE__{}, %User{}), do: [:mail]

  @impl Hearth.Notifications.Message
  def to_mail(%__MODULE__{} = catch_up, _notifiable) do
    total = Enum.sum_by(catch_up.communities, &(length(&1.posts) + &1.more))

    catch_up.communities
    |> Enum.reduce(
      %MailMessage{}
      |> MailMessage.subject(subject(total, catch_up.communities))
      |> MailMessage.greeting(greeting(catch_up.period))
      |> MailMessage.preview(preview(catch_up.communities))
      |> MailMessage.line(
        "New posts in the communities you joined. The ones people found most useful come first."
      ),
      &MailMessage.section(&2, section(&1))
    )
    |> MailMessage.action("Open Catch up", Notifications.url("/"))
    |> MailMessage.link_line(
      "You get this #{schedule(catch_up.period)}. Change it or turn it off in ",
      "Settings",
      Notifications.url("/settings")
    )
  end

  defp subject(total, [%{community: community}]), do: "#{posts(total)} in #{community.name}"

  defp subject(total, [%{community: first}, %{community: second}]),
    do: "#{posts(total)} in #{first.name} and #{second.name}"

  defp subject(total, [%{community: community} | rest]),
    do: "#{posts(total)} in #{community.name} and #{length(rest)} other communities"

  defp posts(1), do: "1 new post"
  defp posts(count), do: "#{count} new posts"

  defp greeting(:daily), do: "What you missed today"
  defp greeting(:weekly), do: "What you missed this week"

  defp schedule(:daily), do: "every morning"
  defp schedule(:weekly), do: "on Monday mornings"

  defp preview(communities) do
    communities
    |> Enum.flat_map(& &1.posts)
    |> Enum.take(2)
    |> Enum.map_join(". ", & &1.post.title)
  end

  defp section(%{community: community, posts: posts, more: more}) do
    url = Notifications.url("/c/#{community.slug}")

    %{
      heading: community.name,
      url: url,
      items:
        Enum.map(posts, fn %{post: post, author: author} ->
          %{
            title: post.title,
            url: Notifications.url(Notices.post_url(community, post)),
            meta: meta(post, author)
          }
        end),
      more: if(more > 0, do: {"#{more} more in #{community.name}", url})
    }
  end

  defp meta(post, author) do
    [
      if(post.pinned_at, do: "Pinned"),
      if(author, do: author.display_name || author.username),
      count(post.reply_count, "reply", "replies"),
      count(post.helpful_count, "helpful", "helpful")
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  defp count(0, _one, _many), do: nil
  defp count(1, one, _many), do: "1 #{one}"
  defp count(n, _one, many), do: "#{n} #{many}"
end
