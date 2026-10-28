defmodule HearthWeb.ReportControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.TestUtils

  setup do
    community = TestUtils.create_random_forum!(nil, moderation: :reports)
    author = TestUtils.join_random_member!(community)
    reporter = TestUtils.join_random_member!(community)
    post = TestUtils.create_random_post!(author, community)

    {:ok, binding()}
  end

  describe "create" do
    test "fails signed out", %{conn: conn, post: post} do
      body = %{subject_type: "post", subject_id: post.id, reason: "spam"}

      assert conn |> post(~p"/api/reports", body) |> valid_response(401)
    end

    test "fails for a reason not on the list", %{conn: conn, reporter: reporter, post: post} do
      body = %{subject_type: "post", subject_id: post.id, reason: "boring"}

      assert %{"errors" => errors} =
               conn |> auth_conn(reporter) |> post(~p"/api/reports", body) |> valid_response(422)

      assert [_message] = errors["reason"]
    end

    test "fails where reports are off", %{conn: conn} do
      community = TestUtils.create_random_forum!()
      author = TestUtils.join_random_member!(community)
      reporter = TestUtils.join_random_member!(community)
      post = TestUtils.create_random_post!(author, community)
      body = %{subject_type: "post", subject_id: post.id, reason: "spam"}

      assert %{"code" => "reports_off"} =
               conn |> auth_conn(reporter) |> post(~p"/api/reports", body) |> valid_response(400)
    end

    test "fails for your own content", %{conn: conn, author: author, post: post} do
      body = %{subject_type: "post", subject_id: post.id, reason: "spam"}

      assert %{"code" => "own"} =
               conn |> auth_conn(author) |> post(~p"/api/reports", body) |> valid_response(400)
    end

    test "queues the report", %{conn: conn, reporter: reporter, post: post} do
      body = %{
        subject_type: "post",
        subject_id: post.id,
        reason: "spam",
        note: Lorem.sentence()
      }

      assert %{"queued" => true} =
               conn |> auth_conn(reporter) |> post(~p"/api/reports", body) |> valid_response(201)
    end
  end
end
