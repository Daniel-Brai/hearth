defmodule Hearth.Auth.Worker.PurgeTokensTest do
  use Hearth.DataCase, async: true

  alias Hearth.Auth
  alias Hearth.Auth.Token
  alias Hearth.Auth.Worker.PurgeTokens
  alias Hearth.TestUtils

  describe "perform/1" do
    test "keeps tokens that have not expired" do
      user = TestUtils.register_random_user!()
      {:ok, session} = Auth.create_session(user)

      assert :ok = perform_job(PurgeTokens, %{})
      assert {:ok, _token} = Token.find_random(:session, session)
    end

    test "deletes expired tokens" do
      user = TestUtils.register_random_user!()
      {:ok, _session} = Auth.create_session(user)

      expires_at = TestUtils.minutes_ago(1)
      :ok = TestUtils.update_rows!(Token, [user_id: user.id], expires_at: expires_at)

      assert :ok = perform_job(PurgeTokens, %{})
      refute Token.exists?(user_id: user.id)
    end
  end
end
