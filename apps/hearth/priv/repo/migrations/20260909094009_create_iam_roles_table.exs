defmodule Hearth.Repo.Migrations.CreateIamRolesTable do
  use Ecto.Migration

  @prefix :iam
  @table :roles

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true
      # References communities once that context's tables exist
      add :community_id, :uuid, null: false
      add :key, :string, null: false
      add :name, :string, null: false
      add :color, :string, null: true
      add :position, :integer, null: false, default: 0
      add :is_default, :boolean, null: false, default: false
      add :is_system, :boolean, null: false, default: false
      add :permissions, {:array, :string}, null: false, default: []

      timestamps()
    end

    create unique_index(@table, [:community_id, :key], prefix: @prefix)

    # One default role per community and members with no role act as it
    create unique_index(@table, :community_id,
             prefix: @prefix,
             where: "is_default",
             name: :roles_one_default_index
           )
  end
end
