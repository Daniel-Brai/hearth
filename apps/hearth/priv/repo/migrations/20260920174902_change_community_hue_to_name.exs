defmodule Hearth.Repo.Migrations.ChangeCommunityHueToName do
  use Ecto.Migration

  # The web app's palette names its hues so a community stores the name
  # Each degree becomes the nearest name
  @to_name """
  CASE
    WHEN hue < 15 OR hue >= 345 THEN 'red'
    WHEN hue < 40 THEN 'orange'
    WHEN hue < 70 THEN 'yellow'
    WHEN hue < 160 THEN 'green'
    WHEN hue < 200 THEN 'aqua'
    WHEN hue < 245 THEN 'blue'
    WHEN hue < 270 THEN 'violet'
    WHEN hue < 300 THEN 'purple'
    ELSE 'pink'
  END
  """

  @to_degrees """
  CASE hue
    WHEN 'red' THEN 0 WHEN 'orange' THEN 30 WHEN 'yellow' THEN 55 WHEN 'green' THEN 140
    WHEN 'aqua' THEN 180 WHEN 'blue' THEN 220 WHEN 'violet' THEN 255 WHEN 'purple' THEN 285
    WHEN 'pink' THEN 330 ELSE 30
  END
  """

  def up do
    for table <- ~w[communities community_requests] do
      execute "ALTER TABLE communities.#{table} ALTER COLUMN hue DROP DEFAULT"
      execute "ALTER TABLE communities.#{table} ALTER COLUMN hue TYPE text USING (#{@to_name})"
      execute "ALTER TABLE communities.#{table} ALTER COLUMN hue SET DEFAULT 'orange'"
    end
  end

  def down do
    for table <- ~w[communities community_requests] do
      execute "ALTER TABLE communities.#{table} ALTER COLUMN hue DROP DEFAULT"

      execute "ALTER TABLE communities.#{table} ALTER COLUMN hue TYPE integer USING (#{@to_degrees})"

      execute "ALTER TABLE communities.#{table} ALTER COLUMN hue SET DEFAULT 30"
    end
  end
end
