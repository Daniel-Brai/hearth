defmodule Hearth.InstanceTest do
  use Hearth.DataCase, async: false

  import Req.Test

  alias Hearth.Instance
  alias Hearth.Instance.GitHubError
  alias Hearth.Instance.Releases
  alias Hearth.TestUtils
  alias Plug.Conn

  @latest "/repos/daniel-brai/hearth/releases/latest"

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  describe "readiness/0" do
    test "is ready once the database answers" do
      assert {:ok, %{database: :ok}} = Instance.readiness()
    end
  end

  describe "update_status/0" do
    test "returns running version before check" do
      assert %{current_version: "0.1.0", latest_version: nil, update_available: false} =
               Instance.update_status()
    end
  end

  describe "check_for_update/0" do
    test "fails when update checks are off" do
      :ok = TestUtils.merge_env(Releases, enabled: false)

      assert {:error, :disabled} = Instance.check_for_update()
    end

    test "fails when GitHub doesn't answer" do
      stub(Releases, fn %Conn{method: "GET", request_path: @latest} = conn ->
        Conn.send_resp(conn, 500, "")
      end)

      assert {:error, %GitHubError{status: 500}} = Instance.check_for_update()
    end

    test "finds nothing new before the first release" do
      stub(Releases, fn %Conn{method: "GET", request_path: @latest} = conn ->
        Conn.send_resp(conn, 404, "")
      end)

      assert {:ok, %{latest_version: nil, update_available: false, checked_at: %DateTime{}}} =
               Instance.check_for_update()
    end

    test "finds nothing if up to date" do
      stub(Releases, fn %Conn{method: "GET", request_path: @latest} = conn ->
        json(conn, TestUtils.random_github_release("v0.1.0"))
      end)

      assert {:ok, %{latest_version: "0.1.0", update_available: false}} =
               Instance.check_for_update()
    end

    test "finds a newer release" do
      stub(Releases, fn %Conn{method: "GET", request_path: @latest} = conn ->
        json(conn, TestUtils.random_github_release("v0.2.0"))
      end)

      assert {:ok, %{latest_version: "0.2.0", update_available: true} = status} =
               Instance.check_for_update()

      assert status == Instance.update_status()
    end
  end
end
