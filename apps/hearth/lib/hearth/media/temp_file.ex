defmodule Hearth.Media.TempFile do
  alias Hearth.Common
  # The path is made from a new id, never from anything a person sent
  # sobelow_skip ["Traversal.FileModule"]
  @spec run((Path.t() -> result)) :: result when result: term()
  def run(fun) when is_function(fun, 1) do
    path = Path.join(System.tmp_dir!(), "hearth-media-#{Common.new_id()}")

    try do
      fun.(path)
    after
      File.rm_rf(path)
    end
  end
end
