defmodule Hearth.IAM.MembershipRole do
  use Hearth.Repo.Schema, prefix: "iam", primary_key: false

  alias Hearth.IAM.Membership
  alias Hearth.IAM.Role

  schema "membership_roles" do
    belongs_to :membership, Membership, primary_key: true
    belongs_to :role, Role, primary_key: true
  end
end
