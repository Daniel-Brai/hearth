defmodule Hearth.Accounts.CaptionsTest do
  use Hearth.DataCase, async: false

  alias Hearth.Accounts
  alias Hearth.Accounts.Settings
  alias Hearth.TestUtils

  setup do
    {:ok, user: TestUtils.register_random_user!()}
  end

  describe "update_settings/2" do
    test "fails if instance does not transcribe", %{user: user} do
      TestUtils.put_transcription(:off)

      assert {:error, changeset} = Accounts.update_settings(user, %{captions_on: true})
      assert %{settings: %{captions_on: ["are off on this instance"]}} = errors_on(changeset)
    end

    test "turns captions off whatever the instance does", %{user: user} do
      TestUtils.put_transcription(:off)

      assert {:ok, %Settings{captions_on: false}} =
               Accounts.update_settings(user, %{captions_on: false})
    end
  end
end
