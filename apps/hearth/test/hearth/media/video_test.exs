defmodule Hearth.Media.VideoTest do
  use ExUnit.Case, async: true

  alias Hearth.Media.Video
  alias Hearth.TestUtils

  @moduletag :tmp_dir

  describe "probe/1" do
    test "fails for a still image", %{tmp_dir: dir} do
      path = TestUtils.write_file!(dir, TestUtils.random_file!())

      assert {:error, :not_a_video} = Video.probe(path)
    end

    test "fails for a missing file" do
      assert {:error, :not_a_video} = Video.probe("/nonexistent/clip.mp4")
    end

    test "reads length size and codecs", %{tmp_dir: dir} do
      path = TestUtils.write_file!(dir, TestUtils.random_file!(:video))

      assert {:ok, %{width: 320, height: 240, video_codec: "h264", audio_codec: "aac"} = info} =
               Video.probe(path)

      assert info.duration_ms in 1_900..2_100
    end

    test "turns the size of a clip recorded sideways", %{tmp_dir: dir} do
      path = TestUtils.write_sideways_video!(dir)

      assert {:ok, %{width: 240, height: 320}} = Video.probe(path)
    end
  end

  describe "silences/1" do
    test "fails for a file that isn't audio", %{tmp_dir: dir} do
      path = TestUtils.write_file!(dir, "not audio")

      assert {:error, :not_converted} = Video.silences(path)
    end

    test "finds the pause between phrases", %{tmp_dir: dir} do
      path = TestUtils.write_speech!(["Hello there", "Goodbye now"], dir)

      assert {:ok, silences} = Video.silences(path)
      assert [_silence | _silences] = TestUtils.long_silences(silences, 1_500)
    end
  end
end
