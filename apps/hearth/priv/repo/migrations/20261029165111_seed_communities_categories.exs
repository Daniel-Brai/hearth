defmodule Hearth.Repo.Migrations.SeedCommunitiesCategories do
  use Ecto.Migration

  # The same set the web app offers, so each picked slug has a row
  @categories [
    {"hobbies", "Hobbies"},
    {"games", "Games"},
    {"art", "Art and making"},
    {"music", "Music"},
    {"books", "Books and writing"},
    {"sports", "Sports and fitness"},
    {"local", "Local groups"},
    {"learning", "Learning"},
    {"work", "Work and business"},
    {"support", "Support and care"},
    {"tech", "Technology"}
  ]

  def up do
    for {{slug, name}, position} <- Enum.with_index(@categories) do
      execute """
      INSERT INTO communities.categories (id, slug, name, position, inserted_at, updated_at)
      VALUES (gen_random_uuid(), '#{slug}', '#{name}', #{position}, now(), now())
      ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, position = EXCLUDED.position
      """
    end
  end

  def down do
    slugs = Enum.map_join(@categories, ", ", fn {slug, _name} -> "'#{slug}'" end)
    execute "DELETE FROM communities.categories WHERE slug IN (#{slugs})"
  end
end
