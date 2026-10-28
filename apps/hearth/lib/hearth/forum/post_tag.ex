defmodule Hearth.Forum.PostTag do
  use Hearth.Repo.Schema, prefix: "forum", primary_key: false

  alias Hearth.Forum.Post
  alias Hearth.Forum.Tag

  schema "post_tags" do
    belongs_to :post, Post, primary_key: true
    belongs_to :tag, Tag, primary_key: true
  end
end
