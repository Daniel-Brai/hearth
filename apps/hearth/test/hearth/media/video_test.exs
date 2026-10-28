defmodule Hearth.Media.VideoTest do
  use ExUnit.Case, async: true

  alias Hearth.Media.TempFile
  alias Hearth.Media.Video
  alias Hearth.TestUtils

  describe "probe/1" do
    test "fails for a still image" do
      png = TestUtils.random_png!(40, 30)

      assert {:error, :not_a_video} =
               TempFile.run(fn path ->
                 File.write!(path, png)
                 Video.probe(path)
               end)
    end

    test "fails for a missing file" do
      assert {:error, :not_a_video} = Video.probe("/nonexistent/clip.mp4")
    end

    test "reads length size and codecs" do
      clip = TestUtils.random_video!()

      assert {:ok, %{width: 320, height: 240, video_codec: "h264", audio_codec: "aac"} = info} =
               TempFile.run(fn path ->
                 File.write!(path, clip)
                 Video.probe(path)
               end)

      assert info.duration_ms in 1_900..2_100
    end

    test "turns the size of a clip recorded sideways" do
      clip = TestUtils.random_video!()

      assert {:ok, %{width: 240, height: 320}} =
               TempFile.run(fn dir ->
                 File.mkdir_p!(dir)
                 input = Path.join(dir, "in.mp4")
                 output = Path.join(dir, "out.mp4")
                 File.write!(input, clip)

                 {_output, 0} =
                   System.cmd(
                     "ffmpeg",
                     ~w[-v error -y -display_rotation 90 -i #{input} -c copy #{output}],
                     env: %{"SECRET_KEY_BASE" => nil}
                   )

                 Video.probe(output)
               end)
    end
  end

  describe "silences/1" do
    test "fails for a file that isn't audio" do
      assert {:error, :not_converted} =
               TempFile.run(fn path ->
                 File.write!(path, "not audio")
                 Video.silences(path)
               end)
    end

    test "finds the pause between phrases" do
      assert {:ok, silences} =
               TempFile.run(fn dir ->
                 ["Hello there", "Goodbye now"]
                 |> TestUtils.write_speech!(dir)
                 |> Video.silences()
               end)

      assert Enum.any?(silences, fn {from, to} -> is_integer(to) and to - from >= 1_500 end)
    end
  end
end
