defmodule TestHelper do
  def fixture(name) do
    File.stream!(Path.join([__DIR__, "fixtures", name]), [], 8)
  end
end
ExUnit.start()
