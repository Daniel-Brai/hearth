defmodule Hearth.Moderation.Screener.LocalTest do
  use ExUnit.Case, async: false

  alias Faker.Lorem
  alias Hearth.Moderation.Screener.ImageModel
  alias Hearth.Moderation.Screener.Local
  alias Hearth.Moderation.Screener.TextModel
  alias Hearth.Moderation.Verdict
  alias Hearth.TestUtils

  @moduletag :models
  @moduletag timeout: :timer.minutes(20)

  setup_all do
    config = Application.fetch_env!(:hearth, Local)

    TestUtils.start_servings!([
      {TextModel, TextModel.serving(config[:text_model], 1)},
      {ImageModel, ImageModel.serving(config[:image_model], 1)}
    ])

    :ok
  end

  describe "screen_text/2" do
    test "holds a threat" do
      assert {:ok, %Verdict{verdict: :unsafe, categories: ["Violent"]}} =
               Local.screen_text("I will find where you live and hurt your family.", [])
    end

    test "holds an insult" do
      assert {:ok, %Verdict{verdict: :unsafe, categories: ["Unethical Acts"]}} =
               Local.screen_text("You are a worthless idiot and everyone here hates you.", [])
    end

    test "passes an ordinary message" do
      assert {:ok, %Verdict{verdict: :safe}} =
               Local.screen_text("Thanks, restarting the supervisor fixed it.", [])
    end
  end

  describe "screen_image/2" do
    test "passes an ordinary image" do
      image = TestUtils.random_file!()

      assert {:ok, %Verdict{verdict: :safe}} = Local.screen_image(image, [])
    end

    test "fails for bytes that aren't an image" do
      assert {:error, :unreadable} = Local.screen_image(Lorem.sentence(), [])
    end
  end
end
