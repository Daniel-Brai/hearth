defmodule Hearth.Communities.StartCommunityTest do
  use Hearth.DataCase, async: false

  alias Faker.Company
  alias Faker.Lorem
  alias Hearth.Communities
  alias Hearth.Communities.Community
  alias Hearth.Communities.Request
  alias Hearth.TestUtils

  setup do
    {:ok, user: TestUtils.register_random_user!()}
  end

  test "fails if only admins start communities", %{user: user} do
    TestUtils.put_community_creation("admins")

    assert {:error, :forbidden} = Communities.start_community(user, %{name: Company.name()})
  end

  test "fails if the account is too new", %{user: user} do
    TestUtils.put_community_creation("anyone")

    assert {:error, :account_too_new} = Communities.start_community(user, %{name: Company.name()})
  end

  test "fails if the person owns too many", %{user: user} do
    TestUtils.put_community_creation("anyone")
    user = %{user | inserted_at: DateTime.add(DateTime.utc_now(), -2, :day)}
    _communities = TestUtils.create_random_communities!(user, 3)

    assert {:error, :too_many_owned} = Communities.start_community(user, %{name: Company.name()})
  end

  test "sends a request", %{user: user} do
    TestUtils.put_community_creation("request")

    params = %{name: Company.name(), note: Lorem.sentence()}

    assert {:requested, %Request{status: :pending} = request} =
             Communities.start_community(user, params)

    assert request.name == params.name
  end

  test "start community", %{user: user} do
    TestUtils.put_community_creation("anyone")
    user = %{user | inserted_at: DateTime.add(DateTime.utc_now(), -2, :day)}

    assert {:ok, %Community{}} = Communities.start_community(user, %{name: Company.name()})
  end
end
