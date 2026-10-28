defmodule Hearth.Media.LifecycleTest do
  use ExUnit.Case, async: true

  alias Hearth.Media.Asset
  alias Hearth.Media.Lifecycle

  @image %Asset{content_type: "image/png"}
  @video %Asset{content_type: "video/mp4"}
  @document %Asset{content_type: "application/pdf"}

  describe "next/2" do
    test "fails for an event the status doesn't take" do
      assert {:error, :invalid_transition} =
               Lifecycle.next(%{@image | status: :uploading}, :processed)

      assert {:error, :invalid_transition} = Lifecycle.next(%{@image | status: :ready}, :confirm)
      assert {:error, :invalid_transition} = Lifecycle.next(%{@image | status: :ready}, :fail)
    end

    test "fails from a final status" do
      assert {:error, :invalid_transition} = Lifecycle.next(%{@image | status: :failed}, :confirm)

      assert {:error, :invalid_transition} =
               Lifecycle.next(%{@image | status: :failed}, :processed)

      assert {:error, :invalid_transition} = Lifecycle.next(%{@image | status: :failed}, :allow)
      assert {:error, :invalid_transition} = Lifecycle.next(%{@image | status: :blocked}, :fail)

      assert {:error, :invalid_transition} =
               Lifecycle.next(%{@image | status: :blocked}, :confirm)

      assert {:error, :invalid_transition} = Lifecycle.next(%{@image | status: :blocked}, :allow)
    end

    test "routes media by kind" do
      assert {:ok, :processing} = Lifecycle.next(%{@image | status: :uploading}, :confirm)
      assert {:ok, :processing} = Lifecycle.next(%{@video | status: :uploading}, :confirm)
      assert {:ok, :ready} = Lifecycle.next(%{@document | status: :uploading}, :confirm)
    end

    test "moves on from processing" do
      media = %{@image | status: :processing}

      assert {:ok, :ready} = Lifecycle.next(media, :processed)
      assert {:ok, :held} = Lifecycle.next(media, :hold)
      assert {:ok, :failed} = Lifecycle.next(media, :fail)
    end

    test "decides a held file" do
      assert {:ok, :ready} = Lifecycle.next(%{@image | status: :held}, :allow)
      assert {:ok, :blocked} = Lifecycle.next(%{@image | status: :held}, :block)
      assert {:ok, :blocked} = Lifecycle.next(%{@image | status: :ready}, :block)
    end
  end
end
