defmodule Hearth.Media.DocumentTest do
  use ExUnit.Case, async: true

  alias Hearth.Media.Document

  @xlsx "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

  setup do
    dir =
      Path.join(System.tmp_dir!(), "hearth-document-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    {:ok, path: Path.join(dir, "file")}
  end

  describe "check/2" do
    test "fails a PDF that doesn't start like one", %{path: path} do
      File.write!(path, "MZ\x90\x00")

      assert {:error, :content_mismatch} = Document.check(path, "application/pdf")
    end

    test "fails an Office file that isn't a ZIP", %{path: path} do
      File.write!(path, "%PDF-1.7")

      assert {:error, :content_mismatch} = Document.check(path, @xlsx)
    end

    test "fails a ZIP without the main part", %{path: path} do
      archive = String.to_charlist(path)
      {:ok, _path} = :zip.create(archive, [{~c"word/document.xml", "<w/>"}])

      assert {:error, :content_mismatch} = Document.check(path, @xlsx)
    end

    test "fails text with a NUL byte", %{path: path} do
      File.write!(path, "a,b\n1,\0")

      assert {:error, :content_mismatch} = Document.check(path, "text/csv")
    end

    test "fails text that isn't UTF-8", %{path: path} do
      File.write!(path, <<0xFF, 0xFE, ?a>>)

      assert {:error, :content_mismatch} = Document.check(path, "text/plain")
    end

    test "fails a type it doesn't know", %{path: path} do
      File.write!(path, "hello")

      assert {:error, :content_mismatch} = Document.check(path, "text/html")
    end

    test "passes a PDF", %{path: path} do
      File.write!(path, "%PDF-1.7\n")

      assert :ok = Document.check(path, "application/pdf")
    end

    test "passes an Office file with its main part", %{path: path} do
      archive = String.to_charlist(path)
      {:ok, _path} = :zip.create(archive, [{~c"xl/workbook.xml", "<w/>"}])

      assert :ok = Document.check(path, @xlsx)
    end

    test "passes UTF-8 text", %{path: path} do
      File.write!(path, "naïve,café\n")

      assert :ok = Document.check(path, "text/csv")
    end
  end
end
