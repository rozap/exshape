defmodule TestHelper do
  def fixture(name) do
    File.stream!(Path.join([__DIR__, "fixtures", name]), [], 256)
  end
end
ExUnit.start()
