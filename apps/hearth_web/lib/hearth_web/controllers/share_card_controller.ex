defmodule HearthWeb.ShareCardController do
  use HearthWeb, :controller

  alias Hearth.Accounts
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Events
  alias Hearth.Forum
  alias Hearth.IAM
  alias Hearth.Instance
  alias Hearth.Media
  alias HearthWeb.PublicProfile

  def community(conn, %{"slug" => slug}), do: respond(conn, community_card(slug))
  def post(conn, %{"id" => segment}), do: respond(conn, post_card(segment))
  def event(conn, %{"id" => segment}), do: respond(conn, event_card(segment))
  def user(conn, %{"username" => username}), do: respond(conn, user_card(username))

  defp community_card(slug) do
    with {:ok, community} <- public_community(slug: slug) do
      images = Media.get_images([community.logo_id, community.banner_id])

      {:ok,
       %{
         eyebrow: "Community",
         title: community.name,
         footer:
           [community.tagline, members(community)] |> Enum.reject(&is_nil/1) |> Enum.join("  ·  "),
         logo: images[community.logo_id],
         banner: images[community.banner_id]
       }}
    end
  end

  defp post_card(segment) do
    with {:ok, id} <- Common.id_from_segment(segment),
         {:ok, post} <- Forum.get_post(id: id, status: :published, deleted_at: nil),
         {:ok, community} <- public_community(id: post.community_id) do
      kind = community.id |> Forum.list_kinds() |> Enum.find(&(&1.id == post.kind_id))
      images = Media.get_images([community.logo_id, community.banner_id])

      {:ok,
       %{
         heading: community.name,
         subheading: community.tagline,
         eyebrow: eyebrow(kind, post),
         title: post.title,
         footer: Enum.join([author(post.author_id) | counts(post)], "  ·  "),
         logo: images[community.logo_id],
         banner: images[community.banner_id]
       }}
    end
  end

  defp event_card(segment) do
    with {:ok, id} <- Common.id_from_segment(segment),
         {:ok, event} <- Events.get_event(id: id),
         {:ok, community} <- public_community(id: event.community_id) do
      images = Media.get_images([community.logo_id, community.banner_id])

      {:ok,
       %{
         heading: community.name,
         subheading: community.tagline,
         eyebrow: if(event.cancelled_at, do: "Event · Cancelled", else: "Event"),
         title: event.title,
         footer: when_text(event),
         logo: images[community.logo_id],
         banner: images[community.banner_id]
       }}
    end
  end

  defp user_card(username) do
    with {:ok, user} <- Accounts.get_user(username: username) do
      user = PublicProfile.apply(user, nil)
      images = Media.get_images([user.avatar_id])

      {:ok,
       %{
         eyebrow: "@" <> user.username,
         title: user.display_name || "@" <> user.username,
         footer: if(user.bio, do: Common.plain_text(user.bio)),
         logo: images[user.avatar_id]
       }}
    end
  end

  defp respond(conn, {:ok, %{} = card}) do
    card = Map.put(card, :brand, Instance.settings().name)

    case Media.share_card_url(card) do
      {:ok, url} ->
        conn
        |> put_resp_header("cache-control", "public, max-age=600")
        |> redirect(external: url)

      {:error, _reason} ->
        send_resp(conn, :service_unavailable, "")
    end
  end

  defp respond(conn, _hidden), do: send_resp(conn, :not_found, "")

  defp public_community(opts) do
    with {:ok, community} <- Communities.get_community(opts),
         true <- Communities.readable?(community, nil) do
      {:ok, community}
    else
      _hidden -> {:error, :not_found}
    end
  end

  defp members(community) do
    case IAM.member_count(community.id) do
      1 -> "1 member"
      count -> "#{count} members"
    end
  end

  defp eyebrow(nil, _post), do: nil
  defp eyebrow(kind, %{answer_reply_id: nil}), do: kind.label
  defp eyebrow(kind, _answered), do: kind.label <> " · Answered"

  defp author(author_id) do
    case Accounts.get_user(id: author_id) do
      {:ok, user} -> PublicProfile.apply(user, nil).display_name || "@" <> user.username
      {:error, :not_found} -> "Someone"
    end
  end

  defp counts(post) do
    Enum.reject(
      [
        count(post.reply_count, "reply", "replies"),
        count(post.helpful_count, "helpful", "helpful")
      ],
      &is_nil/1
    )
  end

  defp count(0, _one, _many), do: nil
  defp count(1, one, _many), do: "1 " <> one
  defp count(n, _one, many), do: "#{n} " <> many

  # In the event's own time zone, as people attending it read it.
  defp when_text(event) do
    starts_at =
      case DateTime.shift_zone(event.starts_at, event.timezone) do
        {:ok, local} -> local
        {:error, _zone} -> event.starts_at
      end

    Calendar.strftime(starts_at, "%a %-d %b %Y, %H:%M ") <> starts_at.zone_abbr
  end
end
