defmodule Hearth.Moderation.ScreenerTest do
  use ExUnit.Case, async: true

  import Req.Test

  alias Faker.Lorem
  alias Hearth.Moderation.Screener.Hosted
  alias Hearth.Moderation.Screener.Hosted.ApiError
  alias Hearth.Moderation.Screener.ImageModel
  alias Hearth.Moderation.Screener.TextModel
  alias Hearth.Moderation.Verdict
  alias Hearth.TestUtils
  alias Plug.Conn

  @completions "/api/v1/chat/completions"

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  describe "TextModel.parse/1" do
    test "fails for an answer without a safety line" do
      assert {:error, :unreadable} = TextModel.parse("I can't help with that.")
    end

    test "reads a safe answer" do
      assert {:ok, %Verdict{verdict: :safe, score: +0.0}} =
               TextModel.parse("Safety: Safe\nCategories: None")
    end

    test "holds unsafe content" do
      assert {:ok, %Verdict{verdict: :unsafe, score: 0.95, categories: ["Unethical Acts"]}} =
               TextModel.parse("Safety: Unsafe\nCategories: Unethical Acts")
    end

    test "scores controversial content low" do
      assert {:ok, %Verdict{verdict: :controversial, score: 0.4}} =
               TextModel.parse("Safety: Controversial\nCategories: Non-violent Illegal Acts")
    end

    test "ignores categories made for AI chat" do
      assert {:ok, %Verdict{verdict: :safe}} =
               TextModel.parse("Safety: Unsafe\nCategories: Jailbreak, Copyright Violation")
    end
  end

  describe "TextModel.prompt/1" do
    test "wraps text in chat template" do
      prompt = TextModel.prompt("hello")

      assert String.starts_with?(prompt, "<|im_start|>user\n# Task:")
      assert prompt =~ "<BEGIN CONVERSATION>\n\nUSER: hello\n\n<END CONVERSATION>"
      assert String.ends_with?(prompt, "<|im_start|>assistant\n<think>\n\n</think>\n\n")
    end
  end

  describe "ImageModel.verdict/1" do
    test "scores an image by how likely it is sexual" do
      predictions = [%{label: "nsfw", score: 0.97}, %{label: "normal", score: 0.03}]

      assert %Verdict{verdict: :unsafe, score: 0.97} = ImageModel.verdict(predictions)
    end

    test "passes an ordinary image" do
      predictions = [%{label: "normal", score: 0.99}, %{label: "nsfw", score: 0.01}]

      assert %Verdict{verdict: :safe, reason: nil} = ImageModel.verdict(predictions)
    end
  end

  describe "Hosted.screen_text/2" do
    test "fails when the provider refuses" do
      stub(Hosted, fn %Conn{method: "POST", request_path: @completions} = conn ->
        conn
        |> Conn.put_status(401)
        |> json(%{"error" => %{"message" => "No auth credentials found"}})
      end)

      assert {:error, %ApiError{status: 401, message: "No auth credentials found"}} =
               Hosted.screen_text(Lorem.sentence(), [])
    end

    test "fails for answer outside schema" do
      stub(Hosted, fn %Conn{method: "POST", request_path: @completions} = conn ->
        json(conn, TestUtils.chat_completion(%{"verdict" => "bad", "score" => 2}))
      end)

      assert {:error, :malformed} = Hosted.screen_text(Lorem.sentence(), [])
    end

    test "fails for an answer that isn't JSON" do
      stub(Hosted, fn %Conn{method: "POST", request_path: @completions} = conn ->
        json(conn, %{"choices" => [%{"message" => %{"content" => "unsafe!"}}]})
      end)

      assert {:error, :malformed} = Hosted.screen_text(Lorem.sentence(), [])
    end

    test "asks for structured output" do
      guidelines = Lorem.sentence()

      # The reply carries the guidelines back so the test can check they reached the prompt
      stub(Hosted, fn %Conn{method: "POST", request_path: @completions} = conn ->
        %{
          params: %{
            "response_format" => %{"type" => "json_schema", "json_schema" => %{"strict" => true}},
            "messages" => [%{"role" => "system", "content" => system} | _user]
          }
        } = conn

        [_rules, given] = String.split(system, "This community's own guidelines:\n")

        json(
          conn,
          TestUtils.chat_completion(%{
            "verdict" => "unsafe",
            "score" => 0.9,
            "categories" => ["Hate"],
            "reason" => given
          })
        )
      end)

      assert {:ok, %Verdict{verdict: :unsafe, score: 0.9, categories: ["Hate"]} = verdict} =
               Hosted.screen_text(Lorem.sentence(), guidelines: guidelines)

      assert verdict.reason == guidelines
    end
  end
end
